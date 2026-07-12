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
> **隔离约束**: Dispatcher 只能加载 `$SECGUARDIAN_HOME/skills/secguard-<language>/` 下的 Skill，禁止加载 `skills/secaudit-secaudit/` 或 `skills/secreview-<language>/` 下的任何文件。知识文件使用 `Read` 工具按需读取（不通过 bash cat 回显，避免 token 浪费）。
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
| `memory.mismatched_free` | mismatched_free | memory |
| `memory.must_check` | must_check | memory |
| `string.api_semantic_misuse` | api_semantic_misuse | string |
| `exec.command_injection` | command_injection | exec |
| `exec.input_validation` | input_validation | exec |
| `io.resource_leak` | resource_leak | io |
| `sync.lock_misuse` | lock_misuse | sync |
| `cpp.crypto.hardcoded_secrets` | hardcoded_secrets | crypto |
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
| `java.crypto.hardcoded-secrets` | hardcoded_secrets | crypto |

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

## Phase 0: 关键警告（OpenCode 通用）

> **⚠️ 本模板中所有 `$SCAN_DIR`、`$SCAN_ID`、`$USER_PROJECT`、`$SECGUARDIAN_HOME` 引用都是 shell 变量。**
> **不要在文件系统路径中直接使用字面量 `$SCAN_DIR`！必须先在 bash 中执行 source 才能展开。**
>
> 正确: `mkdir -p "$SCAN_DIR/findings"`（在 bash 里执行，SCAN_DIR 已被 source）
> 错误: 直接在文件路径写 `$SCAN_DIR/findings`（AI 将创建字面目录）
>
> **输出路径规则:**
> - `.codeagent/` 目录放在**用户项目根目录**下（由 `<path>` 参数推断父目录）
> - 所有扫描输出写入 `.codeagent/secguardian/secguard/scans/<scan-id>/` 下

## Phase 1: 索引与信号生成

> Dispatcher 直接执行的阶段。**每个 bash 调用互相独立，shell 变量不跨调用共享。**

<!-- @secguardian:ordering rule=scan_id FIRST -->
### Step 1: 初始化（仅一次 bash 调用，使用共享 init-scan.sh）

> **唯一一次预初始化 bash 调用**。通过 `scripts/init-scan.sh` 完成自动发现、健康检查、路径确认、建目录、状态持久化，替代旧版 ~40 行复制粘贴代码。
> **禁止**在 Step 1 前后插入任何独立的 bash 命令。

```bash
source "$HOME/.config/opencode/extensions/secguardian/scripts/init-scan.sh" secguard "<path>" "<language>"
```

### 🔒 跨 Shell 状态传递规则

> **每个 bash 调用都是独立 shell，变量不共享。禁止用 `/tmp/` 或任何系统临时目录传状态。**
>
> ⚠️ `$SECGUARDIAN_HOME` **只在 source `.scan_state.secguard` 后的 bash shell 中可用**。不要在 source 之前直接引用 `$SECGUARDIAN_HOME`（值为空）。
>
> ⚠️ **禁止对 `$SCRIPTS_DIR/` 执行 `ls`、`find`、Glob 等探索操作。** 所有脚本路径已在模板中硬编码。探索多余目录填满上下文并触发不必要的权限弹窗。

Step 1 已在 `$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard`（绝对路径）中持久化所有状态。

**从 Step 2 开始，每个 bash 调用必须在开头执行以下命令**（这样 `$SCAN_DIR`、`$SCAN_ID`、`$USER_PROJECT`、`$SECGUARDIAN_HOME` 才能正确展开）:

