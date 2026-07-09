---
name: secguard
description: "[OpenCode] 安全加固检视 — 信号驱动的检测引擎，Worker 串行内联执行（上下文预算控制），文件优先记录 finding"
platform: opencode
---

# /secguard — Dispatcher Protocol v2 (EPIC-3) [OpenCode]

## Command Layer

对源码执行安全加固扫描。采用 Dispatcher-Worker 架构：Dispatcher 读取索引信号 → 按 Skill 分派 Worker → Worker 只看相关代码执行 5 步检视协议。

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

> 本协议实现 EPIC-3 架构重构。从"LLM 全权扫描"（加载 67 规则 × 遍历 642 文件）转变为"信号驱动的 Worker 调度"（索引器预扫描 → Dispatcher 按信号分派 → Worker 只看相关代码）。
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
│    5. 生成 Worker 任务清单                                     │
│                                                               │
│  Phase 2: Worker 调度                                          │
│    对每个有信号的 Skill，启动 Worker (background-task):              │
│      - 输入: 信号清单 + SKILL.md + references/                  │
│      - Worker 执行 5 步检视协议 + 事实锚定反思                      │
│      - 输出: findings 文件 + 盲区报告                            │
│                                                               │
│  Phase 3: 汇总与渲染                                           │
│    1. 合并所有 Worker findings                                  │
│    2. 去重（同一调用点多 Skill → 最高严重度）                    │
│    3. 渲染 report.md + SARIF + summary.json + status.json       │
└──────────────────────────────────────────────────────────────┘
```

### 信号 → Skill 映射表 (Signal Matrix — EPIC-007)

```
┌─ S1: call_sites ───────────────────────────────────────┐
│ category          →  Skill(s)                           │
├─────────────────────────────────────────────────────────┤
string               →  buffer_overflow
                        must_check
                        api_semantic_misuse

memory               →  buffer_overflow
                        null_dereference
                        memory_leak
                        double_free
                        use_after_free
                        integer_overflow
                        ownership_transfer
                        must_check
                        api_semantic_misuse

io                   →  resource_leak
                        must_check

exec                 →  command_injection
                        input_validation

sync                 →  lock_misuse

crypto               →  hardcoded_secrets

* (all)              →  error_propagation
```

**特殊 Skill（非 call_site 驱动）:**
- `hardcoded_secrets` — **S2 string_literals 驱动**。扫描源码中的字符串/密钥模式。即使 call_sites 中 crypto 为零，只要 string_literals 有 `api_key`/`password`/`secret`/`jwt`/`token` 类信号，就启动 Worker。
- `error_propagation` — 扫描被忽略的函数返回值（扫描 `must_check` 标记函数的调用点，不依赖 call_sites 信号）

这两类 Skill 始终参与 Worker 调度，即使 Phase 1 未产出对应 category 的信号。

### ★ Detector Naming Convention（硬性规则）

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

python3 "$SCRIPTS_DIR/validate-index.py" \
    --index .codeagent/secguardian/index.json \
    --scan-id "$SCAN_ID"
```

若返回非 0，**立即终止扫描**并向用户报告索引生成出错。

### Step 4: 解析信号 (Signal Matrix) 并生成 Worker 任务清单

**此步骤由 Dispatcher 在上下文中直接执行（无 bash 调用）—— 读取 index.json 的 `call_sites` 和 `string_literals` 字段，按信号类型 + category 分组，映射到 Skill 清单。**

#### 4a. 读取 index.json

读取 `$USER_PROJECT/.codeagent/secguardian/index.json`，提取关键字段：

```json
{
  "call_sites": [
    {
      "caller": "idm_portal_auth",
      "callee": "strcpy_s",
      "file": "src/ctrlplane/portal/idm_portal_auth.c",
      "line": 142,
      "arguments": ["dst", "sizeof(dst)", "src"],
      "safe_variant": true,
      "category": "string"
    },
    {
      "caller": "idm_hwd_rsp_parse",
      "callee": "calloc",
      "file": "src/ctrlplane/pdt/hwd/idm_hwd_rsp_parse.c",
      "line": 100,
      "arguments": ["1", "in_len"],
      "safe_variant": false,
      "category": "memory"
    }
  ],
  "symbols": { "functions": [...] },
  "call_graph": { "edges": [...] },
  "alloc_free": { "pairs": [...] },
  "string_literals": [
    {
      "file": "src/crypto.c",
      "line": 21,
      "value": "sk-abcdef1234567890abcdef1234567890",
      "context": "global",
      "kinds": ["api_key"]
    },
    {
      "file": "src/crypto.c",
      "line": 26,
      "value": "SuperSecretPassw0rd!",
      "context": "authenticate_user",
      "kinds": ["secret"]
    }
  ]
}
```

#### 4b. 按信号类型 + category 分组

