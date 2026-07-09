# EPIC-009 — Architecture Decision Records

---

## ADR-001: 预筛器嵌入索引器而非独立工具

**日期**: 2026-07-09
**状态**: ✅ Accepted

### Decision

预筛器作为 Go 索引器 `internal/indexer/prescreener.go` 的内部模块实现，而非独立的 Python 脚本或 LLM 前置步骤。

### Reason

1. **数据亲和性**: 预筛需要的 CallSite、Declaration、AllocFreePair 等数据结构全部在 Go 索引器内部。在外部重新解析需要重复 AST 遍历或解析 index.json，浪费。

2. **零额外 I/O**: 内嵌在索引器 Phase 2.5（信号收集后、JSON 序列化前），直接在内存中处理。独立工具需要读 index.json → 处理 → 写 filtered.json，多 2 次 I/O。

3. **确定性**: Go 代码的行为由编译器保证，不受 LLM 版本/温度/token 限制影响。同一个输入永远产出同一个输出。

4. **部署简化**: 只有一个二进制，没有新增外部依赖。独立工具需要 deploy.sh 再部署一个文件。

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| Python 后处理脚本 | 需要全量解析 index.json（30MB+ 生产项目），重复 I/O |
| LLM 前置校验 prompt | 既然 LLM 会批量抑制，加 prompt 也拦不住 |
| 独立的 Go 二进制 `prescreener` | 与索引器共享所有数据结构，没必要分两个二进制 |

### Consequences

- prescreener 直接修改 `allCallSites` 数组（safe 标记的从 LLM 输入中移除）
- 索引器的 `--prescreen-audit` flag 可以输出被过滤的信号及其理由，用于调试
- 新增 `internal/indexer/prescreener.go` 文件，含 prescreener 接口和各个 skill 的实现

---

## ADR-002: 保守预筛策略——safe 标记高置信度

**日期**: 2026-07-09
**状态**: ✅ Accepted

### Decision

预筛器只能把**高置信度**的信号标记为 safe。不确定的信号一律标记 unknown 并保留在 LLM 输入中。

### Reason

1. **假阴性 > 假阳性**：把一个真漏洞标记为 safe（假阴性）导致漏报，比把一个安全信号保留给 LLM（假阳性）严重得多。LLM 收到一个安全信号，走 W1-W5 后会正确 SUPPRESS。

2. **渐进式增强**：预筛器先只处理最有把握的规则（buffer_overflow sizeof 匹配），后续再逐步增加。每次新增规则都有对应的测试覆盖边界条件。

### 置信度判定标准

| 置信度 | 条件 | 标记 | 行为 |
|--------|------|------|------|
| 高 | 有确定性证据（sizeof == ArraySize）且来源不是动态分配 | safe | 从 LLM 输入移除 |
| 中 | 有证据但存在一个不确定因素 | unknown | 保留给 LLM |
| 低 | 无任何确定性证据 | unknown | 保留给 LLM |

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 激进策略——有怀疑就过滤 | 假阴性风险不可接受。漏报比误报更致命 |
| 无预筛——靠 LLM 约束 | 已被生产扫描证伪 |

### Consequences

- buffer_overflow 预筛预期过滤效果 866→~100，而不是 866→0
- 剩余 ~100 个 unknown 信号仍需 LLM 分析，但数量已降到可控范围
- 预筛器可能有额外的 audit log 输出供调试

---

## ADR-003: 废弃 stripped 方案——从源头解决

**日期**: 2026-07-09
**状态**: ✅ Accepted

### Decision

删除 `strip-answer-cards.py`，将所有 demo 项目转换为 no-answers 格式。Worker 直接从源码目录读取。

### Reason

1. **PB-01 违反**：在用户项目目录下全量复制源码，违反"禁止修改/复制用户源码"架构约束。

2. **生产项目零收益**：生产代码没有 `// VULNERABILITY [CWE-xxx]` 标注，但 stripped 仍然全量复制。300 行脚本只为 demo 项目服务。

3. **路径复杂度**：Worker 需要同时支持 `$STRIPPED_ROOT` 和 `$SOURCE_ROOT` 两套路径，协议复杂化。去掉 stripped 后路径模型简化到只从源码目录读。

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 保留 stripped 但改为按需复制 | 依然违反 PB-01。仍然需要管理两个路径 |
| 保留 stripped 但改为 hardlink | 多 filesystem edge case，且仍然污染用户项目 |
| 不解散 stripped，加 --check-only 跳过复制 | 协议复杂度不变，收益远不如直接废弃 |

### Consequences

- 所有 demo 项目的 `// VULNERABILITY`/`// BAD:`/`// TP-xx:` 标注需要清理
- 清理后运行 `grep -r "VULNERABILITY\|// BAD:" examples/` 确保 0 匹配
- AGENTS.md 和各命令协议中的 stripped 引用全部删除
- 该工作一次性，完成后不再需要维护

---

## ADR-004: per_signal_analysis 协议强制

**日期**: 2026-07-09
**状态**: ✅ Accepted

### Decision

每个 Batch Worker 的 blindspot.json 输出必须包含与信号数等长的 `per_signal_analysis` 数组。Aggregator 在合并时检查完整性，缺失则告警。

### Reason

1. **PB-04 防御**：per_signal_analysis 可验证性是防御批量抑制的最后一道闸。如果 blindspot 没有逐信号记录，Aggregator 直接 WARNING。

2. **审计需求**：即使 50 个信号全部被 SUPPRESS，每个信号也有一条独立的裁决记录。客户/审计员可以逐条查看。

3. **Aggregator 可验证**：
   - 长度不匹配 → WARNING
   - 所有条目 verdict 相同且理由笼统（"都是安全变体"）→ WARNING
   - 所有 safe 标记来自 prescreener → OK（可验证）

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 信 LLM 会自觉逐条分析 | 已被证伪。866 个信号时 LLM 必然走捷径 |
| 缩小 BATCH_SIZE | BATCH_SIZE=10 仍然可能批量抑制，只是损失更小 |

### Consequences

- blindspot.json schema 变更：新增 `per_signal_analysis` 字段
- 协议文件更新：三命令全部加上约束
- Aggregator 协议更新：加入完整性检查

---

## ADR-005: 预筛器统一处理三命令

**日期**: 2026-07-09
**状态**: ✅ Accepted

### Decision

预筛器在索引器层统一运行，对 secguard/secaudit/secreview 三个命令产出一致的预筛结果。各命令不再各自做预筛。

### Reason

1. **AC-07**：三命令共享信号层。预筛是信号层的职责，不是命令层的职责。

2. **避免重复劳动**：如果各命令各自预筛，同样的 buffer_overflow 规则需要实现在 secguard.md/secaudit.md/secreview.md 三份协议里。Go 实现一次，三命令受益。

3. **一致性**：同一代码库的同一调用点，不因使用不同命令而得到不同预筛结果。

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 各自在协议中定义预筛规则 | 三份协议维护难度大；LLM 执行预筛不可靠 |
| secaudit 不做预筛（全量分析） | secaudit 信号更多，不做预筛 LLM 必然被困 |

### Consequences

- prescreener 的输出格式必须兼容三个命令的需求
- 如果某个命令需要不同的过滤粒度（如 secaudit 需要保留更多信号），prescreener 支持 per-command 配置
