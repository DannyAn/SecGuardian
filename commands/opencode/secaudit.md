---
name: secaudit
description: "[OpenCode] AI Release Security Audit — 15-skill EPIC-3 architecture via Dispatcher protocol with 13 audit domains"
platform: opencode
---

# /secaudit - AI Release Security Audit

## ⚙️ Command Layer


针对安全专项问题进行深度审计分析。自动识别用户意图，路由到对应的分析或领域审计 skill。

## 使用方式

```

## 🛠️ Engine Layer

> 本命令的审计执行遵循 Investigation Engine 模式：索引 → 信号提取 → 审计域调查 → Evidence 收集 → 裁决。
> secaudit 的 13 个审计域等价于 Investigator 中的"调查方向"，各域有独立的 Evidence 收集指引。
> 详见 `secguard.md §Phase 2` 的 Hypothesis → Investigator → Judge 执行协议。
>
> 🚫 **不要使用 `todowrite` 工具。** 使用原生 task 系统（`TaskCreate` + `TaskUpdate`）追踪进度。
> `todowrite` 每次调用重传全部已完成项，每会话浪费 ≥50KB 无效 token。
>
> 🚫 **不要硬编码 `RECORDER` 路径。** 必须使用 `$SCRIPTS_DIR/record-finding.py`。
> 硬编码路径在安装位置变动时全断。
>
> 🚫 **禁止用 `read` 工具读取 `$SCRIPTS_DIR/` 下的脚本文件。** 所有脚本通过 `Bash` 工具执行，CLI 接口已在本模板中完整文档化。用 `read` 读取脚本文件触发 OpenCode 外部目录权限弹窗，且浪费 token。

## Audit Framework

安全规则统一存放在 `skills/secaudit/rules/` 中，AI Agent 按 workflow 加载对应域的知识文件进行检测。

审计规则统一存储在 `skills/secaudit/rules/` 中，AI Agent 按 workflow 加载对应域的知识文件进行检测。未来扩展（如 `owasp-asvs`、`pci-dss`）只需在 `knowledge/` 下新增规则目录。

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

**执行完毕后必须输出审计摘要，遵循 `knowledge/protocols/scan-output.md §CLI 输出摘要` 的统一格式。**

**secaudit 特有规则：**
- **统计表**：用 `项目 | 数值` 格式，内容包括扫描文件、分析路径数、检出数
- **类别列**：填充数据流路径简写（如 `HTTP param → SQL`）
- **0 发现 → 不出现发现表**

**0 发现（审计通过）：**

```
## secaudit 完成

Scan ID: sec-YYYYMMDD-HHMMSS-xxxx | Project: <project> | Path: <path> | Language: <lang> | Mode: <mode>

### 扫描统计

| 项目 | 数值 |
|------|------|
| 扫描文件 | 15 |
| 分析路径 | 15 |
| 检出 | 0 |

### 安全评分

**100/100 🟢 Grade A — 审计通过，未发现安全议题。**
```

**有发现（检出 > 0）：**

```
## secaudit 完成 — <domain>

Scan ID: sec-YYYYMMDD-HHMMSS-xxxx | Project: <project> | Path: <path> | Language: <lang> | Mode: <mode>

### 扫描统计

| 项目 | 数值 |
|------|------|
| 扫描文件 | 15 |
| 分析路径 | 15 |
| 检出 | 4 (Critical: 2, High: 2) |

### 发现详情

| # | Severity | CWE | 类别 | 位置 | 摘要 |
|---|----------|-----|------|------|------|
| 1 | 🔴 Critical | CWE-089 | HTTP param → SQL | src/handler.py:42 | SQL injection via string concat |
| 2 | 🔴 Critical | CWE-078 | File upload → system | src/upload.py:108 | OS command injection |
| 3 | 🟠 High | CWE-644 | Cookie → response | src/middleware.js:56 | XSS via unescaped cookie |

### 安全评分

