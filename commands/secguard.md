---
name: secguard
description: "安全加固项排查 — 67 个检测器覆盖 memory/concurrency/system/resource/crypto/web/error 7 大安全分类"
---

# /secguard - 安全加固项排查

对源码执行安全加固扫描。支持全量扫描和 Git diff 增量扫描，支持命名空间过滤和逗号组合。

## 使用方式

```
/secguard <path> [mode] [filters]

全量扫描:
  /secguard ./src                                    # 全部检测器（默认）
  /secguard ./src all                                # 全部检测器（显式）
  /secguard ./src *                                  # 全部检测器（通配符）
  /secguard ./src memory.*                           # 内存检测器
  /secguard ./src memory.null-dereference            # 单个检测器
  /secguard ./src memory.*,system.*,crypto.*         # 多过滤器组合（逗号分隔）

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

遵循 [Scan Output Protocol 2.0](../knowledge/protocols/scan-output.md)。人读/机读分离。

```
.codeagent/secguard-secguardian/scans/<scan-id>/
├── report.md               # ★ 人读审计报告 (Markdown)
├── results.sarif            # 机读: SARIF 2.1.0 (CI/CD)
├── summary.json             # 仪表盘统计
├── manifest.json            # 扫描元数据 + 检出索引
├── status.json              # CI 门禁
└── delta.json               # 增量对比 (vs 上次扫描)
```

**执行完毕后必须输出扫描摘要和 scan-id：**

```
## secguard 扫描完成

Scan ID: sc-20260531-143000-a1b2
Path: ./src
Mode: full
Filters: memory.*, system.*

### 结果
- 扫描文件: 12, 扫描行: 450
- 检测器: 18 matched, 8 executed
- 检出: 3 (Critical: 1, High: 2)
- 安全评分: 45/100 🔴

### 检出
| 检出 ID | Severity | Detector | File | 修复建议 |
|---------|----------|----------|------|---------|
| C-BOF-parser_c-L36 | 🔴 Critical | memory.buffer-overflow | src/parser.c:36 | 使用 `snprintf(buf, sizeof(buf), ...)` 替代 `sprintf` |
| H-NPD-network_c-L305 | 🟠 High | memory.null-dereference | src/network.c:305 | malloc() 后检查 `if (!ptr) return ERR_NOMEM;` |
| H-CMD-executor_c-L89 | 🟠 High | system.command-injection | src/executor.c:89 | 使用 `execve()` 参数数组替代 `system()` |

> ID 格式: `<SEVERITY>-<DETECTOR_ABBREV>-<FILE_SLUG>-L<LINE>` — 一眼看懂严重度、漏洞类型、文件和行号。

📄 完整报告: `.codeagent/secguard-secguardian/scans/sc-20260531-143000-a1b2/report.md`
📊 SARIF: `.codeagent/secguard-secguardian/scans/sc-20260531-143000-a1b2/results.sarif`
📋 索引: `.codeagent/secguard-secguardian/scans/sc-20260531-143000-a1b2/manifest.json`

