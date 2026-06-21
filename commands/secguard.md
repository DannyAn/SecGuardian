---
name: secguard
description: "安全加固项排查 — 67<!-- @secguardian:detector_count --> 个检测器覆盖 memory/concurrency/system/resource/crypto/web/error 7<!-- @secguardian:namespace_count --> 大安全分类"
---

# /secguard - 安全加固项排查

对源码执行安全加固扫描。支持全量扫描和 Git diff 增量扫描，支持命名空间过滤和逗号组合。

## 使用方式

```
/secguard <path> <language> [filters] [--sarif]

全量扫描:
  /secguard ./src cpp                                # C/C++ 全量
  /secguard ./src python                             # Python 全量
  /secguard ./src java                               # Java 全量

命名空间过滤:
  /secguard ./src cpp memory.*                       # 仅内存安全检测器
  /secguard ./src cpp memory.null-dereference        # 单个检测器
  /secguard ./src cpp memory.*,system.*,crypto.*     # 多组合（逗号并集）
  /secguard ./src python web.*                       # 仅 Web 安全检测器
  /secguard ./src java memory.buffer-overflow, memory.double-free  # 精确匹配

增量扫描:
  /secguard ./src cpp git diff                       # 工作区变更
  /secguard ./src cpp git diff HEAD~1                # 最近一次提交
  /secguard ./src cpp git diff main                  # 当前分支 vs main
  /secguard ./src cpp git diff main...feature        # 分支差异

SARIF 输出 (CI/CD 集成):
  /secguard ./src python --sarif                     # 附加 SARIF 2.1.0 输出
  /secguard ./src cpp memory.* --sarif               # 过滤 + SARIF
```

## 输出

遵循 [Scan Output Protocol 3.0](../knowledge/protocols/scan-output.md)。人读/机读分离。

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
- **快速看汇总** → 打开 `manifest.json`（JSON 索引，列出所有检出 ID/严重度/文件/行号）
- **★ 人读检视报告** → 打开 `report.md`（每个检出含完整四段式：📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix）
- **CI/CD 集成** → 消费 `results.sarif`（GitHub Code Scanning / GitLab SAST / Azure DevOps）
- **AI Agent 修复** → 告诉 AI：`读取 report.md §4，按每个发现的 🔧 Fix 方案修改代码`
```

## 命名空间

| Namespace | 覆盖范围 | 检测器数 |
|-----------|---------|---------|
| `memory` | 内存安全 + 内存管理 | 13<!-- @secguardian:namespace:memory --> |
| `concurrency` | 并发安全 | 4<!-- @secguardian:namespace:concurrency --> |
| `system` | 系统安全 | 8<!-- @secguardian:namespace:system --> |
| `resource` | 资源生命周期 | 6<!-- @secguardian:namespace:resource --> |
| `crypto` | 加密与密钥 | 9<!-- @secguardian:namespace:crypto --> |
| `web` | Web + 应用安全 | 21<!-- @secguardian:namespace:web --> |
| `error` | 错误处理 + 信息泄露 | 6<!-- @secguardian:namespace:error --> |
| `critical` | 所有 Critical 严重度 | 跨 namespace |
| `*` (默认) | 全部 | 67<!-- @secguardian:detector_count --> |

## 派发规则与执行步骤

> **隔离约束**: 本命令只能加载 `skills/` 扩展下的 `secguard-*` 前缀 skill，禁止加载 `secaudit-*` 或 `secreview-*` 前缀的任何文件。知识文件仅从 `knowledge/guard-rules/` 和 `knowledge/languages/` 加载。

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

**2b. 验证索引完整性 + 生成结构化摘要（必须通过）：**

执行以下脚本。若返回非 0，**立即终止扫描**并向用户报告索引生成出错。
若成功，直接读取输出的 JSON 摘要作为后续所有步骤的上下文，**禁止自己写 Python 去探测索引结构**。

```bash
INDEX_FILE=.codeagent/secguard-secguardian/scans/<scan_id>/index.json
python3 << 'PYEOF'
import json, sys, os
from collections import Counter

with open(os.environ['INDEX_FILE']) as f:
    d = json.load(f)

# ── 校验 ──
assert len(d.get('files',[])) > 0, 'FATAL: index contains no files'
assert 'symbols' in d, 'FATAL: index missing symbols'
assert 'call_graph' in d, 'FATAL: index missing call_graph'

