---
name: secaudit
description: "AI Release Security Audit — 17-domain audit framework with knowledge-driven detection"
---

# /secaudit - AI Release Security Audit

## ⚙️ Command Layer


针对安全专项问题进行深度审计分析。自动识别用户意图，路由到对应的分析或领域审计 skill。

## 使用方式

```

## 🛠️ Engine Layer

> 以下内容属于 Engine 职责（参见 `internal/engine/engine_contract.md`）。当前由 LLM prompt 代行执行。未来 Engine 实现后，此处内容将被 Engine 取代。
>
> 🚫 **不要使用 `todowrite` 工具。** 使用原生 task 系统（`TaskCreate` + `TaskUpdate`）追踪进度。
> `todowrite` 每次调用重传全部已完成项，每会话浪费 ≥50KB 无效 token。
>
> 🚫 **不要硬编码 `RECORDER` 路径。** 必须使用 `$SECGUARDIAN_HOME/scripts/record-finding.py`。
> 硬编码路径在安装位置变动时全断。
>
> 🚫 **禁止用 `read` 工具读取 `$SECGUARDIAN_HOME/scripts/` 下的脚本文件。** 所有脚本通过 `Bash` 工具执行，CLI 接口已在本模板中完整文档化。用 `read` 读取脚本文件触发 OpenCode 外部目录权限弹窗，且浪费 token。

## Audit Framework

安全规则统一存放在 `knowledge/audit-rules/` 中，AI Agent 按 workflow 加载对应域的知识文件进行检测。

审计规则统一存储在 `knowledge/audit-rules/` 中，AI Agent 按 workflow 加载对应域的知识文件进行检测。未来扩展（如 `owasp-asvs`、`pci-dss`）只需在 `knowledge/` 下新增规则目录。

## 使用方式

```
# ★ 零参数缺省调用（推荐）
/secaudit                                            # 扫描当前目录，自动检测语言，执行全量审计

# 显式指定路径和语言
/secaudit ./src python                              # Python 完整安全审计
/secaudit ./src java                                # Java 完整安全审计
/secaudit ./src cpp                                 # C/C++ 完整安全审计
# 单项聚焦审计
/secaudit --focus cryptography                      # 零参数 + 单项聚焦
/secaudit ./src python --focus input-validation     # 单项：仅输入验证审计
/secaudit ./src python --focus data-protection      # 单项：仅数据保护审计

# SARIF 输出
/secaudit ./src python --sarif                      # 输出 SARIF 格式（CI/CD）
```

## 📄 Output Layer

> 以下输出格式遵循 `internal/output/output_contract.md`。

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
.codeagent/secguardian/secaudit/scans/<scan-id>/
├── report.md               # ★ 人读审计报告 (Markdown)
├── results.sarif            # 机读: SARIF 2.1.0 (CI/CD)
├── summary.json             # 仪表盘统计
├── manifest.json            # 审计元数据 + 发现索引
├── status.json              # CI 门禁
└── delta.json               # 增量对比 (vs 上次扫描)
```

**执行完毕后必须输出审计摘要：**

```
## secaudit 审计完成 — input-validation

Scan ID: sec-20260523-143000-b3c4
Project: <project-name>
Workspace: <user-project>
Skill: aud-input-validation

### 结果
- 分析路径: 15 (Source → Propagation → Sink)
- 完整链路: 15 analyzed
- 检出: 4 (Critical: 2, High: 2)

### 发现
| ID | Severity | Path | File |
|----|----------|------|------|
| C-001 | Critical | HTTP param → SQL exec | src/handler.py:42 |
| C-002 | Critical | File upload → os.system | src/upload.py:108 |
| H-001 | High | Cookie → response.write | src/middleware.js:56 |

输出目录: .codeagent/secguardian/secaudit/scans/sec-20260523-143000-b3c4/

💡 **如何使用审计结果？**
- **快速看汇总** → 打开 `manifest.json`
- **★ 人读审计报告** → 打开 `report.md`（每个发现含完整四段式：📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix）
- **CI/CD 集成** → 消费 `results.sarif`
- **🤖 AI Agent 修复** → 读取 `ai/remediation-pack.json` 自动修复：`读取 report.md §4，按每个发现的 🔧 Fix 方案修改代码`
```


