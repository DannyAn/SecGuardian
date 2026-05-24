---
category: protocol
version: "1.0"
---

# SecGuardian 安全审计报告模板

审计完成后按此模板生成客户可交付的 Markdown 报告。

---

# {{PROJECT_NAME}} 安全审计报告

**审计日期**: {{AUDIT_DATE}}
**审计编号**: {{SCAN_ID}}
**审计方法**: {{SKILL_NAME}} ({{SKILL_CATEGORY}})
**审计范围**: {{SCOPE_PATH}} ({{SCOPE_LANGUAGE}}, {{SCOPE_FILES}} 文件, {{SCOPE_LINES}} 行)

---

## 执行摘要

本次审计使用 AI 深度安全分析引擎，对 **{{PROJECT_NAME}}** 进行了 **{{SKILL_NAME}}** 专项审计。

### 总体安全评分

```
████████████████████░░   {{SECURITY_SCORE}}/100
```

> 评分基于发现的严重度和数量加权计算。Critical 每个 -25 分，High 每个 -10 分，Medium 每个 -3 分，满分 100。

### 关键发现

- 🔴 **Critical**: {{CRITICAL_COUNT}} 个 — 可直接导致代码执行或数据泄露
- 🟠 **High**: {{HIGH_COUNT}} 个 — 可被利用但需要一定条件
- 🟡 **Medium**: {{MEDIUM_COUNT}} 个 — 降低系统安全强度
- 🔵 **Low**: {{LOW_COUNT}} 个 — 最佳实践违反
- ⚪ **Info**: {{INFO_COUNT}} 个 — 信息性发现

> **注意**: AI 审计不能替代人工安全审查。Critical/High 级别发现建议立即响应，Medium 级别建议在下一迭代中修复。

---

## 发现清单

| ID | 严重度 | 置信度 | 文件:行 | 标题 |
|----|--------|--------|---------|------|
{{FINDINGS_TABLE}}

---

## 详细发现

{{FINDINGS_DETAIL}}

---

## 修复优先级建议

### 立即修复 (本次迭代)
{{IMMEDIATE_FIXES}}

### 本次迭代内修复
{{THIS_ITERATION_FIXES}}

### 下迭代修复
{{NEXT_ITERATION_FIXES}}

---

## 安全趋势

{{#if HAS_HISTORY}}

| 日期 | 审计 | 安全评分 | Critical | High | Medium |
|------|------|---------|----------|------|--------|
{{HISTORY_TABLE}}

趋势: {{TREND_DIRECTION}} ({{TREND_DELTA}} 分)

{{else}}

> 这是首次审计，尚无历史趋势数据。建议每月进行一次审计以追踪安全态势变化。

{{/if}}

---

## 附录

### A. 审计方法说明

本次审计使用 **SecGuardian secaudit** AI 深度安全分析引擎。分析方法基于以下安全标准和最佳实践：

- {{METHODOLOGY_REFERENCES}}

**与传统 SAST 的区别**: 传统工具做模式匹配，本审计做深度推理。AI 理解代码的上下文、业务逻辑和数据流，能发现传统工具遗漏的隐蔽漏洞。

**置信度说明**:
- **high**: AI 确认存在可验证利用路径
- **medium**: 存在风险模式但缺乏完整利用链证据
- **low**: 安全最佳实践违反，无可直接利用路径

### B. 扫描范围

- 路径: {{SCOPE_PATH}}
- 语言: {{SCOPE_LANGUAGE}}
- 文件数: {{SCOPE_FILES}}
- 代码行数: {{SCOPE_LINES}}
- 审计 skill: {{SKILL_NAME}}
- 耗时: {{DURATION}}

### C. 免责声明

本报告由 AI 自动生成。虽然我们使用先进的 AI 模型进行深度安全分析，但 AI 审计不能保证发现所有安全漏洞。建议结合人工安全审查和其他安全工具的结果进行综合判断。

---

**SecGuardian** — AI-Native Security Guardian
报告版本: 1.0 | 审计编号: {{SCAN_ID}}
