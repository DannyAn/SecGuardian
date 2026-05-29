# /secguard - 安全加固项排查

对源码执行安全加固扫描。支持全量扫描和 Git diff 增量扫描，支持命名空间过滤和逗号组合。

## 使用方式

```
/secguard <path> [mode] [filters]

全量扫描:
  /secguard ./src                                    # 全部检测器
  /secguard ./src memory.*                           # 内存检测器
  /secguard ./src memory.null-dereference            # 单个检测器
  /secguard ./src memory.*,system.*,crypto.*         # 多过滤器组合

增量扫描:
  /secguard ./src git diff                           # 工作区变更
  /secguard ./src git diff HEAD~1                    # 最近一次提交
  /secguard ./src git diff main                      # 当前分支 vs main
  /secguard ./src git diff main...feature            # 分支差异
  /secguard ./src git diff HEAD~1 memory.*           # 增量 + 过滤

SARIF 输出 (CI/CD 集成):
  /secguard ./src --sarif                            # 附加 SARIF 2.1.0 输出
  /secguard ./src memory.*,system.* --sarif          # 过滤 + SARIF
```

## 输出

扫描结果写入 `.codeagent/secguard-secguardian/scans/<scan-id>/`：

```
.codeagent/secguard-secguardian/scans/2026-05-23T14-30-00-a1b2/
├── manifest.json            # 扫描摘要 + 检出索引
└── findings/
    ├── C-001.json            # Critical 检出
    ├── H-001.json            # High 检出
    └── ...
```

### 输出协议

遵循 [Scan Output Protocol 1.0](../knowledge/protocols/scan-output.md)。

**执行完毕后必须输出扫描摘要和 scan-id：**

```
## secguard 扫描完成

Scan ID: 2026-05-23T14-30-00-a1b2
Path: ./src
Mode: git diff HEAD~1
Filters: memory.*, system.*

### 结果
- 扫描文件: 12 (变更行: 95)
- 检测器: 18 matched, 8 executed
- 检出: 3 (Critical: 1, High: 2)

### 检出
| ID | Severity | Detector | File |
|----|----------|----------|------|
| C-001 | Critical | memory.buffer-overflow | src/parser.c:42 |
| H-001 | High | memory.null-dereference | src/network.c:305 |
| H-002 | High | system.command-injection | src/executor.c:89 |

输出目录: .codeagent/secguard-secguardian/scans/2026-05-23T14-30-00-a1b2/
```

## 命名空间

| Namespace | 覆盖范围 | 检测器数 |
|-----------|---------|---------|
| `memory` | 内存安全 + 内存管理 | 12 |
| `concurrency` | 并发安全 | 4 |
| `system` | 系统安全 | 6 |
| `crypto` | 加密与密钥 | 4 |
| `critical` | 所有 Critical 严重度 | 跨 namespace |
| `*` (默认) | 全部 | 26 |

## 派发规则与执行步骤

你（AI Agent）在接收到 `/secguard` 命令后，必须按以下步骤执行来构建索引并进行安全扫描。

### 前置检查（Pre-flight Checklist）

在执行任何扫描步骤之前，必须逐项确认以下所有条件。**任一项未通过，扫描不得开始，向用户报告具体错误。**

- [ ] 定位索引器 wrapper：检查 `.opencode/scripts/secguardian-index`、`.gemini/scripts/secguardian-index`、`.claude/extensions/*/scripts/secguardian-index`，或 `scripts/secguardian-index`（至少一个存在且可执行）
- [ ] 执行 `{indexer} --health` 通过（输出必须包含 `HEALTH:OK` 或 `HEALTH:WARN`，不接受 `HEALTH:FAIL`）
- [ ] 目标路径 `<path>` 存在且包含至少一个源码文件

> 若未通过，报告具体哪一项失败并终止。不要降级为手工逐文件扫描。

---

### Step 1: 建立输出目录

- 生成 `scan_id`（格式: `sc-YYYYMMDD-HHMMSS-xxxx`，其中 `xxxx` 为随机4位字符）。
- 创建输出目录: `.codeagent/secguard-secguardian/scans/<scan_id>/findings/`。
- 记录扫描开始时间戳，用于 Step 4 计算 `duration_ms`。

### Step 2: 构建语义索引（必须执行，不可跳过）

> ⚠️ 这是扫描的**核心前置步骤**。索引器提供符号表、调用图、alloc/free 配对，是后续检测器执行的结构化上下文。**不执行此步骤将导致扫描质量严重下降。**

**2a. 执行索引器（阻塞等待完成）：**

```bash
# 定位 wrapper（按优先级尝试）
INDEXER=""
for candidate in \
    .opencode/scripts/secguardian-index \
    .gemini/scripts/secguardian-index \
    .claude/extensions/secguard-secguardian/scripts/secguardian-index \
    .claude/extensions/secaudit-secguardian/scripts/secguardian-index \
    .claude/extensions/secreview-secguardian/scripts/secguardian-index \
    scripts/secguardian-index \
    internal/secguardian-index; do
    if [ -x "$candidate" ] && [ -f "$candidate" ]; then
        INDEXER="$candidate"
        break
    fi
done

if [ -z "$INDEXER" ]; then
    echo "FATAL: secguardian-index not found" && exit 1
fi

$INDEXER --path <path> --output .codeagent/secguard-secguardian/scans/<scan_id>/index.json
```

**2b. 验证索引完整性（必须通过）：**

```bash
python3 -c "
import json, sys
d = json.load(open('.codeagent/secguard-secguardian/scans/<scan_id>/index.json'))
assert len(d.get('files',[])) > 0, 'FATAL: index contains no files'
assert 'symbols' in d, 'FATAL: index missing symbols'
print(f'Index OK: {len(d[\"files\"])} files, {len(d.get(\"symbols\",{}).get(\"functions\",[]))} functions, {len(d.get(\"call_graph\",{}).get(\"edges\",[]))} call edges')
"
```

若验证失败（返回非 0），**立即终止扫描**并向用户报告索引生成出错。

**2c. 将 index.json 加载为上下文：**

读取生成的 `index.json`，理解以下结构化信息并在后续所有检测步骤中使用：
- `symbols.functions` — 函数名→文件:行号映射（精确定位目标）
- `call_graph.edges` — caller→callee 关系（追踪数据流和影响范围）
- `alloc_free.pairs` — malloc/free 配对（内存管理分析）
- `files` — 源码文件清单（确定扫描对象）

### Step 3: 语言与检测器匹配

- 通过 `index.json` 中的文件扩展名分布自动检测目标语言。
- 读取 `skills/secguard-cpp/references/detector-index.md`，根据命名空间过滤 active 状态的检测器。
- 按 Critical → High → Medium 排序执行。
- 对每一个匹配到的检测器，加载 `../knowledge/detectors/<name>.md` 中的检测逻辑。
- **利用 index.json 中的符号表和调用图定位检测目标**，而非逐文件遍历。
- 增量模式（`git diff`）下，仅分析由 diff 识别的变更行。

### Step 4: 保存检出并输出摘要

- 按照 [Scan Output Protocol 1.0](../knowledge/protocols/scan-output.md) 写入 `findings/<id>.json` 和 `manifest.json`。
- `manifest.json` 中的 `duration_ms` 必须使用 **实际 wall-clock 耗时**（结束时间戳 − 开始时间戳），不得编造。
- 向用户输出 Markdown 格式的扫描摘要，包含：scan_id、检出总数、按严重度分组、Top 5 key findings。
