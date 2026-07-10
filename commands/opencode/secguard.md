---
name: secguard
description: "[OpenCode] 安全加固检视 — 信号驱动的检测引擎，Worker 串行内联执行（上下文预算控制），文件优先记录 finding"
platform: opencode
---

# /secguard — Dispatcher Protocol v2 (EPIC-3) [OpenCode]

## Command Layer

对源码执行安全加固扫描。采用 Investigation Engine 架构：Dispatcher 信号提取 → Hypothesis Generator 多假设 → Investigator 自主取证 → Judge 独立裁决。

支持全量扫描和 Git diff 增量扫描。

### 使用方式

```
# ★ 零参数缺省调用（推荐）
/secguard                                            # 扫描当前目录，自动检测语言，运行所有 Skill

# 显式指定路径和语言
  /secguard ./src cpp                                # C/C++ 全量
  /secguard ./src python                             # Python 全量
  /secguard ./src java                               # Java 全量

# Skill 过滤:
  /secguard ./src cpp memory.*                       # 仅内存安全 Skill
  /secguard ./src cpp memory.buffer_overflow         # 单个 Skill
  /secguard ./src cpp memory.*,exec.*,crypto.*       # 多组合（逗号并集）
  /secguard ./src python crypto.*                    # 仅加密 Skill

# 增量扫描:
  /secguard ./src cpp git diff                       # 工作区变更
  /secguard ./src cpp git diff HEAD~1                # 最近一次提交
  /secguard ./src cpp git diff main                  # 当前分支 vs main
  /secguard ./src cpp git diff main...feature        # 分支差异

# SARIF 输出 (CI/CD 集成):
  /secguard ./src python --sarif                     # 附加 SARIF 2.1.0 输出
  /secguard ./src cpp memory.* --sarif               # 过滤 + SARIF
```

### 输出路径约定

> 扫描输出的 `.codeagent/` 目录必须放在**用户项目根目录**下，不能放在 SecGuardian 项目根。
>
> 从 `<path>` 参数确定用户项目根目录：
> - 将 `<path>` 解析为绝对路径，取其**父目录**作为用户项目根
> - 例如 `/secguard examples/myapp/src cpp` → 用户项目根 = `examples/myapp/`
> - 所有输出路径使用 `<user-project>/.codeagent/` 前缀（包括索引器、Worker 输出、渲染器）
> - 不要使用相对路径 `.codeagent/`（会跑到 SecGuardian 项目下）

### 输出

遵循 [Scan Output Protocol 8.0](../knowledge/protocols/scan-output.md)。人读/机读分离。

```
.codeagent/secguardian/secguard/scans/<scan-id>/
├── human/                       # ★ v7.0: 统一入口
│   └── executive-summary.md      一页仪表盘 + 发现分布 + 导航
├── findings/                    # 按检测器组织的发现目录树（所有 Worker 汇总）
├── ai/                          # ★ v7.0: AI 可消费
│   └── remediation-pack.json     AI 修复包（含关联发现）
├── workers/                     # ★ v2: Worker 执行产物（调试用）
│   └── <skill_id>/              每个 Worker 的执行日志、盲区报告、中间产物
├── report.md                    # ★ 人读审计报告 (精简 5 节)
├── dashboard.html                  # ★ v7.0: 管理层仪表盘
├── results.sarif                # 机读: SARIF 2.1.0 (CI/CD)
├── summary.json                 # 仪表盘统计
├── manifest.json                # 扫描元数据 + 检出索引
├── status.json                  # CI 门禁
├── delta.json                   # 增量对比 (vs 上次扫描)
└── worker_manifest.json         # ★ v2: Worker 调度清单 + 盲区汇总
```

> **全路径权限弹窗优化**: 完成 `cd "$USER_PROJECT"` 后，所有项目内文件路径使用**相对路径**。
> 仅 `$SECGUARDIAN_HOME` 引用使用全路径（脚本和二进制在插件目录，不可避免）。
> 全路径操作触发 AI CLI permission system 逐项确权弹窗，中断扫描流程。

---

## Engine Layer — Dispatcher Protocol v2

