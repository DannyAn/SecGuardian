---
name: secguard
description: "安全加固项排查 — 67<!-- @secguardian:detector_count --> 个检测器覆盖 memory/concurrency/system/resource/crypto/web/error 7<!-- @secguardian:namespace_count --> 大安全分类"
---

# /secguard - 安全加固项排查

## ⚙️ Command Layer


对源码执行安全加固扫描。支持全量扫描和 Git diff 增量扫描，支持命名空间过滤和逗号组合。

## 使用方式

```
# ★ 零参数缺省调用（推荐）
/secguard                                            # 扫描当前目录，自动检测语言，运行所有检测器

# 显式指定路径和语言
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

## 输出路径约定

> ⚠️ 扫描输出的 `.codeagent/` 目录必须放在**用户项目根目录**下，不能放在 SecGuardian 项目根。
>
> 从 `<path>` 参数确定用户项目根目录：
> - 将 `<path>` 解析为绝对路径，取其**父目录**作为用户项目根
> - 例如 `/secaudit examples/myapp/src python` → 用户项目根 = `examples/myapp/`
> - 所有输出路径使用 `<user-project>/.codeagent/` 前缀（包括索引器、查找结果、渲染器）
> - 不要使用相对路径 `.codeagent/`（会跑到 SecGuardian 项目下）

## 输出

遵循 [Scan Output Protocol 3.0](../knowledge/protocols/scan-output.md)。人读/机读分离。

```
.codeagent/secguardian/secguard/scans/<scan-id>/
├── human/                    # ★ v7.0: 统一入口
│   └── executive-summary.md   一页仪表盘 + 发现分布 + 导航
├── findings/                 # 按检测器组织的发现目录树
├── ai/                       # ★ v7.0: AI 可消费
│   └── remediation-pack.json  AI 修复包（含关联发现）
├── report.md                 # ★ 人读审计报告 (精简 5 节)
├── dashboard.html               # ★ v7.0: 管理层 仪表盘
├── results.sarif             # 机读: SARIF 2.1.0 (CI/CD)
├── summary.json             # 仪表盘统计
├── manifest.json            # 扫描元数据 + 检出索引
├── status.json              # CI 门禁
└── delta.json               # 增量对比 (vs 上次扫描)
```

> **🚫 全路径权限弹窗优化**: 完成 `cd "$USER_PROJECT"` 后，所有项目内文件路径使用**相对路径**。
> 仅 `$SECGUARDIAN_HOME` 引用使用全路径（脚本和二进制在插件目录，不可避免）。
> 全路径操作触发 AI CLI permission system 逐项确权弹窗，中断扫描流程。

**执行完毕后必须输出扫描摘要和 scan-id：**

```
## secguard 扫描完成

Scan ID: sc-20260531-143000-a1b2
Project: <project-name>
Workspace: <user-project>
Path: ./src
Mode: full
Filters: memory.*, system.*

### 结果
- 扫描文件: 12, 扫描行: 450
- 检测器: 18 matched, 8 executed
- 检出: 3 (Critical: 1, High: 2)
- 安全评分: 45/100 🔴

### 检出
| # | Severity | Detector | File | 修复建议 |
|---------|----------|----------|------|---------|
| #1 | 🔴 Critical | memory.buffer-overflow | src/parser.c:36 | 使用 `snprintf(buf, sizeof(buf), ...)` 替代 `sprintf` |
| #2 | 🟠 High | memory.null-dereference | src/network.c:305 | malloc() 后检查 `if (!ptr) return ERR_NOMEM;` |
| #3 | 🟠 High | system.command-injection | src/executor.c:89 | 使用 `execve()` 参数数组替代 `system()` |

> 文件命名: `<SHA12>_<FILE_SLUG>-<LINE>.json` — 前 12 位 SHA-256 确保唯一性，后缀 _file-line 帮助定位。

📋 统一入口: `.codeagent/secguardian/secguard/scans/sc-20260531-143000-a1b2/human/executive-summary.md`
📄 完整报告: `.codeagent/secguardian/secguard/scans/sc-20260531-143000-a1b2/report.md`
🌐 仪表盘: `.codeagent/secguardian/secguard/scans/sc-20260531-143000-a1b2/dashboard.html`
🤖 AI 修复包: `.codeagent/secguardian/secguard/scans/sc-20260531-143000-a1b2/ai/remediation-pack.json`
📊 SARIF: `.codeagent/secguardian/secguard/scans/sc-20260531-143000-a1b2/results.sarif`
📋 索引: `.codeagent/secguardian/secguard/scans/sc-20260531-143000-a1b2/manifest.json`

