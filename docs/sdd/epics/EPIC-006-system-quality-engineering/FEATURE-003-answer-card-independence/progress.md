# FEATURE-003: Progress — Answer-Card Independence

## 总体状态

| 环 | 文档 | 状态 | 日期 |
|---|------|------|------|
| 🧠 Brainstorm | 生产会话分析 + 受控实验设计 | ✅ 完成 | 2026-07-06 |
| 📋 Spec | spec.md | ✅ 完成 | 2026-07-07 |
| 📝 ADR | adr.md | ✅ 完成 | 2026-07-07 |
| 📐 Plan | plan.md | ✅ 完成 | 2026-07-07 |
| 🔨 Task | 见下 | ✅ 完成 | 2026-07-07 |
| 📊 Progress | 本文件 | ✅ 完成 | 2026-07-07 |
| 🔄 Change | changes/CHANGE-001 | ✅ 完成 | 2026-07-07 |

## 任务清单

| ID | 任务 | 状态 | 完成日期 |
|----|------|------|---------|
| 1 | 受控实验：剥离 java-vuln-demo 答案卡后扫描对比 | ✅ 完成 | 2026-07-07 |
| 2 | 创建 scripts/strip-answer-cards.py | ✅ 完成 | 2026-07-07 |
| 3 | 集成 secguard 模板 Step 2.5 | ✅ 完成 | 2026-07-07 |
| 4 | self-check §13e 检查 | ✅ 完成 | 2026-07-07 |
| 5 | SDD 文档闭环 | ✅ 完成 | 2026-07-07 |

## 实验验证

### 剥离结果（java-vuln-demo → stripped）

```
✅ Answer-card strip: 8 files scanned, 8 files modified, 75 lines stripped
```

### 扫描对比

| 指标 | 原始（有答案卡） | 剥离（无答案卡） | 评估 |
|------|-----------------|-----------------|------|
| 检出总数 | 27 | 28 | ✅ 无退化 |
| Critical | 12 | 12 | ✅ 一致 |
| High | 13 | 14 | ✅ 更多（细分检出） |
| Medium | 2 | 2 | ✅ 一致 |
| validate-findings | ✅ 通过（1 severity fix） | ✅ 通过（1 severity fix） | ✅ 一致 |

### 关键发现

剥离答案卡后的扫描结果不仅覆盖了原始版本的 27 个 finding，
还额外独立检出了 JWT secret hardcoded（从原始的一个 hardcoded-secrets 拆分为两个）。
证明 guard-rule 独立检测能力不低于（甚至优于）依靠答案卡的检测。

## 已知问题

- `p3_edge_case.reloadConfig` 的 TOCTOU 问题（CWE-367）仍然系统性地检测不到
  因为符号表中没有匹配的 target_functions。这是 FEATURE-002 设计的已知限制，
  不在此 FEATURE 范围内。

## 下一步

无。本 Feature 已完整交付。