# ── 语言检测（健壮扩展名映射） ──
EXT_MAP = {
    'c': 'cpp', 'h': 'cpp', 'cpp': 'cpp', 'cc': 'cpp', 'cxx': 'cpp', 'hpp': 'cpp', 'hh': 'cpp', 'hxx': 'cpp',
    'java': 'java',
    'py': 'python', 'pyw': 'python',
    'go': 'go',
    'js': 'javascript', 'jsx': 'javascript', 'ts': 'javascript', 'tsx': 'javascript', 'mjs': 'javascript', 'cjs': 'javascript',
    'rs': 'rust', 'swift': 'swift', 'kt': 'kotlin', 'kts': 'kotlin', 'scala': 'scala',
    'rb': 'ruby', 'php': 'php', 'cs': 'csharp', 'fs': 'fsharp',
    'sh': 'shell', 'bash': 'shell', 'zsh': 'shell',
    'cmake': 'cmake', 'mk': 'makefile',
}
def detect_lang(filepath):
    base = os.path.basename(filepath)
    # 跳过隐藏文件和常见非源码
    if base.startswith('.'):
        return None
    if '.' not in base:
        return None
    # 取最后一个点后的扩展名，小写
    ext = base.rsplit('.', 1)[-1].lower()
    return EXT_MAP.get(ext)

langs = Counter()
for f in d['files']:
    lang = detect_lang(f)
    if lang:
        langs[lang] += 1

# ── 确定主语言 ──
primary_lang = langs.most_common(1)[0][0] if langs else 'unknown'

# ── 输出 JSON 摘要（所有后续步骤只读这个摘要，不要再自己探测） ──
summary = {
    'scan_id': os.environ.get('SCAN_ID', ''),
    'file_count': len(d['files']),
    'function_count': len(d['symbols']['functions']),
    'call_edge_count': len(d['call_graph']['edges']),
    'primary_language': primary_lang,
    'language_distribution': dict(langs.most_common()),
    'index_path': os.environ['INDEX_FILE'],
}
json.dump(summary, sys.stdout, indent=2, ensure_ascii=False)
PYEOF
```

> **关键约束**：此脚本输出 JSON 到 stdout。读取该 JSON 获取 `file_count`、`function_count`、`primary_language` 等，**严禁**自行编写 Python 或 shell 去重新解析 index.json。

```
read .codeagent/secguard-secguardian/scans/<scan_id>/index.json
```
INDEX_FILE 输出示例:
```json
{
  "scan_id": "...",
  "file_count": 12,
  "function_count": 85,
  "call_edge_count": 210,
  "primary_language": "cpp",
  "language_distribution": {
    "cpp": 12
  }
}
```


### Step 2.5: 扫描目标定位（仅优化执行效率，不跳过任何检测器）

> **此步骤不做检测器选择**。已加载的检测器集合由接下来的 Step 3（`language` 参数 + `filter` 参数）决定。
> 此步骤只回答："我知道了要跑哪些检测器，它们在代码的哪个位置？"

#### 2.5a 读取 index.json

从扫描目录读取 index.json，提取以下结构化数据：
- `symbols.functions` — 代码中所有函数调用
- `call_graph.edges` — 调用关系
- `alloc_free.pairs` — 分配/释放对
- `lock_graph.mutexes` — 锁使用记录

#### 2.5b 构建检测目标映射（为后续执行加速）

预扫描 index.json，建立检测器 → 目标位置的映射。目的：后续 Step 4 执行检测时，AI 带着精确坐标跳转，不盲目遍历文件。

| 检测器类型 | 预查索引数据源 |
|-----------|--------------|
| 内存安全（`memory.*`） | `alloc_free.pairs` 中的分配点、`symbols.functions` 中 unsafe 内存操作 |
| 并发安全（`concurrency.*`） | `lock_graph.mutexes` 中的锁位置、`symbols.variables` 中共享变量 |
| 加密安全（`crypto.*`） | `symbols.functions` 中加密函数调用点 |
| Web 安全（`web.*`） | `symbols.functions` + `call_graph.edges` 中的 SQL/模板/用户输入处理 |
| 系统/资源（`system.*`/`resource.*`） | `symbols.functions` 中系统调用/文件操作 |

> **关键约束**：此步骤构建的映射**仅用于加速执行**，不跳过任何已确定的检测器。
> 即使某检测器在 index.json 中无直接匹配，AI 仍需执行它（确认代码中是否以其他方式实现了类似功能）。

### Step 3: 语言与检测器匹配

> **原则**: 检测器选择由命令的 `language` 参数 + `filter` 参数决定，**不做额外的自动筛选**。
> 默认（无 filter）= 该语言适用的**全部**检测器 = 全量安全扫描。

#### 3a 语言确定

- 如果用户在命令中提供了 `language` 参数（如 `/secguard ./src cpp`），直接使用 `cpp`
- 如果用户未显式提供，从 Step 2b 生成的 index.json 摘要中的 `primary_language` 自动推断

#### 3b 读取语言索引

读取 `knowledge/language-index.md`，直接定位到 `## {language}` 节（如 `## cpp`）。