💡 **如何使用扫描结果？**
- **快速看汇总** → 打开 `manifest.json`（JSON 索引，列出所有检出 ID/严重度/文件/行号）
- **★ 统一入口** → 打开 `human/executive-summary.md`（一页仪表盘 + 发现分布 + 导航）
- **👨‍💻 工程师修复** → 按检测器集中修复：`findings/<检测器>/`
- **🌐 管理层仪表盘** → 打开 `dashboard.html`（浏览器直接打开）
- **📄 安全工程师** → 打开 `report.md`（精简 5 节审计报告）
- **🤖 AI Agent 修复** → 读取 `ai/remediation-pack.json` 自动修复
- **📊 CI/CD 集成** → 消费 `results.sarif`（GitHub Code Scanning / GitLab SAST / Azure DevOps）
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


## 🛠️ Engine Layer

> 以下内容属于 Engine 职责（参见 `internal/engine/engine_contract.md`）。当前由 LLM prompt 代行执行。未来 Engine 实现后，此处内容将被 Engine 取代。
>
> 🚫 **不要使用 `todowrite` 工具。** 使用原生 task 系统（`TaskCreate` + `TaskUpdate`）追踪进度。
> `todowrite` 每次调用重传全部已完成项，每会话浪费 ≥50KB 无效 token。
>
> 🚫 **不要硬编码 `RECORDER` 路径。** 必须使用 `$SECGUARDIAN_HOME/scripts/record-finding.py`。
> 硬编码路径在安装位置变动时全断。

## 派发规则与执行步骤

> **隔离约束**: 本命令只能加载 `$SECGUARDIAN_HOME/skills/` 下的 `secguard-*` 前缀 skill，禁止加载 `secaudit-*` 或 `secreview-*` 前缀的任何文件。知识文件仅从 `.codeagent/secguardian/knowledge/guard-rules/` 和 `.codeagent/secguardian/knowledge/languages/` 加载（已在 Step 1 拷贝到项目内，避免外部目录权限弹窗）。

你（AI Agent）在接收到 `/secguard` 命令后，必须按以下步骤执行来构建索引并进行安全扫描。

### Step 1: 初始化（唯一 bash 调用，禁止拆分）

> ⚠️ 这是**唯一一次预初始化 bash 调用**，必须一次性完成：自动发现 → 健康检查 → 路径确认 → 建目录 → 写入 `.scan_state.secguard`。
> **禁止**在 Step 1 前后插入任何独立的 bash 命令（如 `ls "$SECGUARDIAN_HOME/scripts/"`）— 那会在新 shell 中丢失变量且无意义。
> `$SECGUARDIAN_HOME/scripts/` 已在自动发现中验明存在，无需冗余 `ls` 确认。

- **⏳ 首选生成 scan_id**（格式: `sc-YYYYMMDD-HHMMSS-xxxx`，`xxxx` 为随机4位字符）。
- **scan_id 一旦生成，后续所有路径必须使用此 scan_id。**