> **知识库读取规则**:
> - 规则文件（`rule.md`、`references/*.md`）：使用 `Read` 工具读取（内容直接进入 LLM 上下文，无 shell 回显 token 开销）
> - 协议文件：使用 `Read` 工具读取技能目录下的 `protocols/` symlink（如 `$SECGUARDIAN_HOME/skills/secguard-cpp/protocols/verification-protocol.md`），不直接读 `knowledge/`
> - 标准文件：使用 `Read` 工具读取技能目录下的 `standards/` symlink
> - 语言画像（`skills/secguard-{lang}/references/language-features.md`）：使用 `Read` 工具读取
> - 用户项目下的扫描输入文件（`index.json`、`expected-results.json` 等）：使用 `Read` 工具读取
> - ⚠️ **排除项：`$SCRIPTS_DIR/` 下的二进制文件**（`secguardian-index`）是编译产物，**禁止 Read/cat**。只能通过 bash 执行（`"$INDEXER" --lang ...`）
> - 🚫 **禁止通过 bash 读取文本文件**（bash cat/head/tail 回显内容到对话浪费 token）。所有文本文件使用 `Read` 工具。
> - 🚫 **禁止用 `read` 工具读取 `$SCRIPTS_DIR/` 下的脚本文件**（不读取脚本源码，只执行）

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

<!-- @secguardian:non-skippable step=validate -->
### Step 3: 验证索引完整性

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"
python3 "$SCRIPTS_DIR/validate-index.py" "$USER_PROJECT/.codeagent/secguardian/index.json" || { echo "FATAL: index invalid"; exit 1; }
```

<!-- @secguardian:non-skippable step=pre-filter -->
### Step 3.6: 生成 compact schedule 和 Task prompts [NON-SKIPPABLE]

> **这是 Phase 2 的入口。禁止跳过——所有 nonempty batch 的 Task prompt 由脚本生成，确保格式一致。**

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

# 1. 生成 compact schedule（仅 batch 摘要，不含 signal 详情）
echo "=== COMPACT SCHEDULE ==="
python3 "$SCRIPTS_DIR/compact-schedule.py" --plan "$SCAN_DIR/partition-plan.json"

# 2. 生成所有 Task prompts（机器可消费 JSON）
python3 "$SCRIPTS_DIR/gen-task-prompts.py" \
    --plan "$SCAN_DIR/partition-plan.json" \
    --project "$USER_PROJECT" \
    --scan-dir "$SCAN_DIR" \
    --index-json "$USER_PROJECT/.codeagent/secguardian/index.json" \
    --json > "$SCAN_DIR/task-prompts.json"
```

> **禁止**用 `Read` 读取 `partition-plan.json`（用 compact-schedule.py 代替）。
> **禁止**手写 Task prompt（用 gen-task-prompts.py 预生成）。
> **禁止**用 `Read` 读取 `$SCRIPTS_DIR/` 下的脚本文件。

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"
# 引擎产出平台无关 partition 计划
python3 "$SCRIPTS_DIR/partition-signals.py" \
    --index "$USER_PROJECT/.codeagent/secguardian/index.json" \
    --rules-dir "$RULES_DIR" \
    --batch-size 20 \
    --json > "$SCAN_DIR/partition-plan.json"
```

---

## Phase 2: per-batch Task dispatch [NON-SKIPPABLE] [NON-NEGOTIABLE]

<!-- @secguardian:non-skippable step=rule-loading -->
**以下 bash 块是 Phase 2 的唯一入口。禁止跳过，禁止替换为内联 python3 -c。**

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

# 1. compact schedule（LLM 只读 stdout，不读 plan 文件）
python3 "$SCRIPTS_DIR/compact-schedule.py" --plan "$SCAN_DIR/partition-plan.json"

# 2. 预生成标准化 Task prompts
python3 "$SCRIPTS_DIR/gen-task-prompts.py" \
    --plan "$SCAN_DIR/partition-plan.json" \
    --project "$USER_PROJECT" \
    --scan-dir "$SCAN_DIR" \
    --index-json "$USER_PROJECT/.codeagent/secguardian/index.json" \
    --json > "$SCAN_DIR/task-prompts.json"
```

**此 bash 块执行完毕后，LLM 的行为约束：**