该文件按语言预分组了所有适用的规则。示例：cpp 节包含 `guard-rules/buffer-overflow`、`audit-rules/cryptography`、`review-rules/cpp` 等。

AI 只需读取 `## cpp` 以下至下一个 `##` 之间的内容即获得完整的语言规则清单——不需解析 JSON，不需遍历全部文件。

#### 3c 应用 filter 裁剪

- 无 filter 或 `all` 或 `*` → 使用该语言下的**全部**规则
- `namespace.*`（如 `memory.*`）→ 只保留该命名空间的 guard-rules
- `namespace.name`（如 `memory.null-dereference`）→ 只加载单个检测器
- 逗号分隔（如 `memory.*,system.*`）→ 取并集
- 检测器文件路径：`../../knowledge/guard-rules/{namespace-name}.md`

#### 3d 精确加载

从裁剪后的清单中，精确加载每个检测器的 .md 文件（不遍历、不猜测）。

#### 3e 排序与执行

- 按 Critical → High → Medium → Low → Info 排序执行
- 增量模式（`git diff`）下，仅分析由 diff 识别的变更行

### Step 3.5: 三轮验证管道（误报消减）

> ⚠️ 这是 v6.0 新增的验证步骤。在 Detector 产出 Finding 后、渲染报告前，执行三轮独立验证对每个 Finding 进行证据认证，最大化降低误报。
> 跳过验证: 在命令末尾加 `--no-verify` flag。

**3.5a. 加载验证协议：**

读取 `knowledge/protocols/verification-protocol.md` 获取完整的三轮 prompt 模板和裁决标准。

**3.5b. 执行 P1: Semantic Verification：**

- 从 index.json 的 `types` 和 `functions` 构建 Project Security Profile（安全包装类/安全工厂方法/校验方法的全局视图）。
- 对每个 Finding，判断其声称的风险是否已被项目自身的安全框架天然消除。
- 裁决: `exempted` (抑制) / `no_exemption` (保留) / `uncertain` (保留但标记)。
- Profile 全局构建一次，所有 Finding 复用。

**3.5c. 执行 P2: Counter-Evidence Hunt：**

- 对 P1 中 `no_exemption` 和 `uncertain` 的 Finding，执行 Defense Agent 搜索。
- 按 Finding 的 CWE/类型使用对应搜索清单（内存安全→RAII/smart pointer；注入→PreparedStatement/ORM；并发→lock_guard/atomic；加密→高层加密库/KMS）。
- 搜索范围: Finding 所在文件 + index.json 中同模块文件。
- 裁决: `counter_evidence_found` (抑制) / `counter_evidence_not_found` (保留)。

**3.5d. 执行 P3: Adjudication Court：**

- 对 P2 中 `counter_evidence_not_found` 的 Finding，构建 Court Record（Finding 摘要 + P1 + P2 verdict）。
- Prosecutor + Defender 并行发言（基于 Court Record，禁止访问源码）。
- Judge 最终裁决（禁止访问源码，仅基于 Court Record + 双方陈述）。
- 裁决: `confirmed` (确认) / `suspected` (可疑，需人工确认) / `dismissed` (抑制)。

**3.5e. 输出验证产物：**

写入两个新文件到 scan root：

```bash
SCAN_DIR=".codeagent/secguard-secguardian/scans/<scan_id>"

# dismissed.json — 被抑制的 Finding + 原因 + 轮次
# verification-audit.json — 完整验证链 + 每轮收敛统计
```

**3.5f. 自检完整性：**