```bash
# ===== 阶段 A: SECGUARDIAN_HOME 自动发现 =====
if [ -z "$SECGUARDIAN_HOME" ] || [ ! -d "$SECGUARDIAN_HOME/scripts" ]; then
    for candidate in \
        "/root/.config/opencode/extensions/secguardian" \
        "$HOME/.config/opencode/extensions/secguardian" \
        "$HOME/.claude/plugins/secguardian" \
        "$HOME/.gemini/extensions/secguardian" \
        "."; do
        if [ -f "$candidate/scripts/record-finding.py" ]; then
            export SECGUARDIAN_HOME="$candidate"
            echo "SECGUARDIAN_HOME=$SECGUARDIAN_HOME"
            break
        fi
    done
fi
if [ -z "$SECGUARDIAN_HOME" ] || [ ! -d "$SECGUARDIAN_HOME/scripts" ]; then
    echo "FATAL: Cannot locate secguardian installation (no SECGUARDIAN_HOME with scripts/)"
    echo "  Tried: /root/.config/opencode/extensions/secguardian, ~/.config/opencode/extensions/secguardian, ..."
    exit 1
fi

# ===== 阶段 B: 索引器健康检查 =====
if ! "$SECGUARDIAN_HOME/scripts/secguardian-index" --health; then
    echo "FATAL: secguardian-index health check failed"
    exit 1
fi

# ===== 阶段 C: 扫描路径确认 =====
test -d "<path>" || { echo "FATAL: scan path <path> not found"; exit 1; }

# ===== 阶段 D: 创建扫描目录 & 知识库拷贝 =====
SCAN_ID="sc-$(date +%Y%m%d-%H%M%S)-$(openssl rand -hex 2)"
SCAN_DIR="$USER_PROJECT/.codeagent/secguardian/secguard/scans/$SCAN_ID"
mkdir -p "$SCAN_DIR" "$USER_PROJECT/.codeagent/secguardian/knowledge"
cp -r "$SECGUARDIAN_HOME/knowledge/." "$USER_PROJECT/.codeagent/secguardian/knowledge/"

# ===== 阶段 E: 持久化状态到 .scan_state.secguard =====
cat > ".codeagent/secguardian/.scan_state.secguard" << STATEEOF
USER_PROJECT="$USER_PROJECT"
SCAN_ID="$SCAN_ID"
SCAN_DIR="$SCAN_DIR"
SECGUARDIAN_HOME="$SECGUARDIAN_HOME"
STATEEOF
echo "SCAN_DIR=$SCAN_DIR"
```

### 🔒 跨 Shell 状态传递规则（Step 1 之后所有 bash 调用）

> **每个 bash 调用都是独立 shell，变量不共享。禁止用 `/tmp/` 或任何系统临时目录传状态。**

Step 1 已在 `.scan_state.secguard` 中持久化 `SCAN_ID`、`SCAN_DIR`、`USER_PROJECT`、`SECGUARDIAN_HOME`。
从 Step 2 开始，**每个 bash 调用第一行必须是**：
```bash
source .codeagent/secguardian/.scan_state.secguard
```
此后 `$SCAN_DIR`、`$SCAN_ID`、`$USER_PROJECT`、`$SECGUARDIAN_HOME` 均可直接使用。**禁止用 `cat /tmp/*.txt`**。
`/tmp/` 在 Windows 不可用、触发 macOS 确权弹窗、且多用户不安全。
>
> **📂 知识库本地拷贝**: 知识库文件（guard-rules、language-index、protocols）已在 Step 1 拷贝到 `.codeagent/secguardian/knowledge/`。
> - `read` 工具读取检测器规则时，必须使用 `.codeagent/secguardian/knowledge/` 相对路径
> - 禁止使用 `$SECGUARDIAN_HOME/knowledge/` 全路径（触发 OpenCode 外部目录权限弹窗）
> - bash 操作也优先使用 `.codeagent/secguardian/knowledge/` 路径

### Step 2: 构建语义索引（必须执行，不可跳过）

> ⚠️ 这是扫描的**核心前置步骤**。索引器提供符号表、调用图、alloc/free 配对，是后续检测器执行的结构化上下文。**不执行此步骤将导致扫描质量严重下降。**

**2a. 执行索引器（阻塞等待完成）：**
> 索引自动复用同路径缓存。加 `--force` 强制重建。

