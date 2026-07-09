# LLM-Investigation-Architecture-Guide

> Version: v2 Draft

## 1. 目标

本指南用于指导 Codex 调度 DeepSeek V4 对现有 Security Scan Framework 进行重构。

核心目标不是继续强化 Rule Engine，而是演进为 Investigation Engine，提高 Recall，降低生产环境漏报。

---

# 2. 根因分析

当前架构：

Command -> Skill -> Rule -> Worker -> Finding

存在以下根因：

1. Dispatcher 过早决定漏洞类型。
2. Signal 被误认为 Conclusion。
3. Rule 固化推理路径。
4. Worker 只能验证，不会调查。
5. Reflection 更关注 Suppress，而不是发现漏洞。
6. Skill 被割裂，无法跨领域推理。

因此整个系统虽然流程完整，但推理能力被架空。

---

# 3. v2 总体架构

```text
Command
    │
    ▼
Signal Extraction
    │
    ▼
Hypothesis Generator
    │
    ▼
Investigator Agent Pool
    │
    ▼
Evidence Graph
    │
    ▼
Counter Evidence
    │
    ▼
Judge Agent
    │
    ▼
Finding
```

原则：

- Dispatcher 不推理
- Signal 不代表漏洞
- Rule 提供经验，不提供流程
- Investigator 自主调查
- Judge 独立裁决

---

# 4. Dispatcher 规范

Dispatcher 只允许：

- 建立索引
- 提供上下文
- 提供调用图
- 提供符号表
- 提供入口 Signal

Dispatcher 禁止：

- 判断漏洞类型
- Suppress
- Confirm
- 限制调查方向

错误：

malloc -> Null Skill

正确：

malloc -> Signal(memory allocation)

---

# 5. Signal Generator

Signal 仅是调查入口。

例如：

- malloc
- memcpy
- getenv
- strcpy
- pthread_mutex_lock

不要输出：

Buffer Overflow

要输出：

Memory Copy Signal

---

# 6. Hypothesis Generator

每个 Signal 至少生成 3~5 个 Hypothesis。

例如 memcpy：

H1 长度错误

H2 来源污染

H3 整数溢出导致长度错误

H4 生命周期错误

H5 实际安全

不要只生成一个。

---

# 7. Investigator

Investigator 不验证 Rule。

Investigator 调查事实。

允许：

- 自主读 Caller
- 自主读 Callee
- 自主扩大上下文
- 自主请求更多源码

Evidence 必须包括：

Source

Propagation

Sink

Control Flow

Data Flow

Lifetime

Ownership

---

# 8. Evidence

Evidence 必须引用源码。

不能：

"可能"

必须：

line xx

function xx

variable xx

---

# 9. Counter Evidence

必须尝试推翻自己。

例如：

是否已有 NULL Check？

是否 Contract 保证？

是否 RAII？

是否 Ownership Transfer？

如果没有反证，不允许 Suppress。

---

# 10. Judge

Judge 不重新扫描。

Judge 只阅读：

Evidence

Counter Evidence

Hypothesis

最后裁决：

Confirmed

Suspicious

Safe

Unknown

Unknown 不允许自动降级 Safe。

---

# 11. Rule.md 重构

Rule 保留：

危险模式

安全模式

误报模式

调查建议

删除：

Step1

Step2

Q1

Q2

Q3

固定流程。

---

# 12. Skill.md 重构

Skill 不描述流程。

Skill 描述：

领域知识

API

危险点

调查经验

边界条件

---

# 13. DeepSeek 工作规范

必须：

- 多假设
- 多证据
- 多反证

禁止：

Rule 没写就停止。

禁止：

Evidence 不足直接 Safe。

禁止：

没有发现问题就结束。

Evidence 不足：

继续扩大阅读范围。

---

# 14. Prompt 模板

Dispatcher：

输出 Signal。

不要输出漏洞。

Hypothesis：

至少五个假设。

Investigator：

逐个验证。

Judge：

独立裁决。

---

# 15. Null Dereference 样板

Signal：

malloc

Hypothesis：

NULL 未检查

Ownership 错误

Cleanup Double Free

Allocator 保证非 NULL

Investigator：

读取分配点

读取第一次解引用

读取调用链

Evidence：

记录所有引用。

Judge：

根据支持证据和反证输出。

---

# 16. Integer Overflow -> Buffer Overflow 样板

不要拆成两个 Skill。

必须联合调查：

整数来源

长度计算

分配

复制

最终写入。

输出统一 Finding。

---

# 17. 迁移顺序

Phase1

Dispatcher

Phase2

Rule 瘦身

Phase3

Skill 重构

Phase4

Hypothesis

Phase5

Judge

Phase6

Evidence Graph

Phase7

全部 Skill 迁移。

---

# 18. DeepSeek 禁止事项

禁止：

为了完成任务而结束调查。

禁止：

看到 Rule 就停止思考。

禁止：

没有证据就 Safe。

禁止：

只调查一个方向。

禁止：

忽略跨 Skill 推理。

---

# 19. Codex 实施计划

1. 重构 Dispatcher
2. 增加 Hypothesis Generator
3. Investigator 替换 Worker
4. 新建 Judge
5. Rule 瘦身
6. Skill 重构
7. Prompt 全部迁移
8. 新建 Evidence Graph
9. 回归测试
10. Recall Benchmark

---

# 20. 最终目标

系统目标：

不是 Rule Engine。

而是：

Evidence Driven Investigation Engine。

评价标准：

Recall > Precision。

先发现，再证明。

不要先否定，再调查。