```
┌─ S1: call_sites ──────────────────────────────────┐
string  → [call_sites where category="string"]
memory  → [call_sites where category="memory"]
io      → [call_sites where category="io"]
exec    → [call_sites where category="exec"]
sync    → [call_sites where category="sync"]
crypto  → [call_sites where category="crypto"]
```

#### 4c. 生成 Worker 任务清单

对每个有信号的 category 和 string_literals 类别，按映射表关联到对应 Skill。若信号数 > BATCH_SIZE(50)，按 §5.5 拆分为多个 Batch 任务。每个 Worker 任务包含：

```json
{
  "skill_id": "buffer_overflow",
  "category": "string",
  "severity": "critical",
  "cwe": "CWE-120",
  "signal_count": 3,
  "signals": [
    {
      "caller": "idm_portal_auth",
      "callee": "strcpy_s",
      "file": "src/ctrlplane/portal/idm_portal_auth.c",
      "line": 142,
      "arguments": ["dst", "sizeof(dst)", "src"],
      "safe_variant": true,
      "category": "string"
    }
  ],
  "skill_path": "$SECGUARDIAN_HOME/skills/secguard-cpp/buffer_overflow/",
  "source_root": "$USER_PROJECT"
}
```

#### 4d. 写入 Worker 任务清单到文件（可选的持久化）

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

# Dispatcher 将 Worker 任务清单写入 workers/ 目录
# 格式: workers/<skill_id>/task.json
```

#### 4e. 脱敏答案卡标注（如果 index.json 包含源码行）

> 源码中可能存在 `// VULNERABILITY [CWE-xxx]`、`// CWE-xxx`、`// BAD:` 等标注注释。
> Worker 直接读源码时会看到这些标注，影响独立判断。必须预先脱敏。

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

# strip-answer-cards.py removed (EPIC-009) — demo sources now no-answers format
echo "  Strip-answer-cards: deprecated — prescreener handles deterministic filtering"
```

若输出 "deprecated" 日志，确认这是预期行为（EPIC-009 移除脱敏步骤）。

---

## Phase 2: Worker 调度

> **核心执行阶段**。Dispatcher 为每个有信号的 Skill 串行执行 Worker，独立执行 5 步检视协议，输出 findings。
>
> ⚠️ **关键现实：OpenCode 没有后台任务工具（`task()`/`background-task`/`Agent` 均不可用）。**
> **所有 Worker 必须在主会话中串行执行。** 因此必须严格控制每个 Worker 的上下文消耗，否则多 Skill 积累后必然溢出。
>
> **分批策略**：当单个 Skill 的信号数 > BATCH_SIZE(50) 时，Dispatcher 自动拆分为多个 Batch Worker。

### ⚠️ 上下文预算（OpenCode 核心约束）

> 这是 OpenCode 版最重要的规则。每步必须始终跟踪上下文消耗。

```
上下文预算规则（硬性约束）：
1. 每处理完一个 Worker，检查当前上下文是否接近满（~70%+）
2. 如果上下文即将溢出：立即停止，标记未处理 Skill 为 "unprocessed"，开始 Phase 3
3. 单个 Worker 内部的上下文约束：
   a. 源码读取：优先用 bash `cat` + `grep`（单行工具调用），避免 `Read` 工具（大块文本进入上下文）
   b. 禁用 Glob/Grep 工具探索源码（`✱Glob`/`✱Grep` 结果进入上下文）
   c. 禁用 `find` 探索（输出进入上下文）
   d. finding 录制：🚫 只允许唯一的 canonical 流程（写 JSON 文件 → `--from-file` 传路径）。禁止 `--from-stdin`、禁止直接 CLI `--detector --rationale`、禁止 `python3 << 'PYEOF'` 内联写 JSON。详见 §5.3 HARD RULE。
   e. LLM 分析：每个信号输出 <= 3 句结论，不需要完整 evidence chain 展示
```

**上下文消耗清单（每个 Worker）：**

| 操作 | 上下文消耗 | 优化方案 |
|------|-----------|---------|
| `cat` 读取 rule.md | 低 (~1-2K tokens) | 必须做，不接受优化 |
| `Read` 工具读源码 | **高** (~5-30K tokens/次) | 改用 `cat src/file.c \| sed -n '20,40p'` |
| `✱Glob`/`✱Grep` | **高** (全部匹配行进入上下文) | 改用 bash `grep`。必须在外层 bash 中完成，匹配结果不返回主会话。若确实需要，在 bash 中 grep 后用 `echo "found:N"` 仅返回计数 |
| `python3 record-finding.py --rationale "..."` | **极高** (~2-10K tokens/条) | **禁止**。改写入文件后用 `--from-file` |
| `Read` index.json | **高** (整个 JSON 进上下文) | Phase 1 已读取。Worker 用 bash `cat` + `python3 -c "import json; ..."` 按需提取 |
| Dispatcher 的 LLM 推理 | 中 (仅分析结论) | 每个信号只输出分析和 verdict |

### 5.1 Worker 启动协议

#### Step 0: 应用用户过滤器（如果指定）

```
PARSE user_filter FROM command arguments (e.g., "memory.*" or "memory.double_free")

