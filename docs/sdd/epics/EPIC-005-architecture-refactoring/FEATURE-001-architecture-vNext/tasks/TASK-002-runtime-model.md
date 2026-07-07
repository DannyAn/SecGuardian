# TASK-002: Create runtime-model.md

> **Feature**: FEATURE-001 Architecture Documentation vNext
> **隶属 Task**: 2 / 5

## 目标

创建 `docs/architecture/runtime-model.md`，描述双运行时架构。

## 内容要求

文档必须区分：

1. **Runtime A (AI Agent Runtime)**
   - 交互式执行
   - 上下文维持
   - 增量扫描
   - 人机协作
   - 数据输出：report + findings + patch

2. **Runtime B (CI Runtime)**
   - 确定性执行
   - Headless 模式
   - SARIF 输出
   - 门禁退出码
   - 数据输出：telemetry + gate decision + SARIF

3. **Shared Layer**
   - indexer
   - knowledge / detectors
   - output protocol
   - versioning

4. **Dual-Runtime Consequences**
   - 对 skill 设计的影响
   - 对输出协议的影响
   - 对验证流程的影响

## 原则

- 清晰说明两个运行时共享什么、不同什么
- 避免隐含 CI 是"first-class"运行时（CI 是另一个运行时，不是主要运行时）

## 验证

- 文件存在：`docs/architecture/runtime-model.md`
- 双运行时对比清晰