| 步骤 | 操作 | 工具 |
|------|------|------|
| A | 读 `task-prompts.json`，选 signal 最少的 batch 作 pilot | `Read`（仅读该文件） |
| B | 对 pilot batch，取其 `prompt` 字段**原文**，启动 `Task` 子代理 | `Task`，`subagent_type=general` |
| C | 等待 pilot 完成，检查工件存在（`hypotheses.json`等） | `Bash` |
| D | 对剩余 batch，逐个取其 `prompt` 字段原文，启动独立 `Task` | `Task` |

**禁止清单**：
- 禁止合并多个 batch 到一个 Task（`complete remaining` 等）
- 禁止父 dispatcher 读取 rule.md、源码、judge_verdict.json
- 禁止手写 Task prompt（全部来自 `task-prompts.json`）
- 禁止 todowrite、禁止探索目录、禁止 Read 二进制文件
- 临时文件写入 `$SCAN_DIR/.tmp/`（已由 gen-task-prompts.py 创建）

**每个 Task 子代理的标准 prompt 已由 gen-task-prompts.py 预生成，包含完整的 canonical JSON Schema（judge_verdict、blindspot、record-finding 格式）。**

**Task prompt 最小模板（每个 batch 单独生成，禁止复用为多 batch prompt）。必须包含完整的 JSON Schema，确保 20 个独立 Task 产出的 artifact 格式 100% 一致。**

```text
Execute ONLY this SecGuardian isolated batch.
SCAN_ID: <scan-id>
PROJECT: <user-project>
RULE_ID: <rule_id>
BATCH_ID: <batch_id>
RULE_PATH: <rule_path>
SIGNALS: [list of {signal_id, file, line, callee, category, arguments}]

Load state from .codeagent/secguardian/.scan_state.secguard.
Read only RULE_PATH and source windows for signals in this exact batch using Read(file, offset=line-N, limit=2N).

===== CANONICAL ARTIFACT FORMATS (MUST MATCH EXACTLY) =====

1. judge_verdict.json — THE GATE CONSUMES THIS. Format errors → needs_review.
{
  "rule_id": "<rule_id>",
  "batch_id": "<batch_id>",
  "verdicts": [
    {
      "signal_id": "<from partition plan>",
      "file": "<source file>",
      "line": <line number>,
      "verdict": "CONFIRMED",
      "severity": "Critical",
      "cwe": "CWE-120",
      "judgment_matrix": {
        "Q1_<descriptor_from_rule_md>": true,
        "Q2_<descriptor_from_rule_md>": true,
        "Q3_<descriptor_from_rule_md>": false,
        "conclusion": "CONFIRMED"
      }
    },
    {
      "signal_id": "<signal_id>",
      "file": "<file>",
      "line": <line>,
      "verdict": "SUPPRESS",
      "judgment_matrix": {
        "Q1_<descriptor>": false,
        "Q2_<descriptor>": false,
        "Q3_<descriptor>": true,
        "conclusion": "SUPPRESS"
      }
    }
  ],
  "summary": {"confirmed": N, "suppressed": M}
}
CRITICAL RULES:
- Every verdict entry MUST have signal_id, file, line, verdict.
- verdict MUST be EXACTLY "CONFIRMED" or "SUPPRESS". No other values.
- judgment_matrix field names MUST start with Q1_/Q2_/Q3_ prefix + underscore + descriptor from rule.md Detection Spec.
- summary.confirmed and summary.suppressed MUST be integers matching the count of each verdict type.
- No extra top-level fields (no generated_at, scan_id, judge_timestamp, etc.).

2. record-finding.py --from-file input (for each CONFIRMED verdict):
{
  "detector": "<canonical detector name from rule.md skill_id>",
  "severity": "Critical",
  "cwe": "CWE-120",
  "title": "<one-line description>",
  "file": "<path relative to project root, e.g. src/parser.c>",
  "line": <line number>,
  "function": "<function name from index.json symbols>",
  "snippet": "<the vulnerable code line>",
  "rule_id": "<rule_id>",
  "batch_id": "<batch_id>",
  "signal_id": "<exact signal_id from partition plan>",
  "index_json": "<PROJECT>/.codeagent/secguardian/index.json",
  "scan_dir": "<PROJECT>/.codeagent/secguardian/secguard/scans/<scan-id>"
}
CRITICAL: signal_id MUST be a real signal_id from the partition plan signals list.
CRITICAL: function MUST match a function name in index.json symbols.functions.

3. blindspot.json — record ALL signals not confirmed, with reason:
{"rule_id": "<rule_id>", "batch_id": "<batch_id>", "suppressed": [
  {"signal_id": "<id>", "reason": "<why suppressed>"}
]}

Do not process any other rule or batch. Do not edit source code.
Return: {rule_id, batch_id, confirmed: N, suppressed: M, artifacts: [list of files created]}
```