```bash
# SECGUARDIAN_HOME 已在 Pre-flight 中自动发现
INDEXER="$SECGUARDIAN_HOME/scripts/secguardian-index"
if [ ! -f "$INDEXER" ]; then
    echo "FATAL: secguardian-index not found at $INDEXER"
    exit 1
fi
echo "Using: $INDEXER"
# 超时保护: timeout 30s，防止索引器挂死。macOS 需要 brew install coreutils。
if command -v timeout &>/dev/null; then
    timeout 30 "$INDEXER" --lang <language> --path <path> --output "$USER_PROJECT/.codeagent/secguardian/index.json" || {
        echo "FAIL: Indexer timed out after 30s or failed — cannot continue"
        echo "  Large codebases: use --skip-index to skip indexing (falls back to regex parser)."
        echo "  macOS: brew install coreutils  (provides 'timeout' command)"
        exit 1
    }
elif command -v gtimeout &>/dev/null; then
    gtimeout 30 "$INDEXER" --lang <language> --path <path> --output "$USER_PROJECT/.codeagent/secguardian/index.json" || {
        echo "FAIL: Indexer timed out after 30s or failed — cannot continue"
        exit 1
    }
else
    echo "WARNING: 'timeout' not found — indexer runs without timeout protection"
    echo "  Install coreutils: brew install coreutils (macOS) or apt install coreutils (Linux)"
    "$INDEXER" --lang <language> --path <path> --output "$USER_PROJECT/.codeagent/secguardian/index.json"
fi
if [ ! -f ""$USER_PROJECT/.codeagent/secguardian/index.json"" ]; then
    echo "FATAL: Indexer failed — cannot continue"
    exit 1
fi
```

**2b. 验证索引完整性 + 生成结构化摘要（必须通过）：**

执行以下脚本。若返回非 0，**立即终止扫描**并向用户报告索引生成出错。
若成功，直接读取输出的 JSON 摘要作为后续所有步骤的上下文，**禁止自己写 Python 或 shell 去重新解析 index.json**。

> ⚠️ 此脚本自动处理不同语言索引器输出差异（如 Java 索引器可能不生成调用图），
> 对 `None`/`null` 值安全。如果索引文件路径不对，会 exit 1。

```bash
python3 "$SECGUARDIAN_HOME/scripts/validate-index.py" \
    --index .codeagent/secguardian/index.json \
    --scan-id <scan_id>
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

**finding 字段检查清单 — 每个 finding 必须包含以下所有字段，否则 validate-findings.py 将拒绝：**

| 路径 | 必填 | 字段名（注意全用小写 snake_case） |
|------|------|----------------------------------|
| `finding.severity` | ✅ | Critical/High/Medium/Low/Info |
| `finding.severity` | ✅ | Critical/High/Medium/Low/Info |
| `finding.cwe` | ✅ | CWE 编号，如 CWE-89 |
| `finding.detector` | ✅ | 必须用 `namespace.name` 格式 |
| `finding.file` | ✅ | 源码文件路径 |
| `finding.line` | ✅ | 行号 |
| `finding.location.file_path` | ✅ | `file_path`，不是 `file` |
| `finding.location.start_line` | ✅ | 起始行号 |
| `finding.location.snippet` | ✅ | `snippet`，不是 `code_snippet` |
| `finding.evidence.code_context` | ✅ | 代码上下文 |
| `finding.evidence.judgment_rationale` | ✅ | 判断依据 |
| `finding.impact.attack_scenario` | ✅ | `attack_scenario`，不是 `attack_path` |
| `finding.impact.cvss_score` | ✅ | CVSS 评分 |
| `finding.fix.before_code` | ✅ | `before_code`，不是 `code_before` |
| `finding.fix.after_code` | ✅ | `after_code`，不是 `code_after` |

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

#### 2.5b 确定读取范围 — index.json 符号表即唯一扫描清单

> ⚠️ **index.json.symbols.functions 已是完整的函数→文件:行号 映射。不需要衍生文件。**

读取 index.json 后，`symbols.functions` 就是 LLM 的唯一定位依据：

```json
// index.json 已包含:
{
  "symbols": {
    "functions": [
      {"name": "parse_task_name", "file": "src/parser.c", "start_line": 26, "end_line": 50},
      {"name": "format_task_desc", "file": "src/parser.c", "start_line": 39, "end_line": 65}
    ]
  },
  "alloc_free": {"pairs": [...]},
  "lock_graph": {"mutexes": [...]}
}
```

> **🔒 强制读取规则 (NON-NEGOTIABLE):**
>
> 1. **读取范围 = `index.json.symbols.functions` 中的所有条目。** 每个条目的 `file`+`start_line` 即读取起点。读取 ±10 行上下文。
> 2. **不读符号表外的代码。** `symbols.functions` 中没有的文件 → 不读。符号表中没有的函数 → 不分析。
> 3. **检测器预筛基于函数名。** 对每个检测器，在 `symbols.functions` 中查找关联函数名（如 `strcpy`→buffer-overflow，`system`→command-injection）。无关联函数 → 跳过该检测器，报告 "Skipped: no matching symbol in index"。
> 4. **alloc_free + lock_graph 作为补充信号。** 内存检测器查阅 `alloc_free.pairs`，并发检测器查阅 `lock_graph.mutexes`。
> 5. **`--no-signal-filter`**: 用户可加此标志跳过预筛，执行全部检测器 + 读取全部文件。

### Step 3: 语言与检测器匹配

> **原则**: 检测器选择由命令的 `language` 参数 + `filter` 参数决定，**不做额外的自动筛选**。
> 默认（无 filter）= 该语言适用的**全部**检测器 = 全量安全扫描。

#### 3a 语言确定

- 如果用户在命令中提供了 `language` 参数（如 `/secguard ./src cpp` 或 `/secguard ./src c`），直接使用该值
  - ⚠️ `c` 和 `cpp` 共享同一套检测器规则，language-index.md 中包含 `## c` 和 `## cpp` 两个等价节
  - 如果用户说 `c`，从 `## c` 节读取规则；如果用户说 `cpp`，从 `## cpp` 节读取