> 本协议实现 EPIC-3 架构重构。从"LLM 全权扫描"（加载 67 规则 × 遍历 642 文件）转变为"信号驱动的 Investigation Pipeline"（索引器预扫描 → Dispatcher 信号提取 → Hypothesis Generator → Investigator → Judge）。
>
> 所有共享架构信息以 [`AGENTS.md`](../AGENTS.md) 为准。
>
> **隔离约束**: Dispatcher 只能加载 `$SECGUARDIAN_HOME/skills/secguard-<language>/` 下的 Skill，禁止加载 `skills/secaudit-secaudit/` 或 `skills/secreview-<language>/` 下的任何文件。知识文件从 `$SECGUARDIAN_HOME/knowledge/` 用 bash `cat` 按需读取。
>
> 🚫 **不要使用 `todowrite` 工具。** 使用原生 task 系统追踪进度。
> 🚫 **不要硬编码 `RECORDER` 路径。** 必须使用 `$SCRIPTS_DIR/record-finding.py`。
> 🚫 **禁止用 `read` 工具读取 `$SCRIPTS_DIR/` 下的脚本文件。** 所有脚本通过 `Bash` 工具执行。

### 调度架构概览

```
┌──────────────────────────────────────────────────────────────┐
│                    Dispatcher (本协议)                          │
│                                                               │
│  Phase 1: 索引与信号生成                                       │
│    1. secguardian-index --path → index.json (含 7 信号类型)   │
│    2. secguard 信号: S1 call_sites + S2 string_literals    │
│    3. 从 call_sites 提取信号，按 category 分组                  │
│    4. 从 string_literals 分发到 hardcoded_secrets             │
│    5. 输出 Signal Summary 给 Hypothesis Generator                                     │
│                                                               │
│  Phase 2: 信号移交给 Investigation Pipeline                     │
│    所有 Signal 传递给 Hypothesis Generator (SKILL.md):             │
│      - 输入: 信号清单 + 源码上下文 + index.json                    │
│      - H1: 此调用有何风险?                                      │
│      - H2: 参数是否可控?                                       │
│      - H3: 边界条件?                                           │
│      - Investigator: 针对每个 Hypothesis 自主调查 Evidence         │
│      - Judge: 独立裁决 (Confirmed / Suspicious / Safe / Unknown)  │
│                                                               │
│  Phase 3: 汇总与渲染                                           │
│    1. 合并所有 Worker findings                                  │
│    2. 去重（同一调用点多 Skill → 最高严重度）                    │
│    3. 渲染 report.md + SARIF + summary.json + status.json       │
└──────────────────────────────────────────────────────────────┘
```

### Signal Type 分类 (Investigation Engine — EPIC-010)

> **Dispatcher 不判定漏洞类型。** Signal 只是调查入口，不是结论。
> 错误: `malloc → Null Dereference Skill`
> 正确: `malloc → Signal(memory allocation)`
>
> 🚫 Dispatcher 禁止：
> - 判断漏洞类型（不得将 Signal 映射为 buffer_overflow/null_dereference 等）
> - Suppress 或 Confirm 任何信号
> - 限制调查方向（不得指定"只看什么漏洞"）
>
> Dispatcher 只做：建立索引 → 提供上下文 → 输出 Signal 清单。

```
┌─ Signal Type 分类 ────────────────────────────────────────┐
│ 操作类型               →  Signal Type                        │
├───────────────────────────────────────────────────────────┤
│ malloc / calloc / realloc →  memory_allocation              │
│ memcpy / memmove         →  memory_copy                     │
│ strcpy / strcat / sprintf →  string_copy                    │
│ getenv / scanf / read    →  user_input                      │
│ system / popen / exec    →  exec_operation                  │
│ pthread_mutex_lock       →  lock_operation                  │
│ free / delete            →  memory_deallocation             │
│ fopen / open / socket    →  resource_acquire                │
│ snprintf / gets / others →  string_copy                     │
├───────────────────────────────────────────────────────────┤
│ 非 call_site 信号:                                         │
│ string_literals (secret/password/token) →  credential       │
│ control_flow (guard patterns)          →  guard_pattern     │
```

