# 安全审计案例 — {{PROJECT_NAME}}

> 使用 SecGuardian 对开源/商业项目执行的真实安全审计案例。

---

## 案例概览

| 项目 | 详情 |
|------|------|
| **项目名称** | {{PROJECT_NAME}} |
| **审计日期** | {{AUDIT_DATE}} |
| **项目规模** | {{SCOPE_FILES}} 文件, {{SCOPE_LINES}} 行 |
| **主要语言** | {{SCOPE_LANGUAGE}} |
| **审计方法** | {{SKILL_NAME}} |
| **审计耗时** | {{DURATION}} |

---

## 安全评分

```
████████████████░░░░░░  {{SECURITY_SCORE}}/100
```

---

## 关键发现

### Critical

{{#each CRITICAL_FINDINGS}}
#### {{id}}: {{title}}

**位置**: `{{file}}:{{line}}`
**置信度**: {{confidence}}

**描述**: {{description}}

**影响**: {{impact}}

**修复方案**:
```{{language}}
// Before:
{{code_before}}

// After:
{{code_after}}
```

**修复工作量**: {{effort}}
**修复风险**: {{risk_of_fix}}
{{/each}}

### High

{{#each HIGH_FINDINGS}}
(同上结构)
{{/each}}

---

## 与现有 SAST 工具的对比

| 维度 | SecGuardian | CodeQL | Semgrep |
|------|-------------|--------|---------|
| 发现总数 | {{total}} | — | — |
| 独有发现数 | {{unique}} | — | — |
| 误报排除 | AI 推理过滤 | 规则排除 | 规则排除 |

> 备注：{{COMPARISON_NOTES}}

---

## 客户评价（模板）

> "{{QUOTE}}"
> — {{CUSTOMER_NAME}}, {{CUSTOMER_TITLE}}

---

## 可复用性

本案例中的主要发现类型在以下场景中可复用：

- {{REUSE_SCENARIO_1}}
- {{REUSE_SCENARIO_2}}
- {{REUSE_SCENARIO_3}}

---

## 附录：审计范围

| 目录/文件 | 审计内容 |
|-----------|---------|
{{SCOPE_TABLE}}

---

**SecGuardian** — AI-Native Security Guardian | 案例编号: {{CASE_ID}}