- 如果用户未显式提供，从 Step 2b 生成的 index.json 摘要中的 `primary_language` 自动推断

#### 3b 读取语言索引

用 bash 定位并读取文件（禁止 Glob/Read）：

```bash
LANG_INDEX=".codeagent/secguardian/knowledge/language-index.md"
[ ! -f "$LANG_INDEX" ] && echo "WARNING: language-index.md not found" && LANG_INDEX="/dev/null"
data=$(cat "$LANG_INDEX")
echo "$data"
```

然后用 `echo "$data" | grep ...` 定位到 `## {language}` 节。

该文件按语言预分组了所有适用的规则。示例：cpp 节包含 `guard-rules/buffer-overflow`、`audit-rules/cryptography`、`review-rules/cpp` 等。

AI 只需读取 `## cpp` 以下至下一个 `##` 之间的内容即获得完整的语言规则清单——不需解析 JSON，不需遍历全部文件。

> 此外还需要读取对应语言的画像文件（dangerous API 列表、框架安全配置）。使用 bash `cat` 从项目内本地拷贝读取（避免 OpenCode 外部目录权限弹窗）：

```bash
LANG_PROFILE=".codeagent/secguardian/knowledge/languages/<language>.md"
if [ -f "$LANG_PROFILE" ]; then
    echo "=== Language Profile ==="
    cat "$LANG_PROFILE"
fi
```

#### 3c 应用 filter 裁剪

- 无 filter 或 `all` 或 `*` → 使用该语言下的**全部**规则
- `namespace.*`（如 `memory.*`）→ 只保留该命名空间的 guard-rules
- `namespace.name`（如 `memory.null-dereference`）→ 只加载单个检测器
- 逗号分隔（如 `memory.*,system.*`）→ 取并集
- 检测器文件路径：`.codeagent/secguardian/knowledge/guard-rules/{namespace-name}.md`
  （`read` 工具和 `cat` 优先用此相对路径，避免 OpenCode 外部目录权限弹窗）

#### 3d 精确加载

从裁剪后的清单中，精确加载每个检测器的 .md 文件（不遍历、不猜测）。

#### 3e 排序与执行

- 按 Critical → High → Medium → Low → Info 排序执行
- 增量模式（`git diff`）下，仅分析由 diff 识别的变更行

> **不要向用户确认**，直接进入后续步骤。默认无 filter = 全量扫描。

> ⚠️ **🚫 禁止将检测执行委托给子代理 (NON-NEGOTIABLE):**
> YOU are the detection engine. Your analysis (reading index.json symbols + loading guard-rules + reading target functions) IS the scanner.
> - ❌ 不允许启动 background task / sub-agent 来执行检测器
> - ❌ 不允许用 grep/find 全文件扫描（必须通过 index.json 符号表定位目标函数）
> - ✅ 正确做法：在当前上下文中，逐一读取 guard-rules → 查 index.json 符号表找到关联函数 → 读取该函数代码 → 应用检测逻辑 → 用 record-finding.py 记录 finding
>
> **为什么？** sub-agent 无法访问 index.json 和 guard-rules，只能全量 grep 642 个文件，完全绕过了索引器体系。

