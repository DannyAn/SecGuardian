# ADR-001: SHA-256 作为 Finding 机器标识

**日期**: 2026-06-28
**状态**: ✅ Accepted

### Decision

Finding 的机器标识采用 SHA-256 哈希，输入为 `{detector}:{file}:{line}:{cwe}`，输出前 12 hex chars 作为文件名前缀。

### Reason

1. **确定性**: 同一输入永远产生同一输出，无需中心化 ID 分配
2. **去中心化**: AI Agent 可独立计算，无需查表
3. **碰撞安全**: 12 hex = 48 bit，单目录下 1000 个文件碰撞概率 < 10^-12
4. **对齐 SARIF**: `partialFingerprints` 本身就是内容哈希，SHA-256 是业界标准
5. **输入可重复**: `detector:file:line:cwe` 在扫描范围内天然唯一，SHA 只是提供紧凑表示

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| UUID v4 | 随机性，AI 无法确定性地重新计算。跨扫描追踪不可靠 |
| 顺序号 | 跨扫描顺序不同，无法作为稳定 identity。不同 AI Agent 生成的顺序不保证一致 |
| 旧格式改进 | 缩写规则无论如何改进，都无法同时满足"紧凑"和"可读"，且行号作为 identity 不稳定 |
| 时间戳 | 同一扫描的多个 finding 时间戳可能相同，碰撞风险 |

### Consequences

- 行号变化会改变 SHA → 跨扫描追踪需要依赖 delta.json（预期行为）
- 文件名不再携带严重度和检测器信息 → 依赖目录树分组

---

# ADR-002: 机器标识 vs 人类标识分离

**日期**: 2026-06-28
**状态**: ✅ Accepted

### Decision

机器标识（SHA-256）和人类可读标识（序号 `#1` ~ `#N`）彻底分离，不再共用同一字符串。

- 机器标识 → 文件名、`partialFingerprints`、跨扫描去重
- 人类标识 → report.md 表格、executive-summary.md、dashboard.html

### Reason

1. **单一职责原则**: 一个标识做一件事。SHA 做去重，序号做引用
2. **序号天然适合人**: "看一下 #3 那个 SQL 注入"是自然语言，不需要解析 ID 格式
3. **工程师使用习惯**: 实证发现工程师在代码审查中引用 finding 时用的是"文件:行号"而非"ID"
4. **行号作为引用比作为 identity 更稳定**: 人类引用需要的是"在哪"，不是"这是哪个"

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 继续使用统一 ID | 当前格式已经证明两件事都做不好 |
| 用 file:line 做 display identity | 同一文件多行 finding 时，区分度不够 |
| 用 file:function 做 display | 函数名可能很长或为空（如配置文件） |

### Consequences

- Renderer 需要维护一个 per-scan 的 seq → SHA 映射
- `manifest.json` 中同时包含 `seq` 和 `sha` 两个字段
- 报告生成时需要排序 → 线性复杂度 O(n log n)，n < 1000，可忽略
- 跨扫描的 delta 对比完全基于 SHA，不依赖序号

---

# ADR-003: 安全评分由 Renderer 独占计算

**日期**: 2026-06-28
**状态**: ✅ Accepted

### Decision

安全评分由 Renderer 的 `calc_score()` 函数独占计算，AI Agent 不写入 `security_score` 字段到 `findings.json`。

### Reason

1. **单一真相源**: 评分是 findings 列表的派生数据，不应在多个位置持有
2. **AI Agent 不擅长度量计算**: Agent 可能随机填 0 或猜错
3. **Renderer 已实现正确公式**: `calc_score()` 使用指数衰减，已验证对不同 severity 组合产出合理分数
4. **分层职责**: AI Agent 负责发现，Renderer 负责聚合和报告

### Consequences

- `findings.json` 模板需要移除 `security_score` 字段
- 所有现有 `findings.json` 中的 `security_score` 会被 Renderer 忽略
- 评分和等级成为纯派生数据，始终与 findings 列表一致