IF user_filter IS NOT EMPTY:
  CONVERT filter TO regex patterns:
    "memory.*"            → pattern = ^memory\.
    "memory.double_free"  → pattern = ^memory\.double_free$
    "memory.*,exec.*"     → pattern = ^memory\.|^exec\.
    "" (default)          → pattern = .* (match all)

  filtered_skills = []
  FOR EACH skill IN skills WITH signals:
    IF skill.signal_filter MATCHES pattern:
      append skill TO filtered_skills
    ELSE:
      SKIP skill (no Worker dispatched)
ELSE:
  filtered_skills = ALL skills WITH signals
```

> **signal_filter 字段来源**：各 skill 的 `rules.md` frontmatter 中声明 `signal_filter`（如 `memory.buffer*`）。
> 过滤匹配基于 skill_id（如 `memory.buffer_overflow`），而非目录名。

#### Step 1: 串行执行 Worker（★ OpenCode 关键实现）

```
0. context_safe = true, skills_processed = 0

FOR EACH skill IN filtered_skills WHILE context_safe:

  1. 加载 rule.md:  cat "$SECGUARDIAN_HOME/skills/secguard-<language>/rules/{skill}/rule.md"
  2. 加载 references:  cat "$SECGUARDIAN_HOME/skills/secguard-<language>/rules/{skill}/references/*.md"
  3. 对 skill 的每个信号执行 W1-W5（详见 §5.2）:
     a. 读取源码: bash `cat $FILE | sed -n 'START,ENDp'` 获取信号所在行上下文（不要用 Read 工具）
     b. W1 信号确认: 判断信号是否真实（输出 1 行结论）
     c. W2 证据链: 分析 Source→Propagate→Sink（输出 3 行，每行 <= 60 字）
     d. W3 安全变体审计: 有则检查（输出 1 行结论）
     e. W4 跨函数补证: 从 index.json 查 caller（输出 1-2 行结论）
     f. W5 事实锚定: 回答 3 个域专用 Q（Yes/No + 1 行依据）
  4. 写入 finding:
     a. 构造 JSON 对象（不含过长的 rational/attack_scenario）
     b. bash: echo '{compact json}' > $SCAN_DIR/workers/{skill}/finding-N.json
     c. bash: python3 $RECORDER --command secguard --from-file $SCAN_DIR/workers/{skill}/finding-N.json
  5. 写 blindspot.json: echo '{...}' > $SCAN_DIR/workers/{skill}/blindspot.json
  6. skills_processed += 1
  7. 上下文预算检查:
     IF 上下文已使用 > 70%（估算方法：bash 工具已调用了 N 次，每次约 0.5-2K tokens）:
       context_safe = false
       echo "CONTEXT_BUDGET: stopping after {skills_processed} skills. {remaining} skills marked unprocessed."