**每信号至少 3~5 个 Hypothesis（由 Hypothesis Generator 负责，非 Dispatcher 职责）:**
- `memory_allocation` → H1: NULL 未检查 / H2: Double Free / H3: Memory Leak / H4: Ownership 错误 / H5: 实际安全
- `memory_copy` → H1: 长度错误 / H2: 来源污染 / H3: 整数溢出导致长度错误 / H4: 生命周期错误 / H5: 实际安全
- `string_copy` → H1: 缓冲区溢出 / H2: 来源污染 / H3: 截断导致逻辑错误 / H4: Underflow / H5: 实际安全

### ★ Detector Naming Convention（输出规范 — 仅用于 finding 输出，非调度用途）

> **注意：** Detector 命名仅用于 finding 输出格式规范，不用于信号分派。
> Dispatcher 不再按 category → Skill 映射分派 Worker。
> 本表仅确保 AI Agent 在输出 finding 时使用正确的 detector ID 格式。
> 🚫 禁止用本表将 Signal 路由到特定 Worker。那是 Hypothesis Generator 的职责。

**每个 finding 的 `detector` 字段必须使用精确的规范名**（`{language}.{rule_name}`）。
**根据 `$SCAN_LANG` 选择对应语言的探测器名称。以 rule.md 的 `skill_id` 为准。**

> 🚫 **禁止**用 C/C++ 命名空间（`memory.*`、`exec.*`、`io.*`）记录其他语言的 finding。
> 每一门语言的 `skill_id` 由 rule.md 的 YAML frontmatter 决定。

---

#### C/C++（`$SCAN_LANG=cpp`）

| 规范 detector 名 | Skill ID | 分类 |
|-----------------|----------|------|
| `memory.buffer_overflow` | buffer_overflow | memory |
| `memory.null_dereference` | null_dereference | memory |
| `memory.memory_leak` | memory_leak | memory |
| `memory.double_free` | double_free | memory |
| `memory.use_after_free` | use_after_free | memory |
| `memory.integer_overflow` | integer_overflow | memory |
| `memory.ownership_transfer` | ownership_transfer | memory |
| `memory.must_check` | must_check | memory |
| `string.api_semantic_misuse` | api_semantic_misuse | string |
| `exec.command_injection` | command_injection | exec |
| `exec.input_validation` | input_validation | exec |
| `io.resource_leak` | resource_leak | io |
| `sync.lock_misuse` | lock_misuse | sync |
| `crypto.hardcoded_secrets` | hardcoded_secrets | crypto |
| `error.error_propagation` | error_propagation | error |

#### Python（`$SCAN_LANG=python`）

| 规范 detector 名 | Skill ID | 分类 |
|-----------------|----------|------|
| `python.code-injection.eval` | code_injection | exec |
| `python.command-injection.shell` | command_injection | exec |
| `python.debug-mode.django` | debug_mode | config |
| `python.deserialization.pickle` | deserialization | deserialization |
| `python.hardcoded-secrets.key` | hardcoded_secrets | string |
| `python.path-traversal.open` | path_traversal | io |
| `python.sql-injection.execute` | sql_injection | exec |
| `python.ssrf.requests` | ssrf | io |
| `python.ssti.jinja2` | ssti | io |
| `python.weak-crypto.md5` | weak_crypto | crypto |
| `python.xss.template` | xss | io |

#### Java（`$SCAN_LANG=java`）

| 规范 detector 名 | Skill ID | 分类 |
|-----------------|----------|------|
| `java.command-injection.exec` | command_injection | exec |
| `java.deserialization.insecure` | deserialization | deserialization |
| `java.log-injection.crlf` | log_injection | io |
| `java.path-traversal.sanitize` | path_traversal | io |
| `java.sql-injection.dynamic` | sql_injection | exec |
| `java.ssrf.open-redirect` | ssrf | io |
| `java.ssti-code-injection.dynamic` | ssti_code_injection | io |
| `java.toctou.race` | toctou | sync |
| `java.weak-crypto.algorithm` | weak_crypto | crypto |
| `java.xxe.insecure-xml` | xxe | io |
| `crypto.hardcoded-secrets` | hardcoded_secrets | crypto |

#### Go（`$SCAN_LANG=go`）

