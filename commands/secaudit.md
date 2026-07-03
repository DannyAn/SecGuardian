---
name: secaudit
description: "AI Release Security Audit — 17-domain audit framework with knowledge-driven detection"
---

# /secaudit - AI Release Security Audit

针对安全专项问题进行深度审计分析。自动识别用户意图，路由到对应的分析或领域审计 skill。

## 使用方式

```
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
.codeagent/secaudit-secguardian/scans/<scan-id>/
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

输出目录: .codeagent/secaudit-secguardian/scans/sec-20260523-143000-b3c4/

💡 **如何使用审计结果？**
- **快速看汇总** → 打开 `manifest.json`
- **★ 人读审计报告** → 打开 `report.md`（每个发现含完整四段式：📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix）
- **CI/CD 集成** → 消费 `results.sarif`
- **🤖 AI Agent 修复** → 读取 `ai/remediation-pack.json` 自动修复：`读取 report.md §4，按每个发现的 🔧 Fix 方案修改代码`
```

## 可用审计域

**审计域**: `knowledge/audit-rules/`（13 个审计域，覆盖 OWASP ASVS + CWE Top 25）


## 派发规则与执行步骤

你（AI Agent）在接收到 `/secaudit` 命令后，必须按以下步骤执行来构建索引并进行安全审计。

### 前置检查（Pre-flight Checklist）
> ⛔ **禁止使用 Glob 或 Read 工具探索文件路径**。所有路径检测必须通过 bash 命令（`[ -f ]`、`ls`）完成。先跑 `find_indexer` 再跑 `--health`。

在执行任何审计步骤之前，必须逐项确认以下所有条件。**任一项未通过，审计不得开始，向用户报告具体错误。**

- [ ] 定位索引器 wrapper：检查 `.opencode/extensions/secguardian/`（项目级）→ `~/.config/opencode/extensions/secguardian/`（用户级）→ `.gemini/` → `.claude/` → `scripts/` 回退（至少一个存在且可执行）
- [ ] 执行 `{indexer} --health` 通过（输出必须包含 `HEALTH:OK` 或 `HEALTH:WARN`，不接受 `HEALTH:FAIL`）
- [ ] 目标路径 `<path>` 存在且包含至少一个源码文件
- [ ] 确认不会启动 clangd/LSP/compile_commands.json/bear 等外部工具 — indexer (tree-sitter) 已提供符号表+调用图+文件清单，所有代码结构数据从 index.json 获取

> 若未通过，报告具体哪一项失败并终止。不要降级为手工逐文件审计。

---

### Step 1: 建立输出目录

- **⏳ 首选生成 scan_id**（格式: `sec-YYYYMMDD-HHMMSS-xxxx`，`xxxx` 为随机4位字符）。
- **scan_id 一旦生成，后续所有路径必须使用此 scan_id。**
- 创建输出目录: `.codeagent/secaudit-secguardian/scans/<scan_id>/`。
- 记录审计开始时间戳，用于 Step 4 计算 `duration_ms`。

### Step 2: 构建语义索引（必须执行，不可跳过）

> ⚠️ 这是审计的**核心前置步骤**。索引器提供符号表、调用图、数据流路径，是后续深度审计的结构化上下文。**不执行此步骤将导致审计质量严重下降。**

**2a. 执行索引器（阻塞等待完成）：**

```bash
# 定位 indexer wrapper — 项目级 + 用户级全覆盖
find_indexer() {
    INDEXER=""
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
    for candidate in scripts/secguardian-index internal/secguardian-index; do
        [ -x "$candidate" ] && [ -f "$candidate" ] && INDEXER="$candidate" && break
    done
    [ -z "$INDEXER" ] && echo "FATAL: secguardian-index not found (checked project + user paths)" && exit 1
    echo "Using: $INDEXER"
}
find_indexer
# 缓存由 wrapper (scripts/secguardian-index) 透明处理：同路径复用 index.json
$INDEXER --path <path> --output <user-project>/.codeagent/secaudit-secguardian/scans/<scan_id>/index.json
if [ ! -f "<user-project>/.codeagent/secaudit-secguardian/scans/<scan_id>/index.json" ]; then
    echo "FATAL: Indexer failed — cannot continue"
    exit 1
fi
```

**2b. 验证索引完整性 + 生成结构化摘要（必须通过）：**

执行以下脚本。若返回非 0，**立即终止审计**并向用户报告索引生成出错。
若成功，直接读取输出的 JSON 摘要作为后续所有步骤的上下文，**禁止自己写 Python 或 shell 去重新解析 index.json**。

> ⚠️ 此脚本自动处理不同语言索引器输出差异，对 `None`/`null` 值安全。

```bash
python3 scripts/validate-index.py \
    --index .codeagent/secaudit-secguardian/scans/<scan_id>/index.json \
    --scan-id <scan_id>
```

### Step 3: 加载审计域规则并路由 Workflow

> 默认加载 `knowledge/audit-rules/` 中的 13 个审计域规则，由 secaudit workflow 自动调度执行。