```

**关键约束:**
> 🚫 **HARD RULE: 禁止 Read 工具 + 禁止全文件 cat** 
>  
> 任何时候读取源码文件，必须使用以下模式（禁止全文件读取）：
> 
> ```bash
> # ✅ GOOD: line-range only (±15 lines around target line)
> cat "$SOURCE_DIR/src/file.py" | sed -n '25,55p'
> 
> # ❌ BAD: full-file cat (wastes context — example from session ses_0ba5)
> cat "$SOURCE_DIR/src/file.py"
> ```
> 
> **示例**: 如果信号在文件 40 行，用 `cat file \| sed -n '25,55p'` 读取 ±15 行范围。不读取文件其余行。
> 
> **违反后果**: 全文件 `cat` 将数千行源码塞入 LLM 上下文，迅速溢出上下文窗口，导致扫描失败。
- ⚠️ **禁止使用 `✱Glob`/`✱Grep` 工具**。改用 bash `grep`
- ⚠️ **finding 必须通过文件传递**（禁止 `--from-stdin` 或长 `--rationale` CLI 参数）
- ⚠️ **每个信号的分析输出 <= 6 行**。evidence chain 写入 finding JSON 文件，不在会话中展示
- ⚠️ L 每个 skill 处理完后主动检查上下文，不要等溢出

> **重要**: Worker 协议从 5 轮反思升级为事实锚定反思（§5.2 W5 更新点）。
> 旧协议已被实验证伪：同 LLM 同上下文同框架 → 5 轮产出同质化结论。
> 新协议用 3 个域专用 Yes/No 事实问题替代 5 轮空转。
> 详见 `skills/secguard-cpp/` 各 skill 的 `rules.md §事实锚定反思`。

**Worker 输入结构：**

```json
{
  "dispatcher_context": {
    "scan_id": "sc-20260707-143000-a1b2",
    "scan_dir": ".codeagent/secguardian/secguard/scans/sc-20260707-143000-a1b2",
    "source_root": "/path/to/user/project",
    "stripped_root": "/path/to/user/project",  # DEPRECATED (EPIC-009) — same as source_root
    "index_json": ".codeagent/secguardian/index.json",
    "recorder": "$SCRIPTS_DIR/record-finding.py",
    "reporter": "$SCRIPTS_DIR/render-report.py"
  },
  "skill": {
    "id": "buffer_overflow",
    "severity": "critical",
    "cwe": "CWE-120",
    "category": "string",
    "rule": "... rule.md 内容（检测规则 + Scenario + Worker 检视协议）...",
    "references": {
      "exceptions": "... exceptions.md 内容 ...",
      "cross_function": "... cross-function.md 内容 ...",
      "false_positive": "... false-positive.md 内容 ..."
    }
  },
  "signals": [
    {
      "caller": "idm_portal_auth",
      "callee": "strcpy_s",
      "file": "src/ctrlplane/portal/idm_portal_auth.c",
      "line": 142,
      "arguments": ["dst", "sizeof(dst)", "src"],
      "safe_variant": true,
      "category": "string"
    }
  ]
}
```

### 5.2 Worker 执行协议（5 步）— OpenCode 内联版

> ⚠️ **OpenCode 上下文约束版**：所有 W1-W5 步骤必须在 Dispatcher 主会话中串行执行，每个信号的分析输出 <= 6 行。证据链详情写入 finding JSON 文件，不在会话中展示。

#### Step W1: 信号确认

对每个预筛信号:

1. 读取调用点源码（±15 行）: `cat src/file.c | sed -n 'START,ENDp'`（**禁止 Read 工具**）
2. 确认调用点真实存在（排除注释、宏、条件编译中的误匹配）
3. 记录: `confirmed` / `false_signal`（如为 false_signal 则跳过）+ **仅输出 1 行结论**

#### Step W2: 证据链构建（输出 <= 3 行）

构建 Source → Propagate → Sink 三段式证据链，每行 <= 60 字:

```
Source: dst char[64] at file.c:130
Propagate: input as param to idm_portal_auth at file.c:140
Sink: strcpy_s(dst, 64, input) — input 长度未知
```

**跨函数追踪约束:**
- 沿 index.json 调用图向上追踪 **最多 1 层**
- 超过 1 层 → 降级为 **suspicious**，计入抑制统计

#### Step W3: 安全变体参数审计

对 `_s` 安全变体调用（`safe_variant: true`），检查参数正确性——**安全变体不意味着自动安全**:

| 函数 | 审计项 |
|------|--------|
| `strcpy_s(dst, dsize, src)` | `dsize` 是否 `== sizeof(dst)`? `dst` 是否为数组（而非指针参数）? |
| `strcat_s(dst, dsize, src)` | `dsize` 是否考虑已有内容? `sizeof(dst) - strlen(dst) >= strlen(src)`? |
| `memcpy_s(dst, dsize, src, n)` | `dsize >= n`? `dsize == sizeof(dst)`? |
| `sprintf_s(buf, size, fmt, ...)` | `size == sizeof(buf)`? `fmt` 含 `%s` 时对应参数是否受控? |
| `snprintf(buf, size, fmt, ...)` | 返回值是否被检查（截断检测）? |

非 `_s` 变体直接进入 Step W4。

#### Step W4: 跨函数补证

1. 从 index.json 查找调用者函数：`python3 -c "import json; d=json.load(open('.../index.json')); ..."`（**禁止 Read index.json**）
2. 读取调用者源码：cat + sed（**禁止 Read 工具**）
3. 检查调用者是否传入已知大小的缓冲区或未检查的用户输入
4. depth > 1 → 降级为 `suspicious`，不计入确认发现

#### Step W4.5: 多信号归并分析

当同一函数内有多个信号时，先聚合再逐条分析。避免重复读取同一段源码。

#### Step W5: 事实锚定反思

**基于 3 个域专用事实锚定问题, 一轮判定。**

**通用 Q 框架:**
```
Q1: [域专用，迫使检查最关键的"是否有漏洞"条件]
Q2: [域专用，迫使检查条件是否真实（如参数来源、初始化状态）]
Q3: [域专用，迫使检查豁免/补偿条件是否存在]
```

**判定矩阵：**

| Q1 | Q2 | Q3 | 结论 |
|----|----|----|------|
| YES(安全) | YES | YES | **SUPPRESS** |
| YES(安全) | YES | NO | **informational** |
| YES(安全) | NO | — | **CONFIRMED** |
| NO(危险) | YES | — | **CONFIRMED** |
| NO(危险) | NO | — | **CONFIRMED** |
| Mixed | Mixed | Mixed | 强制详细分析后判断 |

**执行：**
1. 回答 3 个事实锚定问题（仅 Yes/No + 行号引用，**每问 1 行**）
2. 查判定矩阵 → 决定 verdict
3. 三绿灯: 直接抑制，记入抑制统计（输出 1 行 "SUPPRESSED: ..."）
4. 确认: 输出 1 行 "CONFIRMED: ..." + 写入 finding JSON

### 5.3 Worker 输出格式 — 文件优先（★ 上下文安全版）

> ⚠️ **HARD RULE: 每个 finding 只允许一种记录方式。禁止混用。**
>
> **唯一允许的流程**: 写 JSON 文件 → `--from-file` 传给 `record-finding.py`。
>
> **🚫 禁止以下方式:**
> - ❌ `--from-stdin`: 消除 shell 引用问题但 LLM 会多路径冗余写入
> - ❌ 直接 CLI `--detector --rationale "..."`: 长文本进上下文
> - ❌ `python3 << 'PYEOF'` 内联写 JSON: 与 `--from-file` 路径重复
> - ❌ `python3 -c "..."` 混杂 `$SCAN_DIR`: 引号层级混乱易出错
>
> **幂等性**: `record-finding.py` 已内置 SHA 幂等守卫。相同 `(detector, file, line, cwe)` 的第二次写入会被 `IDEMPOTENT_SKIP` 跳过，不会重复。

**唯一 canonical 流程:**

```bash
# Step 1: 写 finding JSON 到 workers 目录（使用引用 heredoc << 'FEOF'）
# ⚠️ Finding JSON 必须使用嵌套 schema:
#   location: {file_path, start_line, end_line, snippet}
#   evidence: {code_context, judgment_rationale}
#   impact: {attack_scenario}
#   fix: {before_code, after_code, description}
#   id: "secguard-{detector-dashed}-{sha12}"
#   title: (必填，validate --list 输出中显示)
cat > "$SCAN_DIR/workers/{skill}/finding-{id}.json" << 'FEOF'
{
  "id": "secguard-{detector-dashed}-{sha12}",
  "command": "secguard",
  "detector": "memory.buffer_overflow",
  "severity": "Critical",
  "cwe": "CWE-120",
  "title": "strcpy_s called with untrusted input — buffer overflow",
  "location": {
    "file_path": "src/file.c",
    "start_line": 142,
    "end_line": 145,
    "snippet": "strcpy_s(dst, sizeof(dst), input)"
  },
  "evidence": {
    "code_context": "char dst[64];\\nstrcpy_s(dst, sizeof(dst), input)",
    "judgment_rationale": "strcpy_s dsize=64, input length unknown — no size check before copy"
  },
  "impact": {
    "attack_scenario": "Long input overflows dst[64] — buffer overflow exploitable"
  },
  "fix": {
    "before_code": "strcpy_s(dst, sizeof(dst), input)",
    "after_code": "if (strnlen(input, 64) >= 64) return error;\\nstrcpy_s(dst, sizeof(dst), input);",
    "description": "Check input length before copy"
  },
  "scan_dir": "$SCAN_DIR",
  "index_json": ".codeagent/secguardian/index.json"
}
FEOF