> **规则完整性保证**: per-rule 纪律由引擎强制（coverage-gate 逐 assignment 核销）+ 上下文隔离（LLM 无法因上下文压力丢弃未处理的规则）。漏跑 rule → 该 rule 信号未 investigated → coverage-gate BLOCKED。

---
### Investigation Pipeline（由 Task 子代理执行，不在主上下文展开）

完整 Steps 4-8、P2 Counter Evidence、Q-matrix 极性和 record-finding provenance 要求只以 `knowledge/protocols/dispatch-protocol.md §3` 为准。OpenCode command 是平台适配层，不复制 pipeline 细节，避免主 dispatcher 因看到完整流程而内联执行调查。

主 dispatcher 只验证 Task 子代理产出的 canonical 工件是否存在：`hypotheses.json`、`evidence.json`、`counter_evidence.json`、`judge_verdict.json`、`blindspot.json`。缺任一工件时，该 batch 视为未完成，后续 `coverage-gate.py` 必须 BLOCKED。

---

### Step 7: 引擎强制（验证 + 覆盖门禁）[所有 batch 完成后执行]

> **依据**: `knowledge/protocols/dispatch-protocol.md §4`。per-rule 纪律由引擎强制，不靠 LLM 自觉。

```bash
# verification-gate: anchor/severity/Q-matrix 校验 → gate-audit.json（confirmed 才计入 CI）
python3 "$SCRIPTS_DIR/verification-gate.py" \
    --index "$USER_PROJECT/.codeagent/secguardian/index.json" \
    --scan-dir "$SCAN_DIR/"
# coverage-gate: 逐 (rule_id, signal_id) assignment 核销（BLOCKED → exit 1）
python3 "$SCRIPTS_DIR/coverage-gate.py" \
    --plan "$SCAN_DIR/partition-plan.json" \
    --scan-dir "$SCAN_DIR/"
```

gate 非零退出时立即 BLOCKED，禁止进入渲染。`gate-audit.json` 中 `needs_review > 0` 视为未通过，不执行 Step 8。

---

### Step 8: 渲染最终输出

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
    --index "$USER_PROJECT/.codeagent/secguardian/index.json" \
    --output "$SCAN_DIR/" \
    --ci
```

渲染器自动生成: `report.md` + `results.sarif` + `summary.json` + `manifest.json` + `status.json` + `human/executive-summary.md` + `dashboard.html` + `ai/remediation-pack.json` + `delta.json`。

> 如果渲染器不存在或执行失败，打印警告：`"Renderer unavailable — findings saved to findings/ directory tree only."`

### Step 9: 输出摘要（遵循统一 CLI 输出协议）

读取 `manifest.json` 获取扫描统计。**第一步**：从 `.scan_state.secguard` 提取项目信息——`SCAN_PATH` 是被扫描的源码目录，`USER_PROJECT` 是项目根目录。**禁止输出占位符** `<path>`/`<project>`——必须填入实际值。

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"
echo "SCAN_PATH=$SCAN_PATH"
echo "USER_PROJECT=$USER_PROJECT"
```

**secguard 特有规则：**
- **首行必含**：`Scan ID | Project: <项目目录名> | Path: <扫描路径> | Language: <语言>`
- **Project** = `$USER_PROJECT` 的最后一级目录名（如 `cpp-vuln-demo-no-answers`）
- **Path** = `$SCAN_PATH` 相对于 `$USER_PROJECT` 的路径（如 `src`）
- **统计表**：按 Worker 展开（`信号数 | 检出 | 抑制 | 误报` 列），这是 secguard 独有的信号级明细
- **0 finding 附加注释**：在统计表下方说明未映射信号（如 "X 个 io close() 调用当前 Skill 范围未覆盖"）