> 以下内容属于 Engine 职责（参见 `internal/engine/engine_contract.md`）。当前由 LLM prompt 代行执行。未来 Engine 实现后，此处内容将被 Engine 取代。

## 可用审计域

**审计域**: `knowledge/audit-rules/`（13 个审计域，覆盖 OWASP ASVS + CWE Top 25）


## 派发规则与执行步骤

你（AI Agent）在接收到 `/secaudit` 命令后，必须按以下步骤执行来构建索引并进行安全审计。

### 前置检查（Pre-flight Checklist）

# ── Resolve SECGUARDIAN_HOME ─────────────────
if [ -z "$SECGUARDIAN_HOME" ] || [ ! -d "$SECGUARDIAN_HOME/scripts" ]; then
    for _sg_root in "$HOME/.claude/plugins/secguardian" \
                    "$HOME/.config/opencode/extensions/secguardian" \
                    "$HOME/.gemini/extensions/secguardian" \
                    "/root/.config/opencode/extensions/secguardian"; do
        if [ -f "$_sg_root/scripts/record-finding.py" ]; then
            export SECGUARDIAN_HOME="$_sg_root"
            break
        fi
    done
fi
if [ -z "$SECGUARDIAN_HOME" ] || [ ! -d "$SECGUARDIAN_HOME/scripts" ]; then
    echo "FATAL: Cannot locate secguardian installation"
    exit 1
fi

> ⛔ **禁止使用 Glob 或 Read 工具探索文件路径（搜索文件）。已知路径的文件可以用 `cat` 或 `head` 读取（扩展目录下的文件不用 Read 工具，避免权限弹窗）**。所有路径检测必须通过 bash 命令（`[ -f ]`、`ls`）完成。先跑 `find_indexer` 再跑 `--health`。

在执行任何审计步骤之前，必须逐项确认以下所有条件。**任一项未通过，审计不得开始，向用户报告具体错误。**

- [ ] 定位索引器：由 `SECGUARDIAN_HOME` env var 或 `.secguardian-env` 文件确定路径，无需多平台搜索
- [ ] 执行 `{indexer} --health` 通过（输出必须包含 `HEALTH:OK` 或 `HEALTH:WARN`，不接受 `HEALTH:FAIL`）
- [ ] 目标路径 `<path>` 存在且包含至少一个源码文件
- [ ] 确认不会启动 clangd/LSP/compile_commands.json/bear 等外部工具 — indexer (tree-sitter) 已提供符号表+调用图+文件清单，所有代码结构数据从 index.json 获取

> 若未通过，报告具体哪一项失败并终止。不要降级为手工逐文件审计。

---

### Step 1: 初始化（唯一 bash 调用，禁止拆分）

> ⚠️ 这是**唯一一次预初始化 bash 调用**，必须一次性完成：自动发现 → 健康检查 → 路径确认 → 建目录 → 写入 `.scan_state.secaudit`。
> **禁止**在 Step 1 前后插入任何独立的 bash 命令（如 `ls "$SECGUARDIAN_HOME/scripts/"`）— 那会在新 shell 中丢失变量且无意义。
> `$SECGUARDIAN_HOME/scripts/` 已在自动发现中验明存在，无需冗余 `ls` 确认。

- **⏳ 首选生成 scan_id**（格式: `sec-YYYYMMDD-HHMMSS-xxxx`，`xxxx` 为随机4位字符）。
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
    exit 1
fi

# ===== 阶段 B: 索引器健康检查 =====
if ! "$SECGUARDIAN_HOME/scripts/secguardian-index" --health; then
    echo "FATAL: secguardian-index health check failed"
    exit 1
fi

# ===== 阶段 C: 扫描路径确认 =====
test -d "<path>" || { echo "FATAL: scan path <path> not found"; exit 1; }

# ===== 阶段 D: 创建扫描目录 =====
SCAN_ID="sec-$(date +%Y%m%d-%H%M%S)-$(openssl rand -hex 2)"
SCAN_DIR="$USER_PROJECT/.codeagent/secguardian/secaudit/scans/$SCAN_ID"
mkdir -p "$SCAN_DIR"