# Step 2: ⚠️ 必须加 --scan-dir "$SCAN_DIR"（引用 heredoc 阻止了 $SCAN_DIR 展开）
python3 "$RECORDER" --command secguard --scan-dir "$SCAN_DIR" --from-file "$SCAN_DIR/workers/{skill}/finding-{id}.json"

# Step 3: 写 blindspot 报告
echo '{"skill_id":"{skill}","signals_received":N,"findings_reported":N,...}' > "$SCAN_DIR/workers/{skill}/batch-00/blindspot.json"
```

> **关于 zsh heredoc 兼容性**: macOS 默认 zsh 在 `<< 'FEOF'` 引用 heredoc 中传递 JSON 的 `\\n` 不会展开，这是正确的 JSON 行为。如果遭遇 zsh 解析错误，改用 `python3 -c "import json; json.dump(obj, open(...))"` 通过 subprocess 写入同一路径，再走 Step 2 的 `--from-file` 流程。**切勿**在 `python3 -c` 里同时写 finding-{id}.json 再调 recorder — 先写文件，再 --from-file，两个步骤分两次工具调用。

**盲区报告（当所有信号被抑制时输出）:**

```json
{
  "skill_id": "buffer_overflow",
  "signals_received": 15,
  "findings_reported": 3,
  "findings_suppressed": 5,
  "false_signals": 7,
  "suppression_reasons": [
    {"reason": "sizeof(dst) matches dsize correctly", "count": 3}
  ],
  "depth_exceeded": {"count": 2, "max_traced": 1}
}
```
写入: `echo '{...}' > "$SCAN_DIR/workers/{skill}/batch-00/blindspot.json"`
{
  "skill_id": "buffer_overflow",
  "signals_received": 15,
  "findings_reported": 3,
  "findings_suppressed": 5,
  "false_signals": 7,
  "suppression_reasons": [
    {"reason": "sizeof(dst) matches dsize correctly", "count": 3},
    {"reason": "compile-time constant string source", "count": 2}
  ],
  "depth_exceeded": {
    "count": 2,
    "max_traced": 1,
    "downgraded_to_suspicious": 2
  }
}
```

