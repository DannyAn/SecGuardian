# TASK-003: Create security-engine.md

> **Feature**: FEATURE-001 Architecture Documentation vNext
> **隶属 Task**: 3 / 5

## 目标

创建 `docs/architecture/security-engine.md`，定义未来 Security Engine。

## 内容要求

文档必须定义（仅定义，不实现）：

1. **Responsibilities** — Engine 做什么
   - Rule 加载与版本管理
   - Index 匹配与 Finding 定位
   - 执行编排（规则顺序、依赖、去重）
   - 输出标准化

2. **Inputs**
   - Rule Packs (knowledge/detectors/)
   - Index (index.json)
   - Configuration (language filter, severity threshold)
   - Scan Context (file list, baseline)

3. **Outputs**
   - Raw findings (machine-readable)
   - Telemetry (for CI dashboard)
   - Evidence (for audit trail)
   - LLM context (for explanation & patch generation)

4. **Interfaces**
   - AI Agent ↔ Engine API
   - CLI ↔ Engine API
   - CI ↔ Engine API

5. **Boundaries**
   - Engine 不负责 LLM 交互
   - Engine 不负责报告渲染
   - Engine 不负责自然语言解释

6. **Gradual Adoption Path**
   - 如何从当前架构逐步迁移到 Engine 架构

## 原则

- 只定义，不实现
- 边界清晰，不越界
- 当前架构和 Engine 可以共存

## 验证

- 文件存在：`docs/architecture/security-engine.md`
- Engine 的 Inputs/Outputs/Interfaces/Boundaries 全部定义