| 规范 detector 名 | Skill ID | 分类 |
|-----------------|----------|------|
| `go.injection.command` | command_injection | exec |
| `go.injection.sql` | sql_injection | exec |
| `go.injection.ssti` | ssti | io |
| `go.system.path-traversal` | path_traversal | io |
| `go.web.ssrf` | ssrf | io |
| `go.concurrency.safety` | concurrency_safety | sync |
| `go.memory.cgo` | cgo_memory | memory |
| `go.crypto.secrets` | hardcoded_secrets | crypto |
| `go.crypto.weak` | weak_crypto | crypto |
| `go.error.info-leak` | info_leak | io |

#### JavaScript/TypeScript（`$SCAN_LANG=js`）

| 规范 detector 名 | Skill ID | 分类 |
|-----------------|----------|------|
| `js.code_injection` | code_injection | exec |
| `js.command_injection` | command_injection | exec |
| `js.nosql_injection` | nosql_injection | exec |
| `js.path_traversal` | path_traversal | io |
| `js.ssrf` | ssrf | io |
| `js.ssti` | ssti | io |
| `js.hardcoded_secrets` | hardcoded_secrets | crypto |
| `js.weak_crypto` | weak_crypto | crypto |
| `js.prototype_pollution` | prototype_pollution | memory |
| `js.log_injection` | log_injection | io |
| `js.info_leak` | info_leak | io |
| `js.excessive_data_exposure` | excessive_data_exposure | io |
| `js.mass_assignment` | mass_assignment | io |

> ⚠️ **最常见错误 detector 名**（LLM 训练数据常混淆）→ **必须修正**：
> - 扫描 Python 时：~~`exec.command_injection`~~ → `python.command-injection.shell`
> - 扫描 Python 时：~~`crypto.hardcoded_secrets`~~ → `python.hardcoded-secrets.key`
> - 扫描 Python 时：~~`io.path_traversal`~~ → `python.path-traversal.open`
> - 扫描 Python 时：~~`web.xss`~~、~~`python.xss.reflected`~~ → `python.xss.template`
> - 扫描 Python 时：~~`web.ssrf`~~ → `python.ssrf.requests`
> - 扫描 Python 时：~~`web.sql_injection`~~ → `python.sql-injection.execute`
> - 扫描 Python 时：~~`exec.code_injection`~~ → `python.code-injection.eval`
> - 扫描 Python 时：~~`crypto.weak_crypto`~~、~~`python.crypto.weak-crypto`~~ → `python.weak-crypto.md5`

错误 detector 名会导致 Detection Spec 交叉校验失败、render-report 跳过 finding、score 计算错误。

---

## Phase 0: 关键警告（OpenCode / Claude Code 通用）

> **⚠️ 本模板中所有 `$SCAN_DIR`、`$SCAN_ID`、`$USER_PROJECT`、`$SECGUARDIAN_HOME` 引用都是 shell 变量。**
> **不要在文件系统路径中直接使用字面量 `$SCAN_DIR`！必须先在 bash 中执行 source 才能展开。**
>
> 正确: `mkdir -p "$SCAN_DIR/findings"`（在 bash 里执行，SCAN_DIR 已被 source）
> 错误: 直接在文件路径写 `$SCAN_DIR/findings`（AI 将创建字面目录）
>
> **输出路径规则:**
> - `.codeagent/` 目录放在**用户项目根目录**下（由 `<path>` 参数推断父目录）
> - session 文件（`session-*.md`）是 Claude Code 专有产物，OpenCode 中不需要创建
> - 所有扫描输出写入 `.codeagent/secguardian/secguard/scans/<scan-id>/` 下

## Phase 1: 索引与信号生成

> Dispatcher 直接执行的阶段。**每个 bash 调用互相独立，shell 变量不跨调用共享。**

<!-- @secguardian:ordering rule=scan_id FIRST -->
### Step 1: 初始化（仅一次 bash 调用，使用共享 init-scan.sh）

> **唯一一次预初始化 bash 调用**。通过 `scripts/init-scan.sh` 完成自动发现、健康检查、路径确认、建目录、状态持久化，替代旧版 ~40 行复制粘贴代码。
> **禁止**在 Step 1 前后插入任何独立的 bash 命令。

```bash
source "$HOME/.config/opencode/extensions/secguardian/scripts/init-scan.sh" secguard "<path>"
```

### 🔒 跨 Shell 状态传递规则