**零发现报告（当 Skill 没有任何信号时）:**

```json
{
  "skill_id": "error_propagation",
  "signals_received": 0,
  "findings_reported": 0,
  "status": "no_signal",
  "assessment": "没有需检查返回值传播的 must_check 函数调用点",
  "is_blindspot": false
}
```

**关键约束:**
- **禁止非终止状态**: Worker 不得输出"需要更多上下文"、"无法确定"、"信息不足"等。必须做出确定判断：`confirmed` / `suppressed` / `downgraded_to_suspicious`
- **0 findings ≠ no_signal**: 区分 `no_signal`（无信号，真安全）和 `all_suppressed`（有信号但全部被抑制，检测盲区）
- **跨函数 depth 限制**: max depth 1，超过一律降级为 `suspicious`，不报告为确认漏洞
- **事实锚定反思强制**: 任何 finding 必须经过事实锚定反思，`fact_anchored_reflection` 字段必须包含 Q1-Q2-Q3 答案及矩阵裁决
- **suppress-first**: 不确定 → 抑制。仅报告有完整证据链的 finding

### 5.4 特殊 Skill 处理

#### hardcoded_secrets（非 call_site 驱动）

此 Skill 不依赖 call_sites 信号。Worker 改为扫描源码中的字符串/密钥模式:

1. 从 index.json 获取文件清单（`files` 数组去重）
2. 对每个源码文件扫描以下模式:
   - 硬编码密码: `password = "..."`, `passwd = "..."`, `pwd = "..."`
   - 硬编码密钥: `secret_key = "..."`, `api_key = "..."`, `token = "..."`
   - 硬编码加密 IV/盐: `iv = "..."`, `salt = "..."`
   - 注释中的凭据: `// password: ...`, `// user: ... / pass: ...`
3. 根据 `min_string_length`（灵敏度配置）过滤短字符串
4. 执行事实锚定反思确认

#### error_propagation（独立扫描）

此 Skill 不依赖 call_sites 信号。Worker 改为扫描返回值检查:

1. 从 index.json 的 `call_sites` 中筛选 `must_check` 标记的函数调用
2. 对每个调用点检查返回值是否被使用、检查、或传播
3. 识别模式:
   - `if (func() == ERROR)` → 已检查
   - `int ret = func()` → 部分检查（需确认 ret 后续使用）
   - `func()` → 返回值被丢弃（报告）
   - `(void)func()` → 显式丢弃（是否报告取决于灵敏度配置）
4. 执行事实锚定反思确认

### 5.5 Batch 分批派发协议（★ 生产级扩展）

当单个 Skill 的信号数量超过 `BATCH_SIZE`（默认 50）时，Dispatcher 不再截断，而是**拆分为多个 Batch Worker**并按 background-task 并行调度。

| 场景 | 计算 | 示例 (buffer_overflow ~2500 signals) |
|------|------|----------------------------------------|
| 信号数 <= BATCH_SIZE | 直接派发 1 个 Worker | — |
| 信号数 > BATCH_SIZE | `n_batches = ceil(signal_count / BATCH_SIZE)` | 2500/50 = 50 batches |
| Worker 数 | = n_batches | 50 Workers（background-task 自动并行约 10 个并发） |

#### 5.5.1 Batch 拆分规则

```
FOR EACH skill WITH signals:
  n_batches = ceil(len(signals) / BATCH_SIZE)
  IF n_batches == 1:
    → 正常派发 1 个 Worker（同旧协议 §5.1）
  ELSE:
    1. 将 signals 按文件分组（同文件信号保持在一起）
    2. 均分为 n_batches 组，确保每组约 BATCH_SIZE 个信号
    3. 每组生成一个 Worker 任务（batch-N/task.json）
    4. 启动 n_batches 个 Worker，每个 Worker 在 $SCAN_DIR/workers/<skill_id>/batch-N/ 下输出
```

**分组原则**：
- 同一文件的信号尽量分在同一 Batch（减少重复读取源码开销）
- 同一 caller function 的信号不分拆（保持 W4.5 多信号归并的完整性）
- Batch Worker 无状态：每个 Worker 完全独立，不共享上下文

#### 5.5.2 Worker 任务清单（Batch 版本）