# ===== 阶段 E: 持久化状态到 .scan_state.secaudit =====
cat > ".codeagent/secguardian/.scan_state.secaudit" << STATEEOF
USER_PROJECT="$USER_PROJECT"
SCAN_ID="$SCAN_ID"
SCAN_DIR="$SCAN_DIR"
SECGUARDIAN_HOME="$SECGUARDIAN_HOME"
RECORDER="$SECGUARDIAN_HOME/scripts/record-finding.py"
STATEEOF
echo "SCAN_DIR=$SCAN_DIR"
```

- 记录审计开始时间戳，用于 Step 4 计算 `duration_ms`。

### 🔒 跨 Shell 状态传递规则（Step 1 之后所有 bash 调用）

> **每个 bash 调用都是独立 shell，变量不共享。禁止用 `/tmp/` 或任何系统临时目录传状态。**

Step 1 已在 `.scan_state.secaudit` 中持久化 `SCAN_ID`、`SCAN_DIR`、`USER_PROJECT`、`SECGUARDIAN_HOME`、`RECORDER`。
从 Step 2 开始，**每个 bash 调用第一行必须是**：
```bash
source .codeagent/secguardian/.scan_state.secaudit
```
此后 `$SCAN_DIR`、`$SCAN_ID`、`$USER_PROJECT`、`$SECGUARDIAN_HOME`、`$RECORDER` 均可直接使用。**禁止用 `cat /tmp/*.txt`**。
`/tmp/` 在 Windows 不可用、触发 macOS 确权弹窗、且多用户不安全。

> **📂 知识库读取**: 知识库文件存储在 `$SECGUARDIAN_HOME/knowledge/`，使用 bash `cat` 按需读取，不拷贝到项目目录。
> - 审计规则：`cat "$SECGUARDIAN_HOME/knowledge/audit-rules/{domain}.md"`
> - language-index：`cat "$SECGUARDIAN_HOME/knowledge/language-index.md"`
> - 协议文件：`cat "$SECGUARDIAN_HOME/knowledge/protocols/{name}.md"`
> - 禁止使用 `read` 工具读 `$SECGUARDIAN_HOME/knowledge/` 下的文件（触发 OpenCode 外部目录权限弹窗）。使用 bash `cat` 读取不会触发权限弹窗。

### Step 2: 构建语义索引（必须执行，不可跳过）

> ⚠️ 这是审计的**核心前置步骤**。索引器提供符号表、调用图、数据流路径，是后续深度审计的结构化上下文。**不执行此步骤将导致审计质量严重下降。**

**2a. 执行索引器（阻塞等待完成）：**
> 索引自动复用同路径缓存。加 `--force` 强制重建。

```bash
# 定位 indexer wrapper — 项目级 + 用户级全覆盖
INDEXER="$SECGUARDIAN_HOME/scripts/secguardian-index"
if [ ! -f "$INDEXER" ]; then
    echo "FATAL: secguardian-index not found at $INDEXER"
    exit 1
fi
echo "Using: $INDEXER"
# 超时保护: timeout 30s，防止索引器挂死。macOS 需要 brew install coreutils。
if command -v timeout &>/dev/null; then
    timeout 30 "$INDEXER" --path <path> --output <user-project>/.codeagent/secguardian/index.json || {
        echo "FAIL: Indexer timed out after 30s or failed — cannot continue"
        echo "  macOS: brew install coreutils  (provides 'timeout' command)"
        exit 1
    }
elif command -v gtimeout &>/dev/null; then
    gtimeout 30 "$INDEXER" --path <path> --output <user-project>/.codeagent/secguardian/index.json || {
        echo "FAIL: Indexer timed out after 30s or failed — cannot continue"
        exit 1
    }
else
    echo "WARNING: 'timeout' not found — indexer runs without timeout protection"
    echo "  Install coreutils: brew install coreutils (macOS) or apt install coreutils (Linux)"
    "$INDEXER" --path <path> --output <user-project>/.codeagent/secguardian/index.json
fi
if [ ! -f "<user-project>/.codeagent/secguardian/index.json" ]; then
    echo "FATAL: Indexer failed — cannot continue"
    exit 1
fi
```

**2b. 验证索引完整性 + 生成结构化摘要（必须通过）：**

执行以下脚本。若返回非 0，**立即终止审计**并向用户报告索引生成出错。
若成功，直接读取输出的 JSON 摘要作为后续所有步骤的上下文，**禁止自己写 Python 或 shell 去重新解析 index.json**。

> ⚠️ 此脚本自动处理不同语言索引器输出差异，对 `None`/`null` 值安全。

```bash
python3 "$SECGUARDIAN_HOME/scripts/validate-index.py" \
    --index .codeagent/secguardian/index.json \
    --scan-id <scan_id>
```

### Step 3: 加载审计域规则并路由 Workflow

> 默认加载 `$SECGUARDIAN_HOME/knowledge/audit-rules/` 中的 13 个审计域规则，由 secaudit workflow 自动调度执行。

- **默认审计模式**: 加载 `skills/secaudit/SKILL.md` 作为执行引擎，各 phase 从 `$SECGUARDIAN_HOME/knowledge/audit-rules/` 加载对应的规则文件。
  - workflow 中定义的 phase 顺序
  - 后处理（去重、评分、分类、修复路线图）由 workflow 定义
- **单项聚焦**: `--focus <domain>` 时跳过不匹配的 phase，仅加载对应域的规则文件
> ⚠️ **🚫 禁止将检测执行委托给子代理 (NON-NEGOTIABLE):**
> YOU are the execution engine. 禁止启动 background task / sub-agent 执行检测器。
> 禁止用 grep/find 全文件扫描。必须通过 index.json 符号表定位目标函数。

<!-- @secguardian:non-skippable step=pre-filter -->
#### 3.1 检测器预筛（不可跳过）

> 加载审计域规则前，必须先经 index.json 符号表门控。

对审计清单中的每个域：
1. 读取该审计域关联的目标函数/API
2. 在 `index.json.symbols.functions` 中查询目标是否存在
3. **无匹配 → 跳过**：不加载规则全文，记录 "`Skipped: no matching symbol for {domain} in index.json`"
4. **有匹配 → 加载规则**：进入 Step 3 加载规则全文后执行审计

### Step 4: 输出结构化 findings（遵循 Findings Protocol v5.0）

> **v6.0**: secaudit 命令同样适用三轮验证管道（`commands/secguard.md` Step 3.5）。`--no-verify` 跳过验证。
> **自动跳过**: 如果审计产出 0 个 finding，不执行验证管道（标注 `skipped_by_zero_findings`），直接进入渲染。
> ⚠️ **v5.0 关键变更**: AI **不再输出单体 findings.json**。改为按 detector 分类，**每个 finding 输出一个独立文件**到 `findings/` 目录树下。`findings.json` 由渲染器自动生成（不含四段式，仅元数据+索引）。AI 只负责通过 `record-finding.py` 录制独立 finding 文件，渲染器调用时自动聚合 `findings_index`。渲染器通过 `--findings-dir` 聚合所有 finding 文件生成报告。**禁止直接写 report.md / results.sarif / 任何其他输出文件**。

**4a. 按 detector 分组，以 SHA 前缀为文件名逐文件输出：**

> **重要: detector 命名约定** — 每个 finding 的 `detector` 字段必须使用 `audit.{skill-name}` 格式，
> 例如 `audit.cryptography`、`audit.input-validation`、`audit.auth-and-session`。
> 不得使用裸名 (如 `cryptography`)，否则 SARIF 生成器会报 `IndexError`。

每个 finding 写入独立文件，路径格式如 secguard Step 4a（见 `commands/secguard.md`），额外包含 `secaudit_specific` 字段：
每个 finding 写入独立文件，路径格式如 secguard Step 4a，额外包含 `secaudit_specific` 字段。
使用 `record-finding.py`（通过多路径搜索定位）记录每个 finding，无需手写 JSON：

> **🔗 锚定+证据约束 (engine_contract.md Rule A + Rule B):**
> - 每个 finding 的 `file`+`line` MUST 可追溯到 index.json 的符号或文件列表
> - MUST 提供 `--snippet`、`--code-context`、`--rationale`、`--attack-scenario`
> - MUST 传 `--index-json` 进行锚定校验

```bash
# RECORDER/SCAN_DIR/SCAN_ID 已从 .scan_state 加载，无需重复赋值
# ⚠️ MUST use heredoc with --from-stdin. NEVER pass code as inline CLI args.
python3 "$RECORDER" \
    --command secaudit \
    --scan-dir "$SCAN_DIR" \
    --from-stdin << 'RECEOF'
{
  "command": "secaudit",
  "detector": "audit.input-validation",
  "severity": "Critical",
  "cwe": "CWE-89",
  "file": "src/webapp.py",
  "line": 47,
  "end_line": 48,
  "function": "get_user",
  "title": "使用参数化查询替代 f-string",
  "snippet": "cursor.execute(\"SELECT * FROM users WHERE id = ?\")",
  "code_context": "def get_user(user_id):\n    cursor.execute(f\"SELECT * FROM users WHERE id = {user_id}\")",
  "rationale": "用户输入直接拼接 SQL — 违反 OWASP Top 10 A03:2021",
  "attack_scenario": "攻击者通过 SQL 注入窃取所有用户数据",
  "data_flow_path": "HTTP param → get_user() → f-string → cursor.execute",
  "cvss": 9.8,
  "fix_before": "cursor.execute(f\"SELECT * FROM users WHERE id = {user_id}\")",
  "fix_after": "cursor.execute(\"SELECT * FROM users WHERE id = ?\", (user_id,))",
  "skill_name": "input-validation",
  "skill_category": "domain",
  "analysis_paths": 15,
  "complete_chains": 4,
  "index_json": ".codeagent/secguardian/index.json"
}
RECEOF
```

输出：`findings/<ns>/<detector>/<sha12>_<file>-<line>.json`
> ⚠️ Shell 安全：当 fix 代码含 `"` `'` `;` 或路径字符（如 `/etc/`）时，
> 先用 heredoc 写入文件再传 `--fix-before-file` / `--fix-after-file`：
> ```bash
> cat > "$SCAN_DIR/fix_before.txt" << 'EOF'
> String query = "SELECT * FROM users WHERE id = " + input;
> EOF
> python3 "$RECORDER" --command secguard --detector web.sql-injection \
>     --fix-before-file "$SCAN_DIR/fix_before.txt" --fix-after-file "$SCAN_DIR/fix_after.txt"
> ```

关键要求（secaudit 独有）：
- **必须包含** `file`、`line`、`location`、`evidence`、`impact`、`fix` 字段（与 secguard 格式一致）。
  仅提供 `secaudit_specific` 会导致渲染器 `KeyError`。
- `evidence.data_flow_path` 必须包含完整的 Source → Propagation → Sink 路径（至少 3 个步骤）
- `secaudit_specific.skill_name` — 本次审计的 skill 名称
- `secaudit_specific.analysis_paths` / `complete_chains` — 数据流分析统计

<!-- @secguardian:non-skippable step=validate -->
> **🚫 此验证步骤不可跳过。跳过验证不会加速审计——验证减低了误报，是报告前的强制性安全检查。**

**4b. 自检完整性 + 渲染器自动生成 findings.json：**

对所有 finding 执行前置校验。校验发现的问题会用警告列出。

```bash
SCAN_DIR=".codeagent/secguardian/secaudit/scans/<scan_id>"
python3 "$SECGUARDIAN_HOME/scripts/validate-findings.py" --findings-dir "$SCAN_DIR/findings/"
VALIDATE_EXIT=$?
if [ $VALIDATE_EXIT -ne 0 ]; then
    echo "  ⚠️  Findings validation completed with warnings — proceeding to renderer"
fi
```

> 校验结果不阻塞渲染。validate-findings.py 的警告项可通过后续手动检查确认。

**4c. 调用渲染器生成所有输出：**

```bash
# 定位渲染器（同 secguard）
RENDERER="$SECGUARDIAN_HOME/scripts/render-report.py"

python3 "$RENDERER" \
    --command secaudit \
    --scan-id "$SCAN_ID" \
    --findings-dir .codeagent/secguardian/secaudit/scans/<scan_id>/findings/ \
    --index .codeagent/secguardian/index.json \
    --output .codeagent/secguardian/secaudit/scans/<scan_id>/
```

> 渲染器.*⚠️。
> ⚠️ 如果渲染器不存在或执行失败，打印警告：`"Renderer unavailable — findings saved to findings/ directory tree only."`

### Step 5: 输出审计摘要

- 渲染器执行完毕后，读取 `manifest.json` 获取审计统计。
- 向用户输出 Markdown 格式的审计摘要，包含：scan_id、skill_name、检出总数、按严重度分组、Top 5 key findings。
- 如果 quality gate 未通过，明确列出不完整的 finding ID。
  不影响示例代码在测试环境中的使用。"

## secaudit 审计完成

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