<!-- @secguardian:non-skippable step=validate -->
> **🚫 此验证步骤不可跳过。跳过验证不会加速扫描——验证减低了误报，是报告前的强制性安全检查。**
> 如果必须跳过（如极短时间内重复测试），显式加 `--no-verify` flag（但在正式扫描中不鼓励）。

### Step 3.5: 三轮验证管道（误报消减）

> ⚠️ 这是 v6.0 新增的验证步骤。在 Detector 产出 Finding 后、渲染报告前，执行三轮独立验证对每个 Finding 进行证据认证，最大化降低误报。
> 跳过验证: 在命令末尾加 `--no-verify` flag（会触发 self-check 警告）。

**3.5a. 加载验证协议（多路径搜索）：**

与其他 secguardian 模块相同，协议文件部署在插件目录下，需要多路径搜索定位：

```bash
find_protocol() {
    PROTOCOL=".codeagent/secguardian/knowledge/protocols/verification-protocol.md"
    [ -f "$PROTOCOL" ] && echo "$PROTOCOL" || echo ""
}
if [ -n "$(find_protocol)" ]; then
    echo "Using: $(find_protocol)"
else
    echo "WARNING: verification-protocol.md not found across all searched paths — 跳过验证管道"
fi
```

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
SCAN_DIR=".codeagent/secguardian/secguard/scans/<scan_id>"

# dismissed.json — 被抑制的 Finding + 原因 + 轮次
# verification-audit.json — 完整验证链 + 每轮收敛统计
```

**3.5f. 自检完整性：**

```bash
SCAN_DIR=".codeagent/secguardian/secguard/scans/<scan_id>"
export SCAN_DIR
python3 << 'PYEOF'
import json, os, sys

scan_dir = os.environ['SCAN_DIR']

# Check dismissed.json
with open(os.path.join(scan_dir, 'dismissed.json')) as f:
    dismissed = json.load(f)
for d in dismissed['dismissed']:
    assert d['finding_id'], f"Missing finding_id in dismissed entry"
    assert d['dismissed_at_round'] in ('P1', 'P2', 'P3'), "Invalid round: %s" % d['dismissed_at_round']
    assert d['dismiss_reason'], "Missing dismiss_reason for %s" % d['finding_id']

# Check verification-audit.json
with open(os.path.join(scan_dir, 'verification-audit.json')) as f:
    audit = json.load(f)
for round_key in ('p1_semantic', 'p2_counter_evidence', 'p3_court'):
    assert round_key in audit['rounds'], "Missing round: %s" % round_key

certified = audit['certified_count']
dismissed_total = audit['dismissed_count']
findings_total = len(json.load(open(os.path.join(scan_dir, 'findings.json'))).get('findings', []))
assert certified + dismissed_total == findings_total, \
    "Count mismatch: %s + %s != %s" % (certified, dismissed_total, findings_total)

print("✅ Verification audit: %s findings → %s certified, %s dismissed" % (findings_total, certified, dismissed_total))
PYEOF
```

### Step 4: 输出结构化 findings（遵循 Findings Protocol v5.0）

> ⚠️ **唯一输出路径**: 所有 findings 必须通过 `record-finding.py` 逐条录制到 `findings/` 目录树下。
> **禁止 AI 手写 `findings.json`。** `findings.json` 由 `render-report.py` 从 `findings/` 目录树自动聚合生成。
> 渲染器调用: `python3 render-report.py --findings-dir <dir>/findings/ --output <dir>`
> 参见 `internal/output/output_contract.md`。
>
> 调用 `record-finding.py`（通过多路径搜索定位）记录每个 finding：
>
> **🔗 锚定+证据约束 (engine_contract.md Rule A + Rule B):**
> - 每个 finding 的 `file`+`line` MUST 可追溯到 index.json 的符号或文件列表
> - 每个 finding MUST 提供 `--snippet`（漏洞代码行）、`--code-context`（上下文）、`--rationale`（判断依据）
> - MUST 传 `--index-json` 进行锚定校验
> - 无 index 锚点的 finding MUST 标记 `confidence: low` 并说明原因

```bash
RECORDER="$SECGUARDIAN_HOME/scripts/record-finding.py"