**0 finding 示例：**

```markdown
## secguard 扫描完成

Scan ID: sc-20260711-212108-63ac | Project: cpp-vuln-demo-no-answers | Path: src | Language: cpp

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

Scan ID: sc-20260711-212108-63ac | Project: cpp-vuln-demo-no-answers | Path: src | Language: cpp

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

### Phase 3: 管道工件验证与聚合 [不可跳过，在最终输出之前]

> ⚠️ **必须验证所有 (rule, batch) 的 blindspot.json 存在后才能输出最终摘要。**
> 这是管道完整性的最后检查点。

**Step 1: 验证 blindspot.json 完整性**

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

# workers/ 下现在是 <rule_id>/<batch_id>/ 结构
MISSING=0
for batch_dir in $(find "$SCAN_DIR/workers" -type d -name "batch-*" 2>/dev/null); do
  if [ ! -f "$batch_dir/blindspot.json" ]; then
    echo "ERROR: Missing blindspot.json in $batch_dir"
    MISSING=$((MISSING + 1))
  fi
done
if [ "$MISSING" -gt 0 ]; then
  echo "FATAL: $MISSING batch(es) missing blindspot.json — Investigation Pipeline incomplete"
  exit 1
fi
echo "✓ All batches have blindspot.json"
```

**Phase 3 入口（在 Step 7 引擎强制后执行，禁止用内联 python3 -c）**

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

# 1. verdict 汇总
python3 "$SCRIPTS_DIR/scan-verdicts.py" --scan-dir "$SCAN_DIR/"

# 2. findings 查询
python3 "$SCRIPTS_DIR/show-findings.py" --scan-dir "$SCAN_DIR/" --summary
```

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
| 12 | mismatched_free | memory | 灵码 | 分配/释放不配对（malloc↔delete、new↔free 等）|
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
| 优先级策略 | 按严重度排序执行：Critical → High → Medium。信号 > 200 时优先高风险 Skill |
| 同一调用点去重 | 多个 Skill 对同一调用点产出 finding → 保留最高严重度（Phase 3 SHA-256 键控去重） |
| 信号超量处理 | 信号超量时标记 `unprocessed`，记录到 blindspot.json。这是安全机制，不是故障 |

---

## 附录 C: OpenCode 平台上下文隔离执行须知

> **CHANGE-004 (2026-07-11)**: 纯串行内联模式被测试证伪——LLM 在共享上下文中处理 3 条 rule 后自行丢弃剩余 12 条。本附录描述 OpenCode 无 Agent 子代理的原语下的**上下文隔离模拟**策略。

串行上下文隔离执行的要求：

1. **每个 batch 独享上下文**: 每个 (rule_id, batch_id) 处理前必须显式重置上下文——禁止携带前一个 batch 的完整源文件或 rule.md 内容进入下一个 batch。
2. **信号坐标只读片段**: 每个 signal 只通过 `Read(file, offset=line-N, limit=2N)` 读源码窗口（N=15），**禁止不带 offset/limit 的完整源文件 Read**。
3. **rule.md 按需加载**: 每个 batch 开始前读当前 rule.md，处理完后从上下文丢弃。
4. **无上下文累积**: 处理完一个 batch 后只保留 findings 摘要。新 batch 开始时上下文仅含 `rule_id`、`batch_id`、信号列表。

**避免上下文压力的策略：**
- 信号 > 50 的 rule 按 batch 逐个处理，每个 batch 最多 20 信号
- 每个 batch 只读一个 rule.md + 该 batch 的源码片段（< 200 行总量）
- 处理完一个 batch 时主动输出摘要，帮助从上下文缓存中清除旧上下文
- 如果上下文仍达到极限，剩余未处理 batch 交由 coverage-gate 标记为 `unprocessed`，下次扫描继续
