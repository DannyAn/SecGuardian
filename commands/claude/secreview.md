---
name: secreview
description: "[Claude Code] AI Security Code Review — 5-language PR security review via EPIC-3 Dispatcher protocol"
platform: claude
---

# /secreview - AI Security Code Review for Pull Requests

## ⚙️ Command Layer


AI-powered security code review designed for pull requests, repositories and completed implementations.

Unlike traditional linters, SecReview reasons about code behavior, business logic and exploitability.

## Usage

```
# ★ 零参数缺省调用（推荐）
/secreview                                           # 检测当前目录，自动识别语言，git diff 模式

# 全量代码库检视
/secreview ./src                                     # 语言自动检测
/secreview ./src java                                # Java code review

# Git diff / PR review 模式
/secreview git diff                                  # 当前目录的变更
/secreview ./src cpp git diff main                   # Current branch vs main

# SARIF 输出
/secreview ./src java --sarif                        # Append SARIF 2.1.0 output
```

## Output Path Convention

> ⚠️ The `.codeagent/` output directory must be placed in the **user's project root**, not in SecGuardian's project root.
>
> Determine the user project root from the `<path>` argument:
> - Resolve `<path>` to an absolute path, use its **parent** as the user project root
> - All output paths must use `<user-project>/.codeagent/` prefix
> - Do NOT use bare `.codeagent/` (it resolves to SecGuardian's root)

## Output

Follows [Scan Output Protocol 5.0](../knowledge/protocols/scan-output.md). Human-readable and machine-readable separation.

```
<user-project>/.codeagent/secguardian/secreview/scans/<scan-id>/
├── human/                    # ★ v7.0: Unified entry point
│   └── executive-summary.md    One-page dashboard + finding distribution + navigation
├── findings/                 # Per-detector organized finding directory tree
├── ai/                       # ★ v7.0: AI-consumable
│   └── remediation-pack.json   AI remediation pack (with cross-references)
├── report.md                 # ★ Human-readable review report (concise 5 sections)
├── dashboard.html            # ★ v7.0: Management dashboard
├── results.sarif             # Machine: SARIF 2.1.0 (CI/CD)
├── summary.json              # Dashboard statistics
├── manifest.json             # Review metadata + finding index
├── status.json               # CI gate status
└── delta.json                # Delta vs previous scan
```

**Execution summary (must output after each run):**

```
## secreview review complete

Scan ID: pr-20260531-143000-a1b2
Project: <project-name>
Workspace: <user-project>
Path: ./src
Language: Java (auto-detected)
Mode: git diff main

### Results
- Files reviewed: 12 (8 changed + 4 context)
- Review dimensions: 6 checked
- Findings: 5 (Critical: 0, High: 2, Medium: 3, Info: 0)

### Findings
| # | Severity | CWE | File | Summary |
|---|----------|-----|------|---------|
| #1 | 🟠 High | CWE-089 | src/service/UserService.java:89 | SQL injection via string concatenation |
| #2 | 🟠 High | CWE-807 | src/controller/AdminController.java:23 | Trust boundary violation in auth bypass |
| #3 | 🟡 Medium | CWE-532 | src/handler/AuthHandler.java:156 | Sensitive data in log output |
| #4 | 🟡 Medium | CWE-200 | src/filter/RequestFilter.java:42 | ThreadLocal data leak across requests |
| #5 | 🟡 Medium | CWE-829 | src/service/OrderService.java:203 | Unsafe deserialization from user input |

> Each finding includes exploit scenario, CWE mapping, severity assessment, CVE-like CVSS scoring, and fix recommendation.

Output directory: <user-project>/.codeagent/secguardian/secreview/scans/pr-20260531-143000-a1b2/

💡 **How to use review results?**
- **Quick summary** -> `manifest.json`
- **★ Unified entry** -> `human/executive-summary.md`
- **Engineer remediation** -> Per-finding in `findings/` directory
- **Management dashboard** -> Open `dashboard.html` in browser
- **Full review report** -> `report.md` (5-section concise report)
- **🤖 AI Agent fix** -> Read `ai/remediation-pack.json`
- **CI/CD integration** -> Consume `results.sarif`
```

## Difference from /secguard

| Dimension | secguard | secreview |
|-----------|----------|-----------|
| SDLC Stage | During coding | During pull request / code review |
| Primary Users | Individual developers | Developers + Reviewers + PR approvers |
| Granularity | API-level + detector filtered | Function/module-level semantic + business logic |
| Focus | Does this API call introduce a vulnerability? | Is the change safe to merge? |
| Output | CWE + CVSS + detection detail | CWE + exploit scenario + business logic impact |
| Severity | Critical -> Info | High -> Info (PR-blocking semantics) |
| Typical Mode | Full codebase scan | Git diff / PR changeset |


## 🛠️ Engine Layer

> 以下内容属于 Engine 职责（参见 `internal/engine/engine_contract.md`）。当前由 LLM prompt 代行执行。未来 Engine 实现后，此处内容将被 Engine 取代。
>
> 🚫 **不要使用 `todowrite` 工具。** 使用原生 task 系统（`TaskCreate` + `TaskUpdate`）追踪进度。
> `todowrite` 每次调用重传全部已完成项，每会话浪费 ≥50KB 无效 token。
>
> 🚫 **不要硬编码 `RECORDER` 路径。** 必须使用 `$SCRIPTS_DIR/record-finding.py`。
> 硬编码路径在安装位置变动时全断。
>
> 🚫 **Do NOT use `read` tool on `$SCRIPTS_DIR/` files.** All scripts execute via `Bash` tool — their CLI interfaces are fully documented in this template. Reading script files triggers unnecessary OpenCode permission prompts and wastes tokens.

## Dispatch Rules & Execution Steps

> **Architecture (Signal Matrix — EPIC-007)**: SecGuardian EPIC-3 refactors the execution pipeline into 15 focused C/C++ detection skills, dispatched via the unified Dispatcher protocol defined in `commands/secguard.md`. Security code review uses **S1 + S2 + S7 signals** (call_sites, string_literals, control_flow) for PR diff-context analysis. Shared execution flow (init, indexing, output protocol, summary) follows the Dispatcher. secreview adds per-language review rules and three-reasoning-pass analysis (vulnerability, business logic, anti-pattern). secreview-specific logic stays here; shared pipeline steps follow the Dispatcher protocol.

You (the AI Agent) must follow these steps when executing `/secreview` to perform the security code review.

### Pre-flight Checklist

### 前置检查（Pre-flight Checklist）

> ⛔ **禁止使用 Glob 或 Read 工具探索文件路径（搜索文件）。已知路径的文件用 `cat` 读取。**

执行审阅前确认：

- [ ] 目标路径 `<path>` 存在且包含至少一个源码文件
- [ ] **语言检测**（当用户省略 `language` 参数时）：扩展名检查 -> `cpp`/`python`/`java`/`go`
- [ ] 不使用 clangd/LSP/bear 等外部工具
- [ ] `SECGUARDIAN_HOME`/健康检查/目录创建由 Step 1 的 `init-scan.sh` 统一处理

> 若未通过，报告具体失败项并终止。不要降级为手工审阅。

---

<!-- @secguardian:ordering rule=scan_id FIRST -->
### Step 1: 初始化（唯一 bash 调用，使用共享 init-scan.sh）

> **唯一一次预初始化 bash 调用**。通过 `scripts/init-scan.sh` 完成 SECGUARDIAN_HOME 自动发现、健康检查、路径确认、建目录、写 `.scan_state.secreview`。

```bash
source "$HOME/.claude/plugins/secguardian/scripts/init-scan.sh" secreview "<path>"
```

- Record review start timestamp for Step 4 `duration_ms` calculation.

### 🔒 Cross-Shell State Passing (ALL bash calls after Step 1 MUST follow)

> **Each bash call is an independent shell — variables are not shared. NEVER use `/tmp/` for state.**
> `/tmp/` breaks on Windows, triggers macOS permission prompts, and is multi-user unsafe.

Step 1 persists `SCAN_ID`, `SCAN_DIR`, `USER_PROJECT`, `SECGUARDIAN_HOME`, `RECORDER` in `.scan_state.secreview`.
From Step 2 onward, **every bash call MUST start with**:
```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secreview"
```
After this, `$SCAN_DIR`, `$SCAN_ID`, `$USER_PROJECT`, `$SECGUARDIAN_HOME`, `$RECORDER` expand correctly inside bash commands. NEVER use `$(cat /tmp/*.txt)`.

> **📂 Knowledge reading**: Knowledge files are at `$SECGUARDIAN_HOME/knowledge/`. Read on demand via bash `cat` — no directory copy.
> - Review rules: `cat "$SECGUARDIAN_HOME/skills/secreview/{lang}/rules/{lang}.md"`
> - Language profile: `cat "$SECGUARDIAN_HOME/skills/secguard-{lang}/references/language-features.md"`
> - Protocols: `cat "$SECGUARDIAN_HOME/knowledge/protocols/{name}.md"`
> - DO NOT use `read` tool on `$SECGUARDIAN_HOME/knowledge/` (triggers permission prompts). Use bash `cat` instead — no permission prompt.

### Step 2: Build Semantic Index (Required)

> ⚠️ This is the **core prerequisite** for review. The indexer provides symbol table and call graph needed for structured security analysis. **Skipping this step will severely degrade review quality.**

**2a. Execute indexer (blocking):**
> Index caching is automatic. Add `--force` to force a rebuild.

```bash
INDEXER="$SCRIPTS_DIR/secguardian-index"
# 超时保护: timeout 30s，防止索引器挂死。macOS 需要 brew install coreutils。
if command -v timeout &>/dev/null; then
    timeout 30 "$INDEXER" --path "$SCAN_PATH" --output "$USER_PROJECT/.codeagent/secguardian/index.json" || {
        echo "FAIL: Indexer timed out after 30s or failed — cannot continue"
        echo "  macOS: brew install coreutils  (provides 'timeout' command)"
        exit 1
    }
elif command -v gtimeout &>/dev/null; then
    gtimeout 30 "$INDEXER" --path "$SCAN_PATH" --output "$USER_PROJECT/.codeagent/secguardian/index.json" || {
        echo "FAIL: Indexer timed out after 30s or failed — cannot continue"
        exit 1
    }
else
    echo "WARNING: 'timeout' not found — indexer runs without timeout protection"
    echo "  Install coreutils: brew install coreutils (macOS) or apt install coreutils (Linux)"
    "$INDEXER" --path "$SCAN_PATH" --output "$USER_PROJECT/.codeagent/secguardian/index.json"
fi
if [ ! -f "<user-project>/.codeagent/secguardian/index.json" ]; then
    echo "FATAL: Indexer failed — cannot continue"
    exit 1
fi
```

**2b. Validate index integrity (required):**

```bash
python3 "$SCRIPTS_DIR/validate-index.py" \
    --index <user-project>/.codeagent/secguardian/index.json \
    --scan-id <scan_id>
```

> If return code is non-zero, **abort immediately** and report index error.

### Step 3: Language Detection & Skill Routing

- Extract `primary_language` from the summary.
- Load the corresponding skill: `../skills/secreview/{language}/SKILL.md`.
- Load the per-language profile (dangerous API lists) using bash `cat` — avoid `read` tool which triggers OpenCode external dir permission prompts:
  ```bash
  LANG_PROFILE="$SECGUARDIAN_HOME/skills/secguard-<language>/references/language-features.md"
  [ -f "$LANG_PROFILE" ] && echo "=== Language Profile ===" && cat "$LANG_PROFILE"
  ```
- **Use index.json symbol table to locate review targets**, rather than traversing files.

<!-- @secguardian:non-skippable step=pre-filter -->
#### 3a. 检测器预筛（不可跳过 — 语言感知）
> 加载审阅规则前必须先经 index.json 信号门控。按语言类型采用不同策略。**`call_sites` 是 C/C++ 预筛的主要信号源，同时 `imports`/`string_literals`/`control_flow` 提供辅助信号。**

**C/C++（符号表精确匹配）：**
对 `skills/secreview/{lang}/rules/{lang}.md` 的审阅清单：
1. **读取目标函数/API**：rules 关联的目标函数名
2. **查 index.json.call_sites**：在 `call_sites` 中查询目标 API 是否被调用。`call_sites` 记录了每个危险 API（如 `strcpy`、`system`、`malloc`）的文件、行号和上下文，是预筛的主要信号来源。辅助信号：`imports` 检测依赖，`string_literals` 检测硬编码凭据，`control_flow` 检测守卫逻辑
3. **无匹配 → 跳过**：不加载规则全文，记录 "`Skipped: no matching call_site for {rule} in index.json`"
4. **有匹配 → 进入 3b**：规则强制加载后执行审阅

**Java / Python / Go / JS 等 OO 语言（全量加载）：**
> ⚠️ OO 语言中危险 API 是方法内调用，不在索引器符号表顶层。
> rules 每语言仅 1 个文件，全量加载成本极低。

1. 检查 `index.json` 中 `function_count > 0`
2. 有函数 → **必须加载该语言 rules 全文**（不允许 AI 自主裁定）
3. 无函数 → 跳过

#### 3b. 审阅规则强制加载（不可跳过）

> **核心契约**：审阅逻辑必须以 rules 文件内容为准，而非 AI 自身知识。
> 5 个语言的 rules 文件是唯一的审阅语义来源。跳过文件加载 = 忽略自定义审阅规则、检测模式更新、修复修正。
> **finding 的 `rationale`、`fix_before`/`fix_after` 必须引用规则文件原文，否则 finding 无效。**

<!-- @secguardian:non-skippable step=rule-loading -->

对预筛后有匹配的每个 review-rule，**必须**执行：

```bash
cat "$SECGUARDIAN_HOME/skills/secreview/{lang}/rules/{lang}.md"
```

然后：
1. 从规则文件提取审阅检查项、反模式列表、修复模式
2. 对照 index.json 符号表定位关联函数和文件
3. 读取目标函数代码（±10 行上下文），验证是否命中审阅条件
4. 记录 finding 时引用规则文件原文的检测逻辑和修复模式

> 🚫 **禁止行为**：
> - 不加载规则文件直接凭知识审阅
> - 仅列目录后臆测审阅规则内容
> - 用 `read` 工具读 `$SECGUARDIAN_HOME/knowledge/` 目录
> - 用 `grep`/`find` 取代 index.json 符号表定位

### Step 4: AI Security Code Review — Three Reasoning Dimensions

> The AI Agent performs three complementary reasoning passes. Each pass uses the index.json for structural context (symbols, call graph, alloc/free pairs, lock graph) and the skill file for language-specific review criteria.

**Pass A — Vulnerability Detection by Code Review**

For each function/symbol in the changeset (or full codebase), evaluate:

1. **Input trust boundaries** — Does user input cross into dangerous sinks (SQL, shell, file system, eval)?
2. **Authentication / authorization** — Are access control checks present and correct?
3. **Data flow analysis** — Does untrusted data reach sensitive operations without sanitization?
4. **Cryptography usage** — Are algorithms, key lengths, and RNGs appropriate?
5. **Error handling** — Do errors leak sensitive information? Are exceptional paths handled safely?
6. **Dependency / serialization** — Are third-party deserialization sources trusted?

Cite specific CWE IDs for each finding. Include an exploit scenario that explains how an attacker could leverage the defect.

**Pass B — Business Logic Security**

Evaluate the changes for business logic vulnerabilities:

1. **State manipulation** — Can an attacker transition the application to an invalid state?
2. **Privilege escalation** — Does the change allow accessing resources without proper authorization?
3. **Race conditions** — Are shared resources protected consistently (TOCTOU, async race)?
4. **Rate limiting / abuse** — Can the change be abused for denial of service?

**Pass C — Anti-pattern & Code Quality Review**

Evaluate against language-specific anti-patterns (from the skill file):

1. **Coding standard violations** — SEI CERT, OWASP, Go Security Guidelines, etc.
2. **Framework-specific anti-patterns** — Spring, Django, Express, React, etc.
3. **Common language pitfalls** — Type confusion, unsafe reflection, prototype pollution, etc.

> Findings from all three passes are consolidated into a single output. Each finding should reference which pass(es) identified it.

> ⚠️ **🚫 禁止将检测执行委托给子代理 (NON-NEGOTIABLE):**
> YOU are the detection engine. Your analysis (reading index.json symbols + loading detection rules from `skills/secguard/{lang}/rules/*/rule.md` + reading target functions) IS the scanner.
> - ❌ 不允许启动 background task / sub-agent 来执行检测器
> - ❌ 不允许用 grep/find 全文件扫描（必须通过 index.json 符号表定位目标函数）
> - ✅ 正确做法：在当前上下文中，逐一读取 detection rules（`rules/*/rule.md`）→ 查 index.json 符号表找到关联函数 → 读取该函数代码 → 应用检测逻辑 → 用 record-finding.py 记录 finding

> **自动跳过**: 如果 Step 4 (Pass A/B/C) 检出 0 个 finding，跳过 Step 5 渲染管线，直接输出 "✅ 安全审阅通过，未发现安全问题" 并结束。

### Step 5: Output Structured Findings (Findings Protocol v5.0)

> **v5.0**: Each finding is written as an individual file in the `findings/` directory tree. A lightweight `findings.json` is auto-generated by the renderer (not written by AI). The renderer aggregates via `--findings-dir`.

**5a. Output individual finding files:**

Each finding written to `<scan_dir>/findings/<detector>/<sha12>_<file_slug>-<line>.json`:

Each finding is recorded via `record-finding.py` (multi-path search).

> **🔗 锚定+证据约束 (engine_contract.md Rule A + Rule B):**
> - 每个 finding 的 `file`+`line` MUST 可追溯到 index.json 的符号或文件列表
> - MUST 提供 `--snippet`、`--code-context`、`--rationale`、`--attack-scenario`
> - MUST 传 `--index-json` 进行锚定校验
> - 无 index 锚点时 MUST 标记 `confidence: low`

```bash
# RECORDER/SCAN_DIR/SCAN_ID already loaded from .scan_state.secreview — no redundant assignment needed
# ⚠️ MUST use heredoc with --from-stdin. NEVER pass code as inline CLI args.
python3 "$RECORDER" \
    --command secreview \
    --scan-dir "$SCAN_DIR" \
    --from-stdin << 'RECEOF'
{
  "command": "secreview",
  "detector": "web.sql-injection",
  "severity": "High",
  "cwe": "CWE-089",
  "file": "src/service/UserService.java",
  "line": 89,
  "end_line": 92,
  "function": "findUser",
  "title": "Use PreparedStatement for parameterized query",
  "snippet": "String qry = \"SELECT * FROM users WHERE id=\" + userId;",
  "code_context": "public User findUser(String userId) { String qry = \"SELECT * FROM users WHERE id=\" + userId; return jdbcTemplate.query(qry, ...); }",
  "rationale": "String concatenation in SQL query — violates OWASP A03:2021",
  "attack_scenario": "Attacker provides userId=1 OR 1=1 to bypass auth",
  "cvss": 8.2,
  "fix_before": "String qry = \"SELECT * FROM users WHERE id=\" + userId;",
  "fix_after": "PreparedStatement ps = conn.prepareStatement(\"SELECT * FROM users WHERE id=?\"); ps.setInt(1, userId);",
  "review_pass": "vulnerability_detection",
  "review_focus": "input-validation,injection-prevention",
  "index_json": ".codeagent/secguardian/index.json"
}
RECEOF
```

Key requirements (secreview-specific):
- `detector` must use `namespace.name` format (e.g., `web.sql-injection`), consistent across all detection rules
- `evidence.judgment_rationale` must cite relevant security standards (SEI CERT / OWASP / Go Security Guidelines)
- `impact.attack_scenario` is **required** — describe a concrete way an attacker could exploit this
- `secreview_specific.review_pass` indicates which reasoning pass identified the finding
- **Must include** `file`, `line`, `location`, `impact`, `fix` fields

<!-- @secguardian:non-skippable step=validate -->
> **🚫 此验证步骤不可跳过。跳过验证不会加速检视——验证减低了误报，是报告前的强制性安全检查。**

**5b. Self-check + renderer auto-generates findings.json:**

**5b. Self-check + renderer auto-generates findings.json：**

```bash
SCAN_DIR=".codeagent/secguardian/secreview/scans/<scan_id>"
python3 "$SCRIPTS_DIR/validate-findings.py" --findings-dir "$SCAN_DIR/findings/" --check-spec
VALIDATE_EXIT=$?
if [ $VALIDATE_EXIT -eq 0 ]; then
    echo "  ✅ All findings pass validation + spec cross-check"
else
    echo "  ⚠️  Spec validation found violations — findings must be regenerated"
    echo "  AI must re-read review-rule Detection Spec and fix severity/CWE/evidence"
fi
```

**5c. Invoke renderer:**

```bash
python3 "$RENDERER" \
    --command secreview \
    --scan-id "$SCAN_ID" \
    --findings-dir <user-project>/.codeagent/secguardian/secreview/scans/<scan_id>/findings/ \
    --index <user-project>/.codeagent/secguardian/index.json \
    --output <user-project>/.codeagent/secguardian/secreview/scans/<scan_id>/
```

> ⚠️ If renderer unavailable: `"Renderer unavailable — findings saved to findings/ directory tree only."`

### Step 6: Output Review Summary（遵循统一 CLI 输出协议）

读取 `manifest.json` 获取统计，按 `knowledge/protocols/scan-output.md §CLI 输出摘要` 的统一格式输出。

**secreview 特有规则：**
- **统计表**：用 `项目 | 数值` 格式，内容包括文件审阅数、审阅维度（passes）、检出数
- **类别列**：填充审阅维度（如 `injection-prevention`）
- **0 发现 → 不出现发现表**

**0 发现（审阅通过）：**

```
## secreview 完成

Scan ID: pr-YYYYMMDD-HHMMSS-xxxx | Project: <project> | Path: <path> | Language: <lang> | Mode: <full | git diff>

### 扫描统计

| 项目 | 数值 |
|------|------|
| 文件审阅 | 3 |
| 审阅维度 | 3 passes |
| 检出 | 0 |

### 安全评分

**100/100 🟢 Grade A — 代码审查通过，未发现安全问题。**
```

**有发现（检出 > 0）：**

```
## secreview 完成

Scan ID: pr-YYYYMMDD-HHMMSS-xxxx | Project: <project> | Path: <path> | Language: <lang> | Mode: <full | git diff>

### 扫描统计

| 项目 | 数值 |
|------|------|
| 文件审阅 | 8 (4 changed + 4 context) |
| 审阅维度 | 3 passes |
| 检出 | 5 (Critical: 0, High: 2, Medium: 3) |

### 发现详情

| # | Severity | CWE | 类别 | 位置 | 摘要 |
|---|----------|-----|------|------|------|
| 1 | 🟠 High | CWE-089 | injection-prevention | src/UserService.java:89 | SQL injection via string concat |
| 2 | 🟠 High | CWE-807 | auth-bypass | src/AdminController.java:23 | Trust boundary violation |
| 3 | 🟡 Medium | CWE-532 | info-exposure | src/AuthHandler.java:156 | Sensitive data in log |

### 安全评分

**70/100 🟡 Grade B — 建议修复 High 后合并。**
```

