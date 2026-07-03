# CHANGE-001: 证据收集从概念空白 → 三级体系

> **Feature**: FEATURE-002-detector-quality
> **日期**: 2026-06-11
> **类型**: 功能增强
> **原则**: Change 管理演进

## Reason

全面审查 67 个检测器后发现：**无一包含证据收集指引**。AI Agent 扫描时不知道应该收集什么证据来支撑一个 finding。这导致：
- 同一个漏洞，不同 AI 模型产出的 finding 质量差异悬殊
- 缺乏可复现性——同一段代码两次扫描结果可能不同
- 无法区分"真漏洞"和"看起来像漏洞"——没有证据门控

## Impact

| 维度 | 变更前 | 变更后 |
|------|--------|--------|
| 证据收集 | 零指引，AI 自由发挥 | MUST/SHOULD/MAY 三级结构化指引 |
| 误报率 | 不可控（AI 决定是否报告） | 证据门控（无 MUST 证据 → 不报告） |
| 可复现性 | 不可复现 | 同一段代码 → 同一条 MUST 证据 → 同一结论 |
| Schema 字段 | call_stack/variable_state/sanitizer 不存在 | 3 个新字段支撑深度取证 |

### 新增需求
- REQ-008: 每个 detector 含 MUST/SHOULD/MAY 证据收集指引
- REQ-009: findings-schema.json 新增 call_stack/variable_state/sanitizer_analysis
- REQ-010: confidence 从静态改为 dynamic（AI 根据证据完整度实时计算）

### 向后兼容
- 现有 findings 文件的 evidence 字段保持不变
- 新字段均为 optional，旧 finding 不受影响
