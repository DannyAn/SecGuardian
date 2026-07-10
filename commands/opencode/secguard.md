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

### Step 3: 验证索引完整性

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"
python3 "$SCRIPTS_DIR/validate-index.py" "$USER_PROJECT/.codeagent/secguardian/index.json" || { echo "FATAL: index invalid"; exit 1; }
# 引擎产出平台无关 partition 计划：{rule: [batch1, batch2, ...]}（per-rule 隔离，ADR-006）
python3 "$SCRIPTS_DIR/partition-signals.py" \
    --index "$USER_PROJECT/.codeagent/secguardian/index.json" \
    --rules-dir "$SKILL_DIR/secguard/$SCAN_LANG/rules" \
    --batch-size 20 \
    --json > "$SCAN_DIR/partition-plan.json"
```

> **依据**: `knowledge/protocols/dispatch-protocol.md`（单一真理源）。校验是强约束：finding 的 severity、CWE、evidence 必须匹配 rule.md 的 Detection Spec。跳过规则文件加载的 finding 将被拒绝。OpenCode 平台调度原语见该协议 §5（串行内联，无后台任务）。

---

## Phase 2: Investigation Pipeline（Steps 4-8）

> ⚠️ **本 Phase 是 Investigation Engine 核心，每一步不可跳过。**
> 每个 Step 产出指定工件到 `$SCAN_DIR/workers/<rule_name>/`。
> 下一步骤必须检查上一步骤的工件存在后才能继续。
> 🚫 **禁止**：跳过任何 Step、不产出工件直接记录 finding、不使用 index.json 结构化数据。

### Step 4: Phase 2a — Hypothesis Generator [不可跳过]

> **[MANDATORY ARTIFACT]** 产出: `workers/<rule_name>/hypotheses.json`
> **[GATE CHECK]** Step 3 索引完整性已验证 → 继续
> **[INPUT]** 该 rule 触发的信号清单 + index.json call_sites + 源码上下文
>
> **禁止直接判定漏洞类型。** Dispatcher 的唯一输出是 Signal+上下文。Hypothesis Generator 从 Signal 生成 3~5 个调查假设。

**执行流程：**

1. 使用 `Read` 工具读取规则文件（rule.md）获取领域知识
2. 从 index.json 提取该规则的信号清单（call_sites + string_literals + alloc_free/lock_graph 补充）
3. 对每个信号类型，生成 3~5 个假设（H1=最可能漏洞 / H2=特定上下文漏洞 / H3=缓解存在 / H4=替代漏洞类型 / H5=实际安全）
4. 使用 bash 写 `workers/<rule_name>/hypotheses.json`

**hypotheses.json 格式：**
```json
{
  "rule": "buffer_overflow",
  "signal_type": "string_copy",
  "signal_count": 25,
  "hypotheses": [
    {"id": "H1", "direction": "缓冲区溢出 — strcpy 无长度限制", "initial_confidence": "high"},
    {"id": "H2", "direction": "截断导致逻辑错误 — snprintf 返回值未检查", "initial_confidence": "medium"},
    {"id": "H3", "direction": "已有 sizeof 边界保护", "initial_confidence": "low"},
    {"id": "H4", "direction": "整数溢出导致长度计算错误", "initial_confidence": "low"},
    {"id": "H5", "direction": "实际安全 — 使用安全变体或编译期已知大小", "initial_confidence": "low"}
  ]
}
```

### Step 5: Phase 2b — Investigator [不可跳过]

> **[MANDATORY ARTIFACT]** 产出: `workers/<rule_name>/evidence.json`
> **[GATE CHECK]** hypotheses.json 存在且包含 >=3 个假设 → 继续
> **[GATE CHECK]** 通过 `Read` 工具加载 rule.md + index.json 信号上下文
>
> **Investigator 针对每个假设自主收集证据，不按固定规则执行。**

**执行流程：**

1. 验证 hypotheses.json 存在且假设数量 >=3（bash: `python3 -c "import json; d=json.load(open('...')); assert len(d['hypotheses'])>=3"`）
2. 对每个假设，从 index.json 提取对应信号、阅读源码上下文，构建三段式证据链：
   - **Source**: 数据/操作起源于哪里？（锚定 file:line + function + variable）
   - **Propagation**: 数据如何流经系统？（锚定数据流路径上的每个节点）
   - **Sink**: 危害发生在哪里？（锚定最终危险操作点）
3. 每个证据项必须包含：`file`、`line`、`function`、`variable`、`description`
4. 使用 bash 写 `workers/<rule_name>/evidence.json`

**evidence.json 格式：**
```json
{
  "rule": "buffer_overflow",
  "hypotheses_evidence": [
    {
      "hypothesis_id": "H1",
      "evidence_chain": {
        "source": {"description": "argv[1] 从 main 传入 parse_task_name", "file": "src/parser.c", "line": 60, "function": "main", "variable": "argv[1]"},
        "propagate": {"description": "input 参数直接传给 strcpy，无长度检查", "file": "src/parser.c", "line": 20, "function": "parse_task_name", "variable": "input"},
        "sink": {"description": "strcpy 写入 task->name (char[64])，无边界保护", "file": "src/parser.c", "line": 20, "function": "parse_task_name", "variable": "task->name"}
      },
      "evidence_strength": "strong"
    }
  ]
}
```

### Step 6: Phase 2c — Counter Evidence (P2) [强制性阻塞门]

> **[MANDATORY ARTIFACT]** 产出: `workers/<rule_name>/counter_evidence.json`
> **[GATE CHECK]** evidence.json 存在 → 继续
> **[PROTOCOL]** 使用 `Read` 工具加载 `$SECGUARDIAN_HOME/skills/secguard-${SCAN_LANG}/protocols/verification-protocol.md`（通过 symlink → knowledge/protocols/），严格应用 P2 反证搜寻清单
> **[PROTOCOL]** 使用 `Read` 工具加载 rule 的 `references/false-positive.md`，应用抑制决策树
>
> ⚠️ **这是阻塞门。** counter_evidence.json 不存在或 P2 未通过 → **禁止**进入 Step 7。
> P2 的角色是"辩护律师"——主动搜索代码中证明漏洞**不成立**的证据。

**执行流程：**

1. bash 验证 evidence.json 存在
2. 使用 `Read` 工具加载 verification-protocol.md 的 P2 部分 + false-positive.md
3. 对 evidence.json 中的每个假设，按 CWE 类型搜索反证：
   - **内存安全 (CWE-120/476/415/416/787/190)**: RAII 包装器、智能指针、sizeof 边界检查、安全变体 (strcpy_s/snprintf/strlcpy)、FORTIFY_SOURCE/-fstack-protector
   - **注入 (CWE-78/89)**: 参数化 API、白名单验证、输入清理
   - **并发 (CWE-667)**: RAII lock_guard、原子操作
   - **加密 (CWE-327/798)**: 高层加密库 (libsodium)、KMS、环境变量密钥
4. 每个反证必须包含具体的代码位置+机制说明
5. P2 通行裁决: `counter_evidence_found` | `counter_evidence_not_found`
6. 使用 bash 写 `workers/<rule_name>/counter_evidence.json`

**counter_evidence.json 格式：**
```json
{
  "rule": "buffer_overflow",
  "p2_checks": [
    {
      "hypothesis_id": "H1",
      "p2_verdict": "counter_evidence_not_found",
      "search_results": {
        "raii_wrapper": false,
        "smart_pointer": false,
        "bounds_check_before_sink": false,
        "safe_alternative_used": false,
        "compiler_protection": false
      },
      "counter_mechanism": null
    },
    {
      "hypothesis_id": "H3",
      "p2_verdict": "counter_evidence_found",
      "search_results": {
        "raii_wrapper": false,
        "smart_pointer": false,
        "bounds_check_before_sink": true,
        "safe_alternative_used": true,
        "compiler_protection": false
      },
      "counter_mechanism": {
        "type": "safe_alternative",
        "description": "strcpy_s(dst, sizeof(dst), src) — Annex K 安全变体",
        "location": {"file": "src/p0_safe_functions.c", "line": 18}
      }
    }
  ]
}
```

> ⛔ **[BLOCKING GATE]** counter_evidence.json 必须存在且每个假设都有 p2_verdict 才能进入 Step 7。

### Step 7: Phase 2d — Judge + Fact-Anchor Reflection [不可跳过]

> **[MANDATORY ARTIFACT]** 产出: `workers/<rule_name>/judge_verdict.json`
> **[GATE CHECK]** evidence.json + counter_evidence.json 都存在 → 继续
> **[PROTOCOL]** 应用 rule.md 中的 Q1-Q2-Q3 判定矩阵
>
> **Judge 独立裁决。** 基于 Evidence + Counter Evidence，不重新扫描源码。

**执行流程：**

1. bash 验证 evidence.json + counter_evidence.json 都存在
2. 从 rule.md 读取该规则的 Q1-Q2-Q3 问题（事实锚定反射）
3. 对每个假设，回答 Q1-Q2-Q3 三个事实问题：
   - **三绿灯**（Q1=Yes, Q2=Yes, Q3=Yes 且全安全）→ `SUPPRESS`
   - **两绿灯+单黄灯**（大概率安全）→ `downgrade to informational`
   - **两红灯+单绿灯**（大概率确认）→ `CONFIRMED`
   - **三红灯**（全否定）→ `CONFIRMED`
   - **混合模式**（Yes/No 不一致）→ 强制详细分析
4. 裁决: `CONFIRMED` / `SUSPICIOUS` / `SAFE` / `UNKNOWN`
5. Unknown 永远不降级为 Safe。不确定 → 抑制。
6. 使用 bash 写 `workers/<rule_name>/judge_verdict.json`

**judge_verdict.json 格式：**
```json
{
  "rule": "buffer_overflow",
  "verdicts": [
    {
      "hypothesis_id": "H1",
      "verdict": "CONFIRMED",
      "judgment_matrix": {
        "Q1_buffer_too_small": true,
        "Q2_external_input": true,
        "Q3_bounds_check_exists": false,
        "conclusion": "CONFIRMED"
      },
      "severity": "Critical",
      "cwe": "CWE-120",
      "confidence": "high"
    },
    {
      "hypothesis_id": "H3",
      "verdict": "SAFE",
      "judgment_matrix": {
        "Q1_buffer_too_small": false,
        "Q2_external_input": false,
        "Q3_bounds_check_exists": true,
        "conclusion": "SUPPRESS"
      },
      "severity": null,
      "cwe": null,
      "confidence": "high"
    }
  ],
  "summary": {
    "confirmed": 1,
    "suspicious": 0,
    "safe": 1,
    "unknown": 0
  }
}
```

### Step 8: 记录 Findings [条件执行]

> **[CONDITIONAL]** 仅当 judge_verdict.json 包含 CONFIRMED 或 SUSPICIOUS 时运行
> **[GATE CHECK]** judge_verdict.json 存在 → 继续
> **[TOOL]** 使用 `$SCRIPTS_DIR/record-finding.py` 持久化
>
> **SAFE/UNKNOWN 裁决不产生 finding。** 仅 CONFIRMED 和 SUSPICIOUS 推进到 record-finding.py。

**执行流程：**

1. bash 验证 judge_verdict.json 存在
2. 提取所有 CONFIRMED 和 SUSPICIOUS 裁决
3. 对每个确认/可疑发现，构造 finding JSON → 通过 `record-finding.py --from-file` 记录
4. 为该 rule 生成 blindspot.json：
   - 记录哪些信号被抑制及原因
   - 记录哪些检测模式未覆盖（跨函数 depth>1 等）
   - 记录统计：信号数 / 调查数 / 确认 / 抑制
5. 使用 bash 写 `workers/<rule_name>/blindspot.json`

**blindspot.json 格式：**
```json
{
  "rule": "buffer_overflow",
  "status": "triggered",
  "signals_count": 25,
  "hypotheses_generated": 5,
  "findings_confirmed": 3,
  "findings_suppressed": 22,
  "blind_spot_reason": "22 个信号使用安全变体 (strcpy_s/snprintf+sizeof) 或目标缓冲区远大于源数据",
  "missed_patterns": ["跨函数溢出 (depth > 1)", "C++ 智能指针管理的内存操作"],
  "recommendations": ["手动审查跨函数边界的 memcpy 调用"]
}
```

---

### Step 8.5: 引擎强制（验证 + 覆盖门禁）

> **依据**: `knowledge/protocols/dispatch-protocol.md §4`。per-rule 纪律由引擎强制，不靠 LLM 自觉。

```bash
# verification-gate: anchor/severity 校验 → gate-audit.json（confirmed 才计入 CI）
python3 "$SCRIPTS_DIR/verification-gate.py" \
    --index "$USER_PROJECT/.codeagent/secguardian/index.json" \
    --scan-dir "$SCAN_DIR/"