# ⚠️ MUST use heredoc with --from-stdin. NEVER pass code as inline CLI args.
# The 'RECEOF' delimiter is single-quoted → zero shell expansion → zero quoting bugs.
python3 "$RECORDER" \
    --command secguard \
    --scan-dir .codeagent/secguardian/secguard/scans/<scan_id> \
    --from-stdin << 'RECEOF'
{
  "command": "secguard",
  "detector": "<namespace.name>",
  "severity": "Critical",
  "cwe": "CWE-89",
  "file": "src/UserController.java",
  "line": 52,
  "function": "getUser",
  "title": "SQL injection via string concatenation",
  "snippet": "String query = \"SELECT * FROM users WHERE name = '\" + username + \"'\";",
  "code_context": "public User getUser(String username) {\n    String query = \"SELECT * FROM users WHERE name = '\" + username + \"'\";\n    return jdbcTemplate.query(query, ...);\n}",
  "rationale": "User input concatenated into SQL — violates OWASP A03:2021 Injection",
  "attack_scenario": "Attacker provides ' OR '1'='1' -- to bypass auth and dump all users",
  "cvss": 9.8,
  "fix_before": "String query = \"SELECT * FROM users WHERE name = '\" + username + \"'\";",
  "fix_after": "String query = \"SELECT * FROM users WHERE name = ?\";\nPreparedStatement ps = conn.prepareStatement(query);\nps.setString(1, username);",
  "index_json": ".codeagent/secguardian/index.json"
}
RECEOF
```

输出：`findings/<ns>/<detector>/<sha12>_<file>-<line>.json`
> `findings.json` 由渲染器从 `findings/` 目录树自动聚合。禁止 AI 手写。


**4a. 按 detector 分组，以 SHA 前缀为文件名逐文件输出（每个文件 2-4KB）：**

每个 finding 写入独立文件，路径格式：
```
findings/<namespace>/<detector-name>/<finding-id>.json
```

**文件命名规则：SHA-256 前缀 + 文件-行号后缀（对齐 SARIF partialFingerprints）：**

文件命名: `<SHA12>_<FILE_SLUG>-<LINE>.json`

| 组成部分 | 说明 | 唯一性 |
|---------|------|--------|
| `SHA12` | SHA-256(`detector:file:line:cwe`) 前 12 hex | 不同输入几乎零碰撞 |
| `FILE_SLUG` | 文件名去扩展名，无缩写 | 工程师快速定位 |
| `LINE` | 行号（纯数字，无前缀） | 同行同 detector 只产一个 finding |

**为什么不会碰撞？** SHA-256 以 `detector:file:line:cwe` 为输入，不同输入的输出碰撞概率 < 2^-48。同一行同一 detector 只报告一次，filename 天然唯一。

示例：
```
findings/web/sql-injection/a1b2c3d4e5f6_webapp-47.json
findings/crypto/password-storage/f6e5d4c3b2a1_crypto_utils-20.json
```

**单文件格式（遵循 `findings-schema.json` 中 `SingleFindingFile` schema）：**
```json
{
  "schema_version": "1.0",
  "finding": {
    "severity": "High",
    "cwe": "CWE-89",
    "detector": "web.sql-injection",
    "file": "src/webapp.py",
    "line": 47,
    "function": "get_user",
    "title": "SQL injection via f-string query construction",
    "fix_summary": "使用参数化查询替代 f-string 拼接",
    "partialFingerprints": [
      {"algorithm": "SHA-256", "value": "a1b2c3d4e5f6..."}
    ],
    "location": {
      "file_path": "src/webapp.py",
      "start_line": 47,
      "function_name": "get_user",
      "snippet": "cursor.execute(f\"SELECT * FROM users WHERE id = USER_INPUT\")"
    },
    "evidence": {
      "code_context": "cursor.execute(f\"...USER_INPUT...\")",
      "judgment_rationale": "用户输入直接拼接 SQL — 违反 OWASP A03:2021"
    },
    "impact": {
      "attack_scenario": "攻击者通过 SQL 注入窃取所有用户数据",
      "cvss_score": 9.8
    },
    "fix": {
      "description": "使用参数化查询替代 f-string 拼接",
      "before_code": "cursor.execute(f\"...USER_INPUT\")",
      "after_code": "cursor.execute(\"SELECT * FROM users WHERE id = ?\", (user_id,))"
    }
  }
}
```

**Critical 优先输出**：按 Critical → High → Medium → Low 顺序输出，确保用户最关心的问题先落盘。

**4b. 轻量 `findings.json` — 由渲染器自动生成：**

> `render-report.py` 会在 `--output` 目录下自动生成 `findings.json`，
> 从 `findings/` 目录树聚合 `findings_index`。
> AI 无需手动编写 findings.json，只需录制 finding 文件后调用渲染器即可。
>
> 索引文件不含四段式详情，仅含导航字段。企业级项目（1000+ finding）索引约 300KB。

**4c. 自检完整性：**

对所有 finding 执行前置校验。校验发现的问题会用警告列出。

```bash
SCAN_DIR=".codeagent/secguardian/secguard/scans/<scan_id>"
python3 "$SECGUARDIAN_HOME/scripts/validate-findings.py" --findings-dir "$SCAN_DIR/findings/"
VALIDATE_EXIT=$?
if [ $VALIDATE_EXIT -eq 0 ]; then
    echo "  ✅ All findings pass validation"