> **每个 bash 调用都是独立 shell，变量不共享。禁止用 `/tmp/` 或任何系统临时目录传状态。**
>
> ⚠️ `$SECGUARDIAN_HOME` **只在 source `.scan_state.secguard` 后的 bash shell 中可用**。不要在 source 之前直接引用 `$SECGUARDIAN_HOME`（值为空）。
>
> ⚠️ **禁止对 `$SCRIPTS_DIR/` 执行 `ls`、`find`、Glob 等探索操作。** 所有脚本路径已在模板中硬编码。探索多余目录填满上下文并触发不必要的权限弹窗。

Step 1 已在 `$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard`（绝对路径）中持久化所有状态。

**从 Step 2 开始，每个 bash 调用必须在开头执行以下命令**（这样 `$SCAN_DIR`、`$SCAN_ID`、`$USER_PROJECT`、`$SECGUARDIAN_HOME` 才能正确展开）:

> **知识库读取**: 知识库文件存储在 `$SECGUARDIAN_HOME/knowledge/`，使用 bash `cat` 按需读取，不拷贝到项目目录。
> - 规则文件（`rule.md`、`references/*.md`）：使用 bash `cat` 读取（不触发权限弹窗）
> - 协议文件（`knowledge/protocols/*.md`）：使用 bash `cat` 读取
> - 语言画像（`skills/secguard-{lang}/references/language-features.md`）：使用 bash `cat` 读取
> - ⚠️ **排除项：`$SCRIPTS_DIR/` 下的二进制文件**（`secguardian-index`）是编译产物，**禁止 `cat`**。只能通过 bash 执行（`"$INDEXER" --lang ...`）
> - 禁止使用 `read` 工具读 `$SECGUARDIAN_HOME/` 下的文本文件（触发 OpenCode 外部目录权限弹窗）。对于二进制文件（如 `secguardian-index`），既不 `read` 也不 `cat`，只能执行。

### Step 2: 构建语义索引（不可跳过）

> 索引器产出 `call_sites`（库函数调用点 + 参数摘要），作为 Phase 2 Worker 的任务信号清单。**不执行此步骤将导致 Worker 没有信号指引。**
> 索引自动复用同路径缓存。加 `--force` 强制重建。

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

INDEXER="$SCRIPTS_DIR/secguardian-index"
# 超时保护: timeout 30s
if command -v timeout &>/dev/null; then
    timeout 30 "$INDEXER" --lang "$SCAN_LANG" --path "$SCAN_PATH" --output "$USER_PROJECT/.codeagent/secguardian/index.json" || {
        echo "FAIL: Indexer timed out after 30s or failed — cannot continue"
        echo "  macOS: brew install coreutils  (provides 'timeout' command)"
        exit 1
    }
elif command -v gtimeout &>/dev/null; then
    gtimeout 30 "$INDEXER" --lang "$SCAN_LANG" --path "$SCAN_PATH" --output "$USER_PROJECT/.codeagent/secguardian/index.json" || {
        echo "FAIL: Indexer timed out after 30s or failed — cannot continue"
        exit 1
    }
else
    echo "WARNING: 'timeout' not found — indexer runs without timeout protection"
    "$INDEXER" --lang "$SCAN_LANG" --path "$SCAN_PATH" --output "$USER_PROJECT/.codeagent/secguardian/index.json"
fi
if [ ! -f "$USER_PROJECT/.codeagent/secguardian/index.json" ]; then
    echo "FATAL: Indexer failed — cannot continue"
    exit 1
fi
```

### Step 3: 验证索引完整性

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

 校验是强约束：finding 的 severity、CWE、evidence 必须匹配对应 SKILL.md 的 Detection Spec。跳过规则文件加载的 finding 将被拒绝。

### Step 9: 渲染最终输出

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

RENDERER="$SCRIPTS_DIR/render-report.py"

python3 "$RENDERER" \
    --command secguard \
    --scan-id "$SCAN_ID" \
    --findings-dir "$SCAN_DIR/findings/" \
    --path "$SCAN_PATH" \
    --language "$SCAN_LANG" \
    --index .codeagent/secguardian/index.json \
    --output "$SCAN_DIR/"
```