# coverage-gate: batch-suppression 拦截（signals>0 且 0 investigated → BLOCKED exit 1）
python3 "$SCRIPTS_DIR/coverage-gate.py" \
    --index "$USER_PROJECT/.codeagent/secguardian/index.json" \
    --scan-dir "$SCAN_DIR/" || echo "WARN: coverage gate BLOCKED — signals suppressed without dismissed reasons"
```

---

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

### Phase 3: 管道工件验证与聚合 [不可跳过，在最终输出之前]

> ⚠️ **必须验证所有 Worker 的 blindspot.json 存在后才能输出最终摘要。**
> 这是管道完整性的最后检查点。

**Step 1: 验证 blindspot.json 完整性**

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

# 验证所有触发的规则都有 blindspot.json
MISSING=0
for rule_dir in $(ls -d "$SCAN_DIR/workers/"*/ 2>/dev/null); do
  rule_name=$(basename "$rule_dir")
  if [ ! -f "$rule_dir/blindspot.json" ]; then
    echo "ERROR: Missing blindspot.json in workers/$rule_name/"
    MISSING=$((MISSING + 1))
  fi
done
if [ "$MISSING" -gt 0 ]; then
  echo "FATAL: $MISSING rule(s) missing blindspot.json — Investigation Pipeline incomplete"
  exit 1
fi
echo "✓ All worker rules have blindspot.json"
```