```bash
python3 << 'PYEOF'
import json, os, sys

scan_dir = os.environ['SCAN_DIR']

# Check dismissed.json
with open(os.path.join(scan_dir, 'dismissed.json')) as f:
    dismissed = json.load(f)
for d in dismissed['dismissed']:
    assert d['finding_id'], f"Missing finding_id in dismissed entry"
    assert d['dismissed_at_round'] in ('P1', 'P2', 'P3'), f"Invalid round: {d['dismissed_at_round']}"
    assert d['dismiss_reason'], f"Missing dismiss_reason for {d['finding_id']}"

# Check verification-audit.json
with open(os.path.join(scan_dir, 'verification-audit.json')) as f:
    audit = json.load(f)
for round_key in ('p1_semantic', 'p2_counter_evidence', 'p3_court'):
    assert round_key in audit['rounds'], f"Missing round: {round_key}"

certified = audit['certified_count']
dismissed_total = audit['dismissed_count']
findings_total = len(json.load(open(os.path.join(scan_dir, 'findings.json'))).get('findings', []))
assert certified + dismissed_total == findings_total, \
    f"Count mismatch: {certified} + {dismissed_total} != {findings_total}"

print(f"✅ Verification audit: {findings_total} findings → {certified} certified, {dismissed_total} dismissed")
PYEOF
```

### Step 4: 输出结构化 findings（遵循 Findings Protocol v5.0）

> ⚠️ **v5.0 关键变更**: AI **不再输出单体 findings.json**。改为按 detector 分类，**每个 finding 输出一个独立文件**到 `findings/` 目录树下。最后输出轻量 `findings.json`（同名升级，不含四段式，仅元数据+索引）。渲染器通过 `--findings-dir` 聚合所有 finding 文件生成报告。**禁止直接写 report.md / results.sarif / 任何其他输出文件** — 这些由渲染器生成。

**4a. 按 detector 分组，以 finding ID 为文件名逐文件输出（每个文件 2-4KB）：**

每个 finding 写入独立文件，路径格式：
```
findings/<namespace>/<detector-name>/<finding-id>.json
```

**文件命名规则：直接使用 finding ID（业界最佳实践，对齐 SARIF/CodeQL/Semgrep）：**

finding ID 格式: `<SEVERITY>-<DETECTOR_ABBREV>-<FILE_SLUG>-L<LINE>`

| 组成部分 | 说明 | 唯一性 |
|---------|------|--------|
| `SEVERITY` | C/H/M/L/I | 同一行不同 detector = 不同 ID |
| `DETECTOR_ABBREV` | 3-5 字符缩写（SQLI, SSRF, CRYPTO...） | 不同 detector 不碰撞 |
| `FILE_SLUG` | 文件名去扩展名，特殊字符 → `_` | 不同文件不碰撞 |
| `L<LINE>` | 行号（L 前缀 + 数字） | 同行同 detector 只产一个 finding |

**为什么不会碰撞？** 同一行代码不会被同一 detector 重复报告。finding ID 天然保证全局唯一。

示例：
```
findings/web/sql-injection/H-SQLI-webapp-L47.json
findings/crypto/password-storage/H-CRYPTO-crypto_utils-L20.json
```

**单文件格式（遵循 `findings-schema.json` 中 `SingleFindingFile` schema）：**
```json
{
  "schema_version": "1.0",
  "finding": {
    "id": "H-SQLI-webapp-L47",
    "severity": "High",
    "cwe": "CWE-89",
    "detector": "web.sql-injection",
    "file": "src/webapp.py",
    "line": 47,
    "function": "get_user",
    "title": "SQL injection via f-string query construction",
    "fix_summary": "使用参数化查询替代 f-string 拼接",
    "location": { ... },
    "evidence": { ... },
    "impact": { ... },
    "fix": { ... },
    "sarif_specific": { ... }
  }
}
```

**Critical 优先输出**：按 Critical → High → Medium → Low 顺序输出，确保用户最关心的问题先落盘。

**4b. 输出轻量 `findings.json`（同名升级，不含四段式）：**

所有 finding 输出完毕后，写入轻量索引文件（scan root，与 `index.json` 同级）：