```json
{
  "skill_id": "buffer_overflow",
  "category": "string",
  "severity": "critical",
  "cwe": "CWE-120",
  "batch": {
    "index": 3,
    "total": 50,
    "size": 50
  },
  "signal_count": 50,
  "signals": [
    {
      "caller": "idm_portal_auth",
      "callee": "strcpy",
      "file": "src/ctrlplane/portal/idm_portal_auth.c",
      "line": 142,
      "arguments": ["dst", "src"],
      "safe_variant": false,
      "category": "string"
    }
  ],
  "skill_path": "$SECGUARDIAN_HOME/skills/secguard-cpp/buffer_overflow/",
  "source_root": "$USER_PROJECT"
}
```

#### 5.5.3 Worker 输出目录结构

```
$SCAN_DIR/workers/
├── buffer_overflow/
│   ├── batch-00/
│   │   ├── task.json              # 该 Batch 的任务定义
│   │   ├── blindspot.json         # 该 Batch 的盲区报告
│   │   └── findings/              # record-finding.py 录制的 finding
│   ├── batch-01/
│   │   ├── task.json
│   │   ├── blindspot.json
│   │   └── findings/
│   └── ...  (最多 n_batches)
├── double_free/
│   └── batch-00/                  # 信号数 <= BATCH_SIZE，仅 1 个 Batch
│       ├── task.json
│       ├── blindspot.json
│       └── findings/
└── ...
```

#### 5.5.4 BATCH_SIZE 配置

| 参数 | 默认值 | 说明 | 调整依据 |
|------|--------|------|---------|
| `BATCH_SIZE` | 50 | 每 Batch 最大信号数 | Worker context window 决定 |
| `MAX_BATCH_WORKERS` | 100 | 单 Skill 最大 Batch Worker 数 | background-task 工具上限 |

超出 `MAX_BATCH_WORKERS` 时，Dispatcher 记录 WARNING，将超额信号标记为 `unprocessed`（与旧截断策略相同）。

#### 5.5.5 Worker 协议适配

Batch Worker 完全遵循 §5.2 的标准 5 步协议，仅有以下差异：

| 项目 | 单 Worker | Batch Worker |
|------|-----------|-------------|
| 信号范围 | 全部 | 仅本 Batch 的 signals |
| 多信号归并(W4.5) | 跨全量信号 | **仅限本 Batch 内**同一 caller function |
| 盲区统计范围 | 本次扫描 | 仅 Batch 级别（Aggregator 合并） |
| 输出前缀 | workers/<skill_id>/ | workers/<skill_id>/batch-N/ |
| 独立性 | 完全独立 | 完全独立，不依赖其他 Batch |

> **重要限制**：跨 Batch 的同函数信号归并不在 Worker 层进行——由后续 Aggregator (§5.6) 在汇总时处理。

### 5.6 Aggregator 协议（★ 新增）

> 所有同 Skill 的 Batch Worker 完成后，Aggregator 合并它们的产出去重。

Dispatcher 为每个有 >= 2 个 Batch 的 Skill 启动一个 Aggregator 子任务（也通过 `task(..., run_in_background=true)` 派发）。对于只有 1 个 Worker 的 Skill，跳过 Aggregator。

#### 5.6.1 Aggregator 输入

```json
{
  "aggregator_context": {
    "skill_id": "buffer_overflow",
    "batch_count": 50,
    "total_signals": 2500,
    "batches": [
      "workers/buffer_overflow/batch-00/",
      "workers/buffer_overflow/batch-01/",
      "..."
    ],
    "scan_dir": ".codeagent/secguardian/secguard/scans/sc-20260707-143000-a1b2",
    "finding_manifest": {
      "batch-00": {"reported": 1, "suppressed": 42, "suspicious": 2, "false_signals": 5},
      "batch-01": {"reported": 0, "suppressed": 38, "suspicious": 3, "false_signals": 9}
    }
  }
}
```

#### 5.6.2 Aggregator 执行协议（3 步）

**Step A1: 跨 Batch 去重**

遍历所有 Batch 的 findings，识别跨 Batch 的重复报告：

| 去重规则 | 判定条件 | 保留策略 |
|----------|---------|---------|
| 同一 `file:line:CWE` | 完全匹配 | 保留第一个 Batch 的 finding（时间优先） |
| 同一缓冲区多个 Sink | 同一函数内同一缓冲区的 strcpy+strcat | 合并为 1 个复合 finding |
| 证据链冗余 | Source/Propagate 完全相同 | 合并或丢弃副本 |

**Step A2: 合并盲区统计**