else
    echo "  ⚠️  Findings validation completed with warnings — proceeding to renderer"
fi
```

> 校验结果不阻塞渲染。validate-findings.py 的警告项可通过后续手动检查确认。

**4d. 调用渲染器生成所有输出：**

```bash
# 定位渲染器（与索引器相同查找策略）
RENDERER="$SECGUARDIAN_HOME/scripts/render-report.py"

python3 "$RENDERER" \
    --command secguard \
    --scan-id "$SCAN_ID" \
    --findings-dir .codeagent/secguardian/secguard/scans/<scan_id>/findings/ \
    --index .codeagent/secguardian/index.json \
    --output .codeagent/secguardian/secguard/scans/<scan_id>/
```

渲染器自动生成: `report.md` + `results.sarif` + `summary.json` + `manifest.json` + `status.json` + `delta.json`。

> ⚠️ 如果渲染器不存在或执行失败，打印警告：`"Renderer unavailable — findings saved to findings/ directory tree only. Run: python3 $SECGUARDIAN_HOME/scripts/render-report.py --findings-dir <path>/findings/ --index <path>/index.json --output <path>/"`

### Step 5: 输出摘要

- 渲染器执行完毕后，读取 `manifest.json` 获取扫描统计。
- 向用户输出 Markdown 格式的扫描摘要，包含：scan_id、检出总数、按严重度分组、Top 5 key findings。
- `duration_ms` 由渲染器根据 `findings.json` 中的时间戳自动计算。
  不影响示例代码在测试环境中的使用。"

## 📄 Output Layer

> 以下输出格式遵循 `internal/output/output_contract.md`。

## secguard 扫描完成

Scan ID: <scan-id>
Project: <project-name>
Workspace: <user-project>
Path: ./src
Mode: full | Language: python | Filters: all

### 结果
- 扫描文件: 3, 扫描行: 295
- 检测器匹配: N matched, M executed
- 检出: N (Critical: X, High: Y, Medium: Z)
- 安全评分: XX/100

### 检出
| # | Severity | Detector | File | 修复建议 |
|---|---|---|---|---|
| #1 | 🔴 Critical | web.sql-injection | UserController.java:47 | 使用 PreparedStatement |
| ... | ... | ... | ... | ... |

### 输出文件
📋 统一入口: `.codeagent/.../human/executive-summary.md`
📄 完整报告: `.codeagent/.../report.md`
🌐 仪表盘: `.codeagent/.../dashboard.html`
🤖 AI 修复包: `.codeagent/.../ai/remediation-pack.json`
📊 SARIF: `.codeagent/.../results.sarif`
📋 索引: `.codeagent/.../manifest.json`

💡 **如何使用扫描结果？**
- **快速看汇总** → 打开 `manifest.json`
- **★ 统一入口** → `human/executive-summary.md`
- **👨‍💻 工程师修复** → 按检测器：`findings/<检测器>/`
- **🌐 管理层仪表盘** → 浏览器打开 `dashboard.html`
- **📄 安全工程师** → 打开 `report.md`
- **🤖 AI Agent 修复** → `/secfix <scan-id>` 自动修复
- **📊 CI/CD 集成** → 消费 `results.sarif`

