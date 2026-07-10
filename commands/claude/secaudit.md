---
name: secaudit
description: "[Claude Code] AI Release Security Audit — 15-skill EPIC-3 architecture via Dispatcher protocol with 13 audit domains"
platform: claude
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
source "$HOME/.claude/plugins/secguardian/scripts/init-scan.sh" secaudit "<path>"
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
> - 审计规则：`cat "$SECGUARDIAN_HOME/skills/secaudit/rules/{finding JSON written to file first}
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

