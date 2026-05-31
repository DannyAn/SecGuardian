---
category: protocol
version: "2.0"
type: report-template
---

# SecGuardian 安全扫描报告模板 (v2.0)

AI Agent 执行扫描后，按此模板生成 `report.md`。模板变量用 `{{VARIABLE}}` 标记。

---

```markdown
# {{EXTENSION_NAME}} 安全扫描报告

> **Scan ID**: `{{SCAN_ID}}` | **命令**: `/{{COMMAND}}` | **日期**: {{DATE}}
> **路径**: `{{SCOPE_PATH}}` | **语言**: {{LANGUAGE}} | **模式**: {{MODE}}
> **耗时**: {{DURATION}}

---

## 执行摘要

- 📁 扫描文件: **{{SCANNED_FILES}}** ({{SCANNED_LINES}} 行)
- 🔧 启用检测器: **{{DETECTORS_EXECUTED}}** / {{DETECTORS_MATCHED}} ({{FILTER_DESC}})
- 🔍 检出总数: **{{TOTAL}}** 个

| 严重度 | 数量 |
|--------|------|
| 🔴 Critical | {{CRITICAL_COUNT}} |
| 🟠 High | {{HIGH_COUNT}} |
| 🟡 Medium | {{MEDIUM_COUNT}} |
| 🔵 Low | {{LOW_COUNT}} |
| ⚪ Info | {{INFO_COUNT}} |

**安全评分: {{SCORE}}/100**

> 评分规则：满分 100，每个 Critical -25，每个 High -10，每个 Medium -3。{{PASS_FAIL_MESSAGE}}

---

## 检出清单

| 检出 ID | 严重度 | 检测器 | 文件:行 | 修复建议 |
|--------|--------|--------|---------|---------|
{{FINDINGS_TABLE}}

> ID 格式: `<SEVERITY>-<DETECTOR_ABBREV>-<FILE_SLUG>-L<LINE>` — 一眼看懂是什么问题、在哪个文件、哪一行。

---

## 详细发现

{{FINDINGS_DETAIL}}

---

## 修复优先级

### 🔴 立即修复 (Critical — 本次迭代)
{{CRITICAL_FIXES}}

### 🟠 优先修复 (High — 本次迭代)
{{HIGH_FIXES}}

### 🟡 计划修复 (Medium — 下迭代)
{{MEDIUM_FIXES}}

---

## 附录

| 项目 | 值 |
|------|-----|
| 输出目录 | `.codeagent/{{EXTENSION_NAME}}/scans/{{SCAN_ID}}/` |
| SARIF | `results.sarif` — 可导入 GitHub Code Scanning / GitLab SAST |
| 仪表盘 | `summary.json` — 团队统计汇总 |
| 门禁状态 | `status.json` — CI 通过/阻断 |
| CWE 覆盖 | [CWE Top 25](https://cwe.mitre.org/data/definitions/120.html) 100% |
| 标准参考 | SEI CERT C/C++/Java, OWASP ASVS, OWASP Cheat Sheet Series |
| 免责声明 | 本报告由 AI 辅助生成，建议结合人工审查确认。 |

---

**SecGuardian** — AI-Native Security Guardian  
报告版本: {{PROTOCOL_VERSION}} | 扫描编号: {{SCAN_ID}}
```

## 单个 Finding Detail 模板

```markdown
### {{FINDING_ID}} — {{TITLE}} [{{SEVERITY_EMOJI}} {{SEVERITY}}]

| 属性 | 值 |
|------|-----|
| **文件** | `{{FILE}}:{{LINE}}` |
| **检测器** | `{{DETECTOR}}` |
| **命名空间** | `{{NAMESPACE}}` |
| **CWE** | [{{CWE}}](https://cwe.mitre.org/data/definitions/{{CWE_NUMBER}}.html) |
| **置信度** | {{CONFIDENCE}} — {{CONFIDENCE_DESC}} |
| **函数** | `{{FUNCTION}}` |

**问题描述**: {{DESCRIPTION}}

**代码段**:
\`\`\`{{LANGUAGE}}
  {{CONTEXT_BEFORE}}
> {{VULNERABLE_LINE}}   // ← 检出点
  {{CONTEXT_AFTER}}
\`\`\`

**影响分析**: {{IMPACT}}

**修复方案**:
\`\`\`{{LANGUAGE}}
{{FIX_CODE}}
\`\`\`

**修复工作量**: {{EFFORT}} | **修复风险**: {{RISK_OF_FIX}} | **参考**: {{REFERENCES}}

---
```

## 空结果模板

当扫描无检出时：

```markdown
# {{EXTENSION_NAME}} 安全扫描报告

> **Scan ID**: `{{SCAN_ID}}` | **命令**: `/{{COMMAND}}` | **日期**: {{DATE}}

---

## 执行摘要

✅ **无安全问题检出。**

- 📁 扫描文件: **{{SCANNED_FILES}}** ({{SCANNED_LINES}} 行)
- 🔧 启用检测器: **{{DETECTORS_EXECUTED}}** 个
- 🔍 检出总数: **0**

**安全评分: 100/100** 🎉

> 当前代码库未发现已知安全漏洞模式。建议定期扫描保持安全态势。

---

## 附录

| 项目 | 值 |
|------|-----|
| 输出目录 | `.codeagent/{{EXTENSION_NAME}}/scans/{{SCAN_ID}}/` |
| 扫描命令 | `/{{COMMAND}} {{SCOPE_PATH}}` |
```

## 生成规则

1. **始终生成 `report.md`** — 即使无检出也生成空结果报告
2. **代码段包含上下文** — 检出行前后各 2 行
3. **每个检出包含完整修复方案** — 从 detector 文件的 `## 修复指引` 节提取
4. **修复优先级按严重度分组** — Critical → High → Medium，每组内按文件路径排序
5. **emoji 严重度标记** — 视觉化快速识别