**Step 2: 生成 worker_manifest.json**

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

python3 -c "
import json, glob, os
rules = glob.glob('$SCAN_DIR/workers/*/')
manifest = {'scan_id': '$SCAN_ID', 'rules': []}
for r in sorted(rules):
    name = os.path.basename(r.rstrip('/'))
    evidence = os.path.join(r, 'evidence.json')
    blindspot = os.path.join(r, 'blindspot.json')
    judge = os.path.join(r, 'judge_verdict.json')
    counter = os.path.join(r, 'counter_evidence.json')
    manifest['rules'].append({
        'rule': name,
        'has_evidence': os.path.exists(evidence),
        'has_counter_evidence': os.path.exists(counter),
        'has_judge_verdict': os.path.exists(judge),
        'has_blindspot': os.path.exists(blindspot)
    })
with open('$SCAN_DIR/worker_manifest.json', 'w') as f:
    json.dump(manifest, f, indent=2)
print(f'worker_manifest.json written ({len(manifest[\"rules\"])} rules)')
"
```

**Step 3: 管道完整性自检摘要**

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

python3 -c "
import json, glob, os
rules = glob.glob('$SCAN_DIR/workers/*/')
total_confirmed = 0
total_suppressed = 0
pipeline_complete = 0
for r in sorted(rules):
    name = os.path.basename(r.rstrip('/'))
    verdict_file = os.path.join(r, 'judge_verdict.json')
    blindspot_file = os.path.join(r, 'blindspot.json')
    has_verdict = os.path.exists(verdict_file)
    has_blindspot = os.path.exists(blindspot_file)
    if has_verdict and has_blindspot:
        pipeline_complete += 1
        with open(verdict_file) as f:
            v = json.load(f)
        s = v.get('summary', {})
        total_confirmed += s.get('confirmed', 0) + s.get('suspicious', 0)
        total_suppressed += s.get('safe', 0) + s.get('unknown', 0)
print(f'Pipeline Status: {pipeline_complete}/{len(rules)} rules complete')
print(f'Total Confirmed/Suspicious: {total_confirmed}')
print(f'Total Suppressed (Safe/Unknown): {total_suppressed}')
"
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
| 优先级策略 | 按严重度排序执行：Critical → High → Medium。信号 > 200 时优先高风险 Skill |
| 同一调用点去重 | 多个 Skill 对同一调用点产出 finding → 保留最高严重度（Phase 3 SHA-256 键控去重） |
| 信号超量处理 | 信号超量时标记 `unprocessed`，记录到 blindspot.json。这是安全机制，不是故障 |

---

## 附录 C: OpenCode 内联执行须知

> OpenCode 没有后台任务工具。Phase 2 Steps 4-8（上述）定义的串行内联执行是本平台的唯一 Worker 模式，不是"降级方案"。

串行内联执行的已知限制：

1. **上下文预算截断**：如果扫描项目大、信号多，达到上下文预算后未处理的 Skill 将被标记为 `unprocessed`。这是安全机制，不是故障
2. **无上下文隔离**：所有 Worker 在 Dispatcher 主会话中运行，残留上下文可能影响下一个 Worker 的判断
3. **抑制倾向**：如果上下文已满，后续 Worker 的判定质量下降。Ambiguous 信号应该优先抑制而非确认

**避免截断的策略：**
- 信号 > 50 的 Skill 按优先级分批处理，但不要在 Phase 2 一次加载所有规则文件
- 如果扫描包含大量字符串/IO 信号，**默认只运行 buffer_overflow、command_injection、memory 类高风险 Skill**，将 error_propagation、hardcoded_secrets 等低风险 Skill 延后或有选择地执行
- 如果上下文接近预算，优先运行信号量最少的 Skill（快速产出），跳过信号量大的 Skill（长时间占用上下文）