渲染器自动生成: `report.md` + `results.sarif` + `summary.json` + `manifest.json` + `status.json` + `human/executive-summary.md` + `dashboard.html` + `ai/remediation-pack.json` + `delta.json`。

> 如果渲染器不存在或执行失败，打印警告：`"Renderer unavailable — findings saved to findings/ directory tree only."`

### Step 10: 输出摘要（遵循统一 CLI 输出协议）

读取 `manifest.json` 获取扫描统计，按 `knowledge/protocols/scan-output.md §CLI 输出摘要` 的统一格式输出。

**secguard 特有规则：**
- **统计表**：按 Worker 展开（`信号数 | 检出 | 抑制 | 误报` 列），这是 secguard 独有的信号级明细
- **0 finding 附加注释**：在统计表下方说明未映射信号（如 "X 个 io close() 调用当前 Skill 范围未覆盖"）
- **类别列**：填充 detector ID（如 `memory.buffer_overflow`）

**0 finding 示例：**

```markdown
## secguard 扫描完成

Scan ID: sc-YYYYMMDD-HHMMSS-xxxx | Project: <project> | Path: <path> | Language: <lang> | Mode: <mode>

### 扫描统计

| 项目 | 数值 |
|------|------|
| 扫描文件 | 225 |
| 信号数 | 66 |
| 检出 | 0 |

**Worker 明细：** log_injection 39 信号已抑制，deserialization 14 已抑制，command_injection 1 已抑制。

*其中 12 个 io 信号（close() 调用）当前 Skill 范围未覆盖。*

### 安全评分

**100/100 🟢 Grade A — 无可报告发现。**
```

**有 finding 示例：**

```markdown
## secguard 扫描完成

Scan ID: sc-YYYYMMDD-HHMMSS-xxxx | Project: <project> | Path: <path> | Language: <lang> | Mode: <mode>

### 扫描统计

| 项目 | 数值 |
|------|------|
| 扫描文件 | 15 |
| 信号数 | 45 |
| 检出 | 7 (Critical: 1, High: 2, Medium: 4) |

**Worker 明细：** buffer_overflow 7 检出 / 12 抑制 / 26 误报，null_dereference 4 检出 / 4 抑制。

### 发现详情

| # | Severity | CWE | 类别 | 位置 | 摘要 |
|---|----------|-----|------|------|------|
| 1 | 🔴 Critical | CWE-120 | memory.buffer_overflow | src/parser.c:36 | sizeof(dst)=64, input未知 |
| 2 | 🟠 High | CWE-190 | memory.integer_overflow | src/network.c:46 | size calc overflow |
| 3 | 🟠 High | CWE-089 | web.sql_injection | src/webapp.c:59 | sprintf SQL from input |

### 安全评分

**55/100 🟡 Grade C — 存在需关注的风险。**
```

**输出文件：**
- `report.md`、`results.sarif`、`summary.json`、`status.json`、`dashboard.html`

---

## 输出文件命名规范

所有 finding 文件命名格式：`<SHA12>_<FILE_SLUG>-<LINE>.json`

| 组成部分 | 说明 | 唯一性 |
|---------|------|--------|
| `SHA12` | SHA-256(`detector:file:line:cwe`) 前 12 hex | 不同输入几乎零碰撞 |
| `FILE_SLUG` | 文件名去扩展名，无缩写 | 工程师快速定位 |
| `LINE` | 行号（纯数字，无前缀） | 同行同 detector 只产一个 finding |

**不会碰撞**: SHA-256 以 `detector:file:line:cwe` 为输入，碰撞概率 < 2^-48。对齐 SARIF partialFingerprints。

示例:
```
findings/memory/buffer_overflow/a1b2c3d4e5f6_parser-36.json
findings/exec/command_injection/f6e5d4c3b2a1_executor-89.json
```

---

## 附录 A: 检测器清单（输出规范 — 非调度用途）

> **注意：** 以下检测器清单仅用于 finding 输出格式规范。
> Dispatcher 不再按此清单分派 Worker。
> Investigation Pipeline 根据 Signal Type 自动决定调查方向。