```json
{
  "scan_id": "<scan-id>",
  "command": "secguard",
  "path": "./src",
  "mode": "full",
  "language": "python",
  "timing": { "started": "<iso>", "completed": "<iso>", "duration_ms": 76000 },
  "scope": { "files": 3, "lines": 295, "functions": 15, "call_edges": 1 },
  "detectors": { "matched": 27, "executed": 27, "namespaces_used": [...] },
  "security_score": 0,
  "findings_index": [
    {
      "id": "H-SQLI-webapp-L47",
      "severity": "High",
      "cwe": "CWE-89",
      "detector": "web.sql-injection",
      "file": "src/webapp.py",
      "line": 47,
      "function": "get_user",
      "title": "SQL injection via f-string query construction",
      "path": "findings/web/sql-injection/H-SQLI-webapp-L47.json"
    }
  ]
}
```

> 索引文件不含四段式详情，仅含导航字段。企业级项目（1000+ finding）索引约 300KB，AI Agent 可直接读取。

**4c. 自检完整性（必须执行）：**

在写入所有文件后，执行以下脚本校验。**任一 ❌ → 补充缺失文件/内容 → 重新检查，最多 3 次。**

```bash
SCAN_DIR=".codeagent/secguard-secguardian/scans/<scan_id>"
python3 << 'PYEOF'
import json, os, sys

index_path = os.path.join(os.environ['SCAN_DIR'], 'findings.json')
with open(index_path) as f:
    idx = json.load(f)

expected = len(idx['findings_index'])
actual = 0
missing = []

for entry in idx['findings_index']:
    fpath = os.path.join(os.environ['SCAN_DIR'], entry['path'])
    if os.path.isfile(fpath):
        with open(fpath) as f:
            data = json.load(f)
        finding = data.get('finding', data)
        loc = finding.get('location', {})
        ev = finding.get('evidence', {})
        imp = finding.get('impact', {})
        fix = finding.get('fix', {})
        
        incomplete = []
        if not loc.get('file_path'): incomplete.append('location.file_path')
        if not loc.get('snippet'): incomplete.append('location.snippet')
        if not ev.get('judgment_rationale'): incomplete.append('evidence.judgment_rationale')
        if not imp.get('attack_scenario'): incomplete.append('impact.attack_scenario')
        if not fix.get('before_code'): incomplete.append('fix.before_code')
        if not fix.get('after_code'): incomplete.append('fix.after_code')
        
        if incomplete:
            missing.append(f"{entry['id']}: missing {', '.join(incomplete)}")
        else:
            actual += 1
    else:
        missing.append(f"{entry['id']}: file not found at {entry['path']}")

if missing:
    print(f"❌ {len(missing)} findings incomplete/missing:")
    for m in missing: print(f"  - {m}")
    sys.exit(1)
else:
    print(f"✅ All {actual}/{expected} findings present and complete")
PYEOF
```

3 次后仍未通过 → 在 `findings.json` 顶层添加 `"quality_gate_warning": ["<不完整的 finding ID>"]`。

**4d. 调用渲染器生成所有输出：**

```bash
# 定位渲染器（与索引器相同查找策略）
RENDERER=""
for base in "." "$HOME"; do
    for path in \
        ".opencode/extensions/secguardian/scripts/render-report.py" \
        ".config/opencode/extensions/secguardian/scripts/render-report.py" \
        ".gemini/extensions/secguardian/scripts/render-report.py" \
        ".claude/plugins/secguardian/scripts/render-report.py"; do
        candidate="$base/$path"
        [ -f "$candidate" ] && RENDERER="$candidate" && break 3
    done
done
# Fallback: project source
[ -z "$RENDERER" ] && [ -f "scripts/render-report.py" ] && RENDERER="scripts/render-report.py"

python3 "$RENDERER" \
    --findings-dir .codeagent/secguard-secguardian/scans/<scan_id>/findings/ \
    --index .codeagent/secguard-secguardian/scans/<scan_id>/index.json \
    --output .codeagent/secguard-secguardian/scans/<scan_id>/
```

渲染器自动生成: `report.md` + `results.sarif` + `summary.json` + `manifest.json` + `status.json` + `delta.json`。

> ⚠️ 如果渲染器不存在或执行失败，打印警告：`"Renderer unavailable — findings saved to findings/ directory tree only. Run: python3 scripts/render-report.py --findings-dir <path>/findings/ --index <path>/index.json --output <path>/"`

### Step 5: 输出摘要

- 渲染器执行完毕后，读取 `manifest.json` 获取扫描统计。
- 向用户输出 Markdown 格式的扫描摘要，包含：scan_id、检出总数、按严重度分组、Top 5 key findings。
- `duration_ms` 由渲染器根据 `findings.json` 中的时间戳自动计算。