💡 **如何使用扫描结果？**
- **快速看汇总** → 打开 `manifest.json`（JSON 索引，列出所有检出 ID/严重度/文件）
- **看详情 + 改代码** → 打开 `report.md`（每个检出含证据链 + before/after 修复代码）
- **CI/CD 集成** → 消费 `results.sarif`（GitHub Code Scanning / GitLab SAST / Azure DevOps）
- **AI Agent 修复** → 告诉 AI：`读取 report.md，按修复方案修改代码`（修复方案来自 detector 的 FIX 指引，可直接执行）
```

## 命名空间

| Namespace | 覆盖范围 | 检测器数 |
|-----------|---------|---------|
| `memory` | 内存安全 + 内存管理 | 13 |
| `concurrency` | 并发安全 | 4 |
| `system` | 系统安全 | 8 |
| `resource` | 资源生命周期 | 6 |
| `crypto` | 加密与密钥 | 9 |
| `web` | Web + 应用安全 | 22 |
| `error` | 错误处理 + 信息泄露 | 6 |
| `critical` | 所有 Critical 严重度 | 跨 namespace |
| `*` (默认) | 全部 | 67 |

## 派发规则与执行步骤

> **隔离约束**: 本命令只能加载 `skills/` 扩展下的 `secguard-*` 前缀 skill，禁止加载 `secaudit-*` 或 `secreview-*` 前缀的任何文件。知识文件仅从 `knowledge/detectors/` 和 `knowledge/languages/` 加载。

你（AI Agent）在接收到 `/secguard` 命令后，必须按以下步骤执行来构建索引并进行安全扫描。

### 前置检查（Pre-flight Checklist）

在执行任何扫描步骤之前，必须逐项确认以下所有条件。**任一项未通过，扫描不得开始，向用户报告具体错误。**

- [ ] 定位索引器 wrapper：优先查找项目级路径，其次用户级（`~/.config/opencode/`、`~/.gemini/`、`~/.claude/`），最后回退到 `scripts/secguardian-index` 或 `internal/secguardian-index`（至少一个存在且可执行）
- [ ] 执行 `{indexer} --health` 通过（输出必须包含 `HEALTH:OK` 或 `HEALTH:WARN`，不接受 `HEALTH:FAIL`）
- [ ] 目标路径 `<path>` 存在且包含至少一个源码文件
- [ ] 确认不会启动 clangd/LSP/compile_commands.json/bear 等外部工具 — indexer (tree-sitter) 已提供符号表+调用图+文件清单，所有代码结构数据从 index.json 获取

> 若未通过，报告具体哪一项失败并终止。不要降级为手工逐文件扫描。

---

### Step 1: 建立输出目录

- 生成 `scan_id`（格式: `sc-YYYYMMDD-HHMMSS-xxxx`，其中 `xxxx` 为随机4位字符）。
- 创建输出目录: `.codeagent/secguard-secguardian/scans/<scan_id>/`。
- 记录扫描开始时间戳，用于 Step 4 计算 `duration_ms`。

### Step 2: 构建语义索引（必须执行，不可跳过）

> ⚠️ 这是扫描的**核心前置步骤**。索引器提供符号表、调用图、alloc/free 配对，是后续检测器执行的结构化上下文。**不执行此步骤将导致扫描质量严重下降。**

**2a. 执行索引器（阻塞等待完成）：**

```bash
# 定位 indexer wrapper — 项目级 + 用户级全覆盖
find_indexer() {
    INDEXER=""
    # Base directories × relative paths — covers project-level + user-level
    for base in "." "$HOME"; do
        for path in \
            ".opencode/extensions/secguardian/scripts/secguardian-index" \
            ".config/opencode/extensions/secguardian/scripts/secguardian-index" \
            ".gemini/extensions/secguardian/scripts/secguardian-index" \
            ".claude/plugins/secguardian/scripts/secguardian-index"; do
            candidate="$base/$path"
            [ -x "$candidate" ] && [ -f "$candidate" ] && INDEXER="$candidate" && break 3
        done
    done
    # Legacy fallbacks (pre-plugin-format deploys)
    for candidate in \
        scripts/secguardian-index \
        internal/secguardian-index; do
        [ -x "$candidate" ] && [ -f "$candidate" ] && INDEXER="$candidate" && break
    done
    [ -z "$INDEXER" ] && echo "FATAL: secguardian-index not found (checked project + user paths)" && exit 1
    echo "Using: $INDEXER"
}
find_indexer
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
- 读取 `skills/secguard/cpp/references/detector-index.md`，获取全部 60 个 active 检测器清单。
- **过滤规则**：
  - 无 filter 或 `all` 或 `*` → 加载全部 60 个检测器
  - `namespace.*`（如 `memory.*`）→ 加载该命名空间下所有检测器
  - `namespace.name`（如 `memory.null-dereference`）→ 加载单个检测器
  - 逗号分隔（如 `memory.*,system.*`）→ 取并集
  - 检测器文件名：将 `namespace.name` 转换为 `../knowledge/detectors/namespace-name.md`
- 按 Critical → High → Medium → Low → Info 排序执行。
- **利用 index.json 中的符号表和调用图定位检测目标**，而非逐文件遍历。
- 增量模式（`git diff`）下，仅分析由 diff 识别的变更行。

### Step 4: 保存检出并输出摘要

- 按照 `knowledge/protocols/scan-output.md` (v2.0) 写入 `report.md`（人读）+ `results.sarif`（机读）+ `manifest.json` + `summary.json` + `status.json`。
- `manifest.json` 中的 `duration_ms` 必须使用 **实际 wall-clock 耗时**（结束时间戳 − 开始时间戳），不得编造。
- 向用户输出 Markdown 格式的扫描摘要，包含：scan_id、检出总数、按严重度分组、Top 5 key findings。