| # | Skill | call_sites category | Source | 检测内容 |
|---|-------|---------------------|--------|---------|
| 1 | buffer_overflow | string + memory | 灵码 | strcpy/strcat/sprintf 及 `_s` 变体参数误用 |
| 2 | null_dereference | memory | 灵码 | malloc/calloc/realloc 后无 NULL 检查 |
| 3 | memory_leak | memory | 灵码 | malloc/calloc 无配对 free |
| 4 | double_free | memory | 灵码 | 同一指针多次 free |
| 5 | use_after_free | memory | 灵码 | free 后继续使用指针 |
| 6 | integer_overflow | memory | 灵码 | 整数运算溢出导致缓冲区大小错误 |
| 7 | resource_leak | io | 灵码 | fopen/socket/open 无配对 close |
| 8 | command_injection | exec | 灵码 | system/popen/exec 参数来自用户输入 |
| 9 | input_validation | exec | 灵码 | 外部输入未校验即使用 |
| 10 | hardcoded_secrets | crypto* | SecGuardian | 密钥/密码硬编码（非 call_site 驱动） |
| 11 | must_check | memory + io | 灵码 | 函数返回值必须检查但未检查 |
| 12 | ownership_transfer | memory | 灵码 | 所有权转移后原指针继续使用 |
| 13 | api_semantic_misuse | * | 灵码 | API 副作用与隐式语义误用 |
| 14 | lock_misuse | sync | 灵码 | 互斥锁 lock/unlock 不配对 |
| 15 | error_propagation | * | 灵码 | 错误码未传播或被吞没（非 call_site 驱动） |

*: hardcoded_secrets 映射到 crypto category 但实际使用模式匹配扫描。

---

## 附录 B: Investigation Pipeline 流程摘要

> **Phase 2a: Hypothesis Generator** — 每个 Signal Type 生成 3~5 假设
> **Phase 2b: Investigator** — 为每个假设收集 Source/Propagation/Sink Evidence
> **Phase 2c: Counter Evidence** — 尝试推翻自己的假设
> **Phase 2d: Judge** — 基于 Evidence + Counter Evidence 独立裁决

| 条目 | 规则 |
|------|------|
| 输入 | 信号清单 + SKILL.md + references/ + 源码根路径 |
| 执行步骤 | W1 信号确认 → W2 证据链构建 → W3 安全变体审计 → W4 跨函数补证 → W5 事实锚定反思 |
| 事实锚定反思 | 3 个域专用事实锚定问题 + 判定矩阵 |
| 输出 | finding（通过 record-finding.py）+ blindspot.json（每个 Worker） |
| 禁止 | 非终止状态（"需要更多上下文"、"无法确定"） |
| suppress | 不确定 → 抑制。仅完全证据链才报告 |
| 跨函数 depth | max 1，超过 → downgrade to suspicious |
| 分批策略 | BATCH_SIZE=50，信号超标时自动分批（§5.5） |
| Batch Worker 独立性 | 完全无状态，不依赖其他 Batch |
| 跨 Batch 归并 | Aggregator (§5.6) 在 Worker 完成后合并去重 |
| 信号上限 | BATCH_SIZE × MAX_BATCH_WORKERS(=100)，超额标记 unprocessed |

---

## 附录 C: OpenCode 内联执行须知

> OpenCode 没有后台任务工具。Phase 2 §5.1 定义的串行内联执行是本平台的唯一 Worker 模式，不是"降级方案"。

串行内联执行的已知限制：

1. **上下文预算截断**：如果扫描项目大、信号多，达到上下文预算后未处理的 Skill 将被标记为 `unprocessed`。这是安全机制，不是故障
2. **无上下文隔离**：所有 Worker 在 Dispatcher 主会话中运行，残留上下文可能影响下一个 Worker 的判断
3. **抑制倾向**：如果上下文已满，后续 Worker 的判定质量下降。Ambiguous 信号应该优先抑制而非确认

**避免截断的策略：**
- 信号 > 50 的 Skill 自动分批（§5.5），但不要在 Phase 2 一次加载所有规则文件
- 如果扫描包含大量字符串/IO 信号，**默认只运行 buffer_overflow、command_injection、memory 类高风险 Skill**，将 error_propagation、hardcoded_secrets 等低风险 Skill 延后或有选择地执行
- 如果上下文接近预算，优先运行信号量最少的 Skill（快速产出），跳过信号量大的 Skill（长时间占用上下文）