- **默认审计模式**: 加载 `skills/secaudit/SKILL.md` 作为执行引擎，各 phase 从 `knowledge/audit-rules/` 加载对应的规则文件。
  - workflow 中定义的 phase 顺序
  - 后处理（去重、评分、分类、修复路线图）由 workflow 定义
- **单项聚焦**: `--focus <domain>` 时跳过不匹配的 phase，仅加载对应域的规则文件
### Step 4: 输出结构化 findings（遵循 Findings Protocol v5.0）

> **v6.0**: secaudit 命令同样适用三轮验证管道（`commands/secguard.md` Step 3.5）。`--no-verify` 跳过验证。
> ⚠️ **v5.0 关键变更**: AI **不再输出单体 findings.json**。改为按 detector 分类，**每个 finding 输出一个独立文件**到 `findings/` 目录树下。最后输出轻量 `findings.json`（同名升级，不含四段式，仅元数据+索引）。渲染器通过 `--findings-dir` 聚合所有 finding 文件生成报告。**禁止直接写 report.md / results.sarif / 任何其他输出文件**。

**4a. 按 detector 分组，以 SHA 前缀为文件名逐文件输出：**

> **重要: detector 命名约定** — 每个 finding 的 `detector` 字段必须使用 `audit.{skill-name}` 格式，
> 例如 `audit.cryptography`、`audit.input-validation`、`audit.auth-and-session`。
> 不得使用裸名 (如 `cryptography`)，否则 SARIF 生成器会报 `IndexError`。

每个 finding 写入独立文件，路径格式如 secguard Step 4a（见 `commands/secguard.md`），额外包含 `secaudit_specific` 字段：

```json
{
  "schema_version": "1.0",
  "finding": {
    # no "id" field — identity is SHA-256(detector:file:line:cwe)
    "severity": "Critical",
    "cwe": "CWE-89",
    "detector": "audit.input-validation",
    "file": "src/webapp.py",
    "line": 47,
    "location": {
      "file_path": "src/webapp.py",
      "start_line": 47,
      "end_line": 48,
      "function_name": "get_user",
      "snippet": "cursor.execute(f\"SELECT * FROM users WHERE id = {user_id}\")"
    },
    "evidence": {
      "code_context": "cursor.execute(f\"...{user_id}...")",
      "judgment_rationale": "用户输入直接拼接 SQL — 违反 OWASP Top 10 A03:2021",
      "data_flow_path": "HTTP param → get_user() → f-string → cursor.execute"
    },
    "impact": {
      "attack_scenario": "攻击者通过 SQL 注入窃取所有用户数据",
      "cvss_score": 9.8
    },
    "fix": {
      "description": "使用参数化查询替代 f-string",
      "before_code": "cursor.execute(f\"SELECT * FROM users WHERE id = {user_id}\")",
      "after_code": "cursor.execute(\"SELECT * FROM users WHERE id = ?\", (user_id,))"
    },
    "secaudit_specific": {
      "skill_name": "input-validation",
      "skill_category": "domain",
      "analysis_paths": 15,
      "complete_chains": 4
    }
  }
}
```

关键要求（secaudit 独有）：
- **必须包含** `file`、`line`、`location`、`evidence`、`impact`、`fix` 字段（与 secguard 格式一致）。
  仅提供 `secaudit_specific` 会导致渲染器 `KeyError`。
- `evidence.data_flow_path` 必须包含完整的 Source → Propagation → Sink 路径（至少 3 个步骤）
- `secaudit_specific.skill_name` — 本次审计的 skill 名称
- `secaudit_specific.analysis_paths` / `complete_chains` — 数据流分析统计

**4b. 输出轻量 `findings.json` + 自检完整性：**

同 secguard Step 4b-4c（见 `commands/secguard.md`）。路径使用 `secaudit-secguardian`。

**4c. 调用渲染器生成所有输出：**

```bash
# 定位渲染器（同 secguard）
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
[ -z "$RENDERER" ] && [ -f "scripts/render-report.py" ] && RENDERER="scripts/render-report.py"

python3 "$RENDERER" \
    --command secaudit \
    --findings-dir .codeagent/secaudit-secguardian/scans/<scan_id>/findings/ \
    --index .codeagent/secaudit-secguardian/scans/<scan_id>/index.json \
    --output .codeagent/secaudit-secguardian/scans/<scan_id>/
```

> 渲染器自动执行 secaudit 质量门禁，未通过的 finding 会在 report.md 中标记 ⚠️。

> ⚠️ 如果渲染器不存在或执行失败，打印警告：`"Renderer unavailable — findings saved to findings/ directory tree only."`

### Step 5: 输出审计摘要

- 渲染器执行完毕后，读取 `manifest.json` 获取审计统计。
- 向用户输出 Markdown 格式的审计摘要，包含：scan_id、skill_name、检出总数、按严重度分组、Top 5 key findings。
- 如果 quality gate 未通过，明确列出不完整的 finding ID。
- **样例代码检测**: 如果 `<path>` 中包含 `examples/`（样例/测试代码目录），在摘要末尾追加提示：
  "目标路径包含样例/测试代码（examples/），检测到的漏洞是预置的预期结果。
  CI 门禁的零容忍阈值（Critical=0, High=0）是为生产代码设计的，
  不影响示例代码在测试环境中的使用。"