**65/100 🟡 Grade C — 存在需关注的审计发现。**
```


> 本命令的审计执行遵循 Investigation Engine 模式：索引 → 信号提取 → 审计域调查 → Evidence 收集 → 裁决。
> secaudit 的 13 个审计域等价于 Investigator 中的"调查方向"，各域有独立的 Evidence 收集指引。
> 详见 `secguard.md §Phase 2` 的 Hypothesis → Investigator → Judge 执行协议。

## 可用审计域

**审计域**: `skills/secaudit/rules/`（13 个审计域，覆盖 OWASP ASVS + CWE Top 25）


## ⚠️ 上下文预算警告（OpenCode 核心约束）

> OpenCode 没有后台任务工具 —— 所有审计域在主会话中串行执行。
>
> **上下文预算规则：**
> 1. 每个审计域处理完后，检查上下文是否接近 70% 满载
> 2. 如果接近溢出：停止未处理的审计域，标记为 `unprocessed`
> 3. finding 录制：CLI 参数直调（不写文件、无文件操作）
> 4. **工具禁止：** 禁止 `Read` 工具读 `$SECGUARDIAN_HOME/` 下的文件（触发权限弹窗）。禁止 Glob/Grep 工具（结果进入上下文）。使用 bash `cat`/`grep`
>
> 详见 secguard.md `§5.1 Worker 启动协议` 的上下文预算细节（同样的串行约束适用于各审计域）。

## 派发规则与执行步骤

> **架构说明 (Signal Matrix — EPIC-007)**: SecGuardian 已将执行管线重构为 15 个聚焦的 C/C++ detection skills，通过统一的 Dispatcher 协议调度。
> securrity audit 使用**全部 7 信号类型** (S1–S7: call_sites, string_literals, declarations, value_constants, imports, config_patterns, control_flow) 进行版本发布级全域审计。
> 共享执行流程（初始化、索引、输出协议、摘要）定义在 `commands/secguard.md` Dispatcher 中。
> secaudit 在此框架上增加 13 个审计域的深度分析能力。secaudit 独有逻辑（审计域加载、域规则校验、四段式证据）保
> 留在本文件中；共享管线步骤遵循 Dispatcher 协议。

你（AI Agent）在接收到 `/secaudit` 命令后，必须按以下步骤执行来构建索引并进行安全审计。

### 前置检查（Pre-flight Checklist）

> ⛔ **禁止使用 Glob 或 Read 工具探索文件路径。** 已知路径的文件用 `cat` 读取（扩展目录下避免权限弹窗）。索引器已提供符号表+调用图，所有代码结构数据从 index.json 获取，无需 LSP/compile_commands.json。

执行审计前确认：

- [ ] 目标路径 `<path>` 存在且包含至少一个源码文件
- [ ] 不使用 clangd/LSP/bear 等外部工具
- [ ] `SECGUARDIAN_HOME`/健康检查/目录创建由 Step 1 的 `init-scan.sh` 统一处理

> 若未通过，报告具体失败项并终止。不要降级为手工审计。

---

<!-- @secguardian:ordering rule=scan_id FIRST -->
### Step 1: 初始化（唯一 bash 调用，使用共享 init-scan.sh）

> **唯一一次预初始化 bash 调用**。通过 `scripts/init-scan.sh` 完成 SECGUARDIAN_HOME 自动发现、健康检查、路径确认、建目录、写 `.scan_state.secaudit`。

```bash
source "$HOME/.config/opencode/extensions/secguardian/scripts/init-scan.sh" secaudit "<path>"
```

- 记录审计开始时间戳，用于 Step 4 计算 `duration_ms`。

### 🔒 跨 Shell 状态传递规则（Step 1 之后所有 bash 调用）

> **每个 bash 调用都是独立 shell，变量不共享。禁止用 `/tmp/` 或任何系统临时目录传状态。**

Step 1 已在 `.scan_state.secaudit` 中持久化 `SCAN_ID`、`SCAN_DIR`、`USER_PROJECT`、`SECGUARDIAN_HOME`、`RECORDER`。
从 Step 2 开始，**每个 bash 调用第一行必须是**：
```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secaudit"
```
此后 `$SCAN_DIR`、`$SCAN_ID`、`$USER_PROJECT`、`$SECGUARDIAN_HOME`、`$RECORDER` 在 bash 命令中才能正确展开。**禁止用 `cat /tmp/*.txt`**。
`/tmp/` 在 Windows 不可用、触发 macOS 确权弹窗、且多用户不安全。

> **📂 知识库读取**: 知识库文件存储在 `$SECGUARDIAN_HOME/knowledge/`，使用 bash `cat` 按需读取，不拷贝到项目目录。
> - 审计规则：`cat "$SECGUARDIAN_HOME/skills/secaudit/rules/{domain}.md"`
> - 检测规则（按需）：`cat "$SECGUARDIAN_HOME/skills/secguard/{lang}/rules/{rule}/rule.md"`
> - 协议文件：`cat "$SECGUARDIAN_HOME/knowledge/protocols/{name}.md"`
> - 禁止使用 `read` 工具读 `$SECGUARDIAN_HOME/knowledge/` 下的文件（触发 OpenCode 外部目录权限弹窗）。使用 bash `cat` 读取不会触发权限弹窗。

### Step 2: 构建语义索引（必须执行，不可跳过）

> ⚠️ 这是审计的**核心前置步骤**。索引器提供符号表、调用图、数据流路径，是后续深度审计的结构化上下文。**不执行此步骤将导致审计质量严重下降。**

**2a. 执行索引器（阻塞等待完成）：**
> 索引自动复用同路径缓存。加 `--force` 强制重建。

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

**2b. 验证索引完整性 + 生成结构化摘要（必须通过）：**

执行以下脚本。若返回非 0，**立即终止审计**并向用户报告索引生成出错。
若成功，直接读取输出的 JSON 摘要作为后续所有步骤的上下文，**禁止自己写 Python 或 shell 去重新解析 index.json**。

> ⚠️ 此脚本自动处理不同语言索引器输出差异，对 `None`/`null` 值安全。

```bash
python3 "$SCRIPTS_DIR/validate-index.py" \
    --index .codeagent/secguardian/index.json \
    --scan-id <scan_id>
```

### Step 3: 加载审计域规则并路由 Workflow

> 默认加载 `$SECGUARDIAN_HOME/skills/secaudit/rules/` 中的 13 个审计域规则，由 secaudit workflow 自动调度执行。

- **默认审计模式**: 加载 `skills/secaudit/SKILL.md` 作为执行引擎，各 phase 从 `$SECGUARDIAN_HOME/skills/secaudit/rules/` 加载对应的规则文件。
  - workflow 中定义的 phase 顺序
  - 后处理（去重、评分、分类、修复路线图）由 workflow 定义
- **单项聚焦**: `--focus <domain>` 时跳过不匹配的 phase，仅加载对应域的规则文件
> ⚠️ **🚫 禁止将检测执行委托给子代理 (NON-NEGOTIABLE):**
> YOU are the execution engine. 禁止启动 background task / sub-agent 执行检测器。
> 禁止用 grep/find 全文件扫描。必须通过 index.json 符号表定位目标函数。
> 
> 🚫 **HARD RULE: 禁止全文件 cat** — 每个源码读取必须 `cat $FILE | sed -n '±15p'` 限定行范围：
> ```bash
> # ✅ GOOD: cat "$SOURCE_DIR/src/file.py" | sed -n '25,55p'
> # ❌ BAD:  cat "$SOURCE_DIR/src/file.py"
> ```
> 全文件 cat 将数千行源码塞入上下文，迅速溢出。零容忍。

<!-- @secguardian:non-skippable step=pre-filter -->
#### 3.1 检测器预筛（不可跳过 — 语言感知）

> 加载审计域规则前，必须先经 index.json 信号门控。按语言类型采用不同策略。**`call_sites` 是 C/C++ 预筛的主要信号源，同时 `imports`/`string_literals`/`control_flow` 提供辅助信号。**

**C/C++（符号表精确匹配）：**
对审计清单中的每个域：
1. 读取该审计域关联的目标函数/API
2. 在 `index.json.call_sites` 中查询目标 API 是否被调用。`call_sites` 记录了每个危险 API（如 `strcpy`、`system`、`malloc`）的文件、行号和上下文，是预筛的主要信号来源。辅助信号：`imports` 检测依赖（如 `openssl`、`sqlite3`），`string_literals` 检测硬编码凭据
3. **无匹配 → 跳过**：不加载规则全文，记录 "`Skipped: no matching call_site for {domain} in index.json`"
4. **有匹配 → 进入 3.1a**：规则强制加载后执行审计

**Java / Python / Go / JS 等 OO 语言（全量加载）：**
> ⚠️ OO 语言中危险 API（如 `Runtime.exec()`）是方法内调用，不在索引器符号表顶层。
> 共 13 个 rules，全量加载成本极低。

1. 检查 `index.json` 中 `function_count > 0`
2. 有函数 → **必须加载所有审计域规则全文**（不允许 AI 自主裁定"哪些可能匹配"）
3. 无函数 → 跳过

#### 3.1a 审计规则强制加载（不可跳过）

> **核心契约**：审计逻辑必须以 rules 文件内容为准，而非 AI 自身知识。
> 13 个 rules 文件是唯一的审计语义来源。跳过文件加载 = 忽略自定义审计规则、分析方法更新、修复模式修正。
> **finding 的 `rationale`、`fix_before`/`fix_after` 必须引用规则文件原文，否则 finding 无效。**

<!-- @secguardian:non-skippable step=rule-loading -->

对预筛后有匹配的每个审计域，**必须**执行：

```bash
cat "$SECGUARDIAN_HOME/skills/secaudit/rules/{domain-name}.md"
```

然后：
1. 从规则文件提取审计检查项、分析方法、输出要求
2. 对照 index.json 符号表定位关联函数和文件
3. 读取目标函数代码（±10 行上下文），验证是否命中审计条件
4. 记录 finding 时引用规则文件原文的检测逻辑和修复模式

> 🚫 **禁止行为**：
> - 不加载规则文件直接凭知识审计
> - 仅列目录后臆测审计规则内容
> - 用 `read` 工具读 `$SECGUARDIAN_HOME/knowledge/` 目录
> - 用 `grep`/`find` 取代 index.json 符号表定位

### Step 4: 输出结构化 findings（Findings Protocol v5.0 — 文件优先版）

> **HARD RULE: 每个 finding 只允许一种记录方式。禁止混用。**
>
> **唯一方式**: CLI 参数直调 `record-finding.py`。
>
> **🚫 禁止以下方式:**
> - ✅ CLI 参数直调（推荐）
> - ❌ 直接 CLI `--detector --rationale "..."`: 长文本进上下文
> - ✅ 无文件、无 heredoc
>
> **幂等性**: `record-finding.py` 已内置 SHA 幂等守卫。相同 finding 的第二次写入会被 `IDEMPOTENT_SKIP` 跳过。

**4a. ⭐ 唯一 canonical 记录流程**

> **检测器名规范**: `audit.{domain-name}` 格式。例如 `audit.cryptography`、`audit.input-validation`、`audit.auth-and-session`。
> **禁止**裸名如 `cryptography`（SARIF 生成器会报 `IndexError`）。

```bash
# RECORDER/SCAN_DIR/SCAN_ID 已从 .scan_state.secaudit 加载，无需重复赋值
# ⚠️ CLI 方式：--detector --severity --file --line (puts finding data in context).
# Step A: write finding JSON via quoted heredoc << 'FEOF'
# ⚠️ Finding JSON MUST use nested schema:
#   location (file_path, start_line, snippet)
#   evidence (code_context, judgment_rationale)
#   impact (attack_scenario)
#   fix (before_code, after_code)
#   id (string) — required by render-report.py
# Step A: Write finding JSON silently (用 python3 -c 替代 cat > heredoc — 不回显 JSON 内容)
python3 -c "import json; json.dump(FINDING_DICT, open('$SCAN_DIR/findings/finding-{id}.json', 'w'))"

# Step: record finding (CLI 参数直调)
python3 "$RECORDER" --command secaudit --scan-dir "$SCAN_DIR" \
    --detector "audit.input-validation" --severity Critical --cwe CWE-89 \
    --file "src/webapp.py" --line 47 \
    --snippet "cursor.execute(query)" --code-context "SQL拼接" \
    --rationale "未参数化，OWASP A03:2021" --attack-scenario "SQL注入"
```

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
python3 "$SCRIPTS_DIR/validate-findings.py" --findings-dir "$SCAN_DIR/findings/"
VALIDATE_EXIT=$?
if [ $VALIDATE_EXIT -eq 0 ]; then
    echo "  ✅ All findings pass validation + spec cross-check"
else
    echo "  ⚠️  Spec validation found violations — findings must be regenerated"
    echo "  AI must re-read audit-rule Detection Spec and fix severity/CWE/evidence"
fi
```

> Spec 校验是强约束：finding 的 severity、CWE、evidence 必须匹配 Detection Spec（即 audit-rule 文件内容）。跳过规则文件加载的 finding 将被拒绝。

**4c. 调用渲染器生成所有输出：**

```bash
# 定位渲染器（同 secguard）
RENDERER="$SCRIPTS_DIR/render-report.py"

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