```json
{
  "skill_id": "buffer_overflow",
  "total_signals": 2500,
  "batches_dispatched": 50,
  "batches_with_findings": 3,
  "batches_all_suppressed": 45,
  "batches_no_signal": 2,
  "total_findings_after_dedup": 2,
  "total_suppressed": 2320,
  "total_suspicious": 125,
  "total_false_signals": 51,
  "total_unprocessed": 0,
  "suppression_reasons": [
    {"reason": "sizeof(dst) matches dsize correctly", "count": 980},
    {"reason": "compile-time constant string source", "count": 750}
  ],
  "depth_exceeded": {
    "count": 125,
    "max_traced": 1,
    "downgraded_to_suspicious": 125
  },
  "findings": [
    {"file": "src/parser.c", "line": 36, "cwe": "CWE-120", "title": "...", "batch": "batch-00"},
    {"file": "src/network.c", "line": 89, "cwe": "CWE-120", "title": "...", "batch": "batch-03"}
  ]
}
```

**Step A3: 输出合并后产物**

Aggregator 输出到 `$SCAN_DIR/workers/<skill_id>/aggregated/`:

```
workers/buffer_overflow/aggregated/
├── blindspot.json      # 合并后的盲区报告
├── findings/           # 去重后的 finding（符号链接或副本）
└── summary.json        # 合并摘要
```

---

## Phase 3: 汇总与渲染

> 所有 Worker 和 Aggregator 执行完毕后，Dispatcher 汇总结果并生成报告。

### Step 6: 汇总 Worker 产物（Batch 感知）

1. 遍历 `$SCAN_DIR/workers/<skill_id>/` 下的每个 Worker 输出
2. 若存在 `aggregated/blindspot.json`（该 Skill 有多个 Batch）：
   - 使用 Aggregator 合并后的产物（已去重、已合并统计）
   - 收集 `aggregated/findings/` 下的 finding 文件
   - 收集 `aggregated/blindspot.json` 作为该 Skill 的盲区报告
3. 若不存在 `aggregated/`（该 Skill 仅 1 个 Worker）：
   - 直接从 `batch-00/`（或 `skill_id/` 根目录）收集 finding 和 blindspot
4. 汇总到 `worker_manifest.json`:

```json
{
  "scan_id": "sc-20260707-143000-a1b2",
  "mode": "batch",
  "batch_size": 50,
  "workers_dispatched": 58,
  "workers_with_findings": 6,
  "workers_all_suppressed": 49,
  "workers_no_signal": 3,
  "total_signals_processed": 2545,
  "total_findings_reported": 8,
  "total_findings_after_dedup": 7,
  "total_suppressed": 2380,
  "total_suspicious": 131,
  "total_unprocessed": 0,
  "workers": {
    "buffer_overflow": {
      "status": "has_findings",
      "batches": 50,
      "signals": 2500, "reported": 3, "suppressed": 2320, "suspicious": 125,
      "aggregated": true
    },
    "double_free": {
      "status": "has_findings",
      "batches": 1,
      "signals": 15, "reported": 3, "suppressed": 5, "suspicious": 2
    },
    "null_dereference": {
      "status": "all_suppressed",
      "batches": 1,
      "signals": 8, "reported": 0, "suppressed": 8
    },
    "error_propagation": {
      "status": "no_signal",
      "signals": 0, "reported": 0
    }
  }
}
```

### Step 7: 去重（跨 Skill）

> **跨 Batch 去重已在 Aggregator (§5.6) 中完成。** 此处仅处理跨 Skill 的冗余。

不同 Skill 可能报告同一调用点，Dispatcher 保留最高严重度的 finding:

| 规则 | 示例 |
|------|------|
| 同一 `file:line` 跨多个 Skill | `buffer_overflow` 和 `must_check` 都报告同一 `strcpy_s` 调用 → 保留 `buffer_overflow`（Critical > Medium） |
| 同一缓冲区多个 Sink | 同一函数内 `strcpy(dst, a)` + `strcat(dst, b)` → 合并为 1 个 finding |
| 证据链冗余 | 两个 finding 的 Source/Propagate 完全相同 → 合并 |

去重规则由 Dispatcher 在上下文中执行（不通过 bash 脚本）。

### Step 8: 验证 findings

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

python3 "$SCRIPTS_DIR/validate-findings.py" \
    --findings-dir "$SCAN_DIR/findings/" \
    --check-spec \
    --list
VALIDATE_EXIT=$?
if [ $VALIDATE_EXIT -eq 0 ]; then
    echo "  All findings pass validation + spec cross-check"
else
    echo "  Spec validation found violations — findings must be regenerated"
    echo "  Dispatcher must re-read SKILL.md Detection Spec and fix severity/CWE/evidence"
fi
```

> Spec 校验是强约束：finding 的 severity、CWE、evidence 必须匹配对应 SKILL.md 的 Detection Spec。跳过规则文件加载的 finding 将被拒绝。

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

## 附录 A: 15 个 Skill 清单

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

## 附录 B: Worker 协议摘要

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
