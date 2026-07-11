# ADR — FEATURE-007: Signal Precision & Function-Level Context Assembly

> **隶属**: EPIC-011 / FEATURE-007
> **日期**: 2026-07-11
> **状态**: ✅ Accepted

---

## ADR-007: callee 级路由替代 category 级路由

### Decision
`rule.md` frontmatter 的 `signal_source` 从 `cat="memory"` 改为 `callee="free|delete"` 等精确函数名匹配。`partition-signals.py` 已有此匹配能力，不需要修改。

### Reason
1. `cat="memory"` 匹配 40 个信号到 8 个规则 → 320 assignments，其中大部分是噪音。`callee="free"` 只匹配 20 个信号 → 20 assignments。
2. `callee` 名是确定性的——indexer 通过 Tree-sitter 提取的函数名不会模糊。`cat` 是索引器的启发式分类，边界模糊（`snprintf` 属于 `string` 但也可视为 `memory`）。
3. `partition-signals.py` 的 `_matches()` 函数按字段名匹配，`callee` 和 `cat` 对它是等价的。

### Rejected Alternatives
| 方案 | 否决原因 |
|------|---------|
| 保持 `cat="memory"` 不变，在 prefilter 后过滤 | prefilter 只能减少信号数，不能解决 8 个规则共享同一批信号的结构问题 |
| 索引器做 rule 级预筛，不放 raw signal 给 Python | 索引器保持纯数据提取定位；Python 预筛可快速迭代规则无需重编译 |
| 配置式 pairs.json | 穷举式配置无法覆盖企业自定义命名，且本质是传统 SAST 方式，丢掉 LLM 语义优势 |

### Consequences
- 好：signals 降 50-75%，batch 数等比例下降。LLM 不再被无关信号淹没。
- 好：rule frontmatter 自文档化——从 `cat="memory"` 改为 `callee="free"` 明确表达了该规则关注什么函数调用。
- 不好：rule 作者需要知道目标语言中哪些函数名会被 Tree-sitter 提取。需要文档化各语言的 callee 命名规范。

---

## ADR-008: Python 预筛器而非 Go 索引器内预筛

### Decision
新增 `scripts/prefilter.py` 作为独立的确定性预筛层，消费 index.json 的变量级数据，在 partition-signals 之前执行。预筛器在 Go 索引器之外运行，不进入编译管线。

### Reason
1. **迭代速度**：预筛规则是启发式的，需要频繁调参。Python 修改规则后无需重编译 CGO 二进制。
2. **数据消费**：index.json 已经是自包含的 JSON 文档，预筛器可以直接读写。
3. **可测试性**：Python 的预筛逻辑可以接受 mock index.json 做单元测试，方便 TDD。
4. **保守策略可审计**：预筛器输出 `filter_reasons` JSON，任何被过滤的信号都有明确理由。coverage-gate 可以读取这些 reasons 做审计。

### Rejected Alternatives
| 方案 | 否决原因 |
|------|---------|
| 在 Go 索引器内做预筛 | 预筛规则迭代需重新编译；Python 更利于快速实验 |
| 在 partition-signals.py 内做预筛 | 职责混淆：partition 负责路由，prefilter 负责过滤。分开后各自可独立测试 |
| 不做预筛，完全靠 LLM | 生产项目信号量级（1358+）必然导致 batch-suppression 或上下文溢出 |

### Consequences
- 好：预筛逻辑独立于索引器和分区器，三者可独立演进。
- 好：预筛结果可审计（filter_reasons.json）。
- 不好：增加的 Python 脚本需要打包部署。需更新 package.sh + deploy.sh。

---

## ADR-009: V1+V2 调用图合并

### Decision
`main.go` 的调用图构建改为：同时运行 V1（user→user）和 V2（user→lib），合并去重后写入 index.json。V1 使用已有的文本近似匹配算法，V2 使用 call_sites。

### Reason
1. V1 是唯一能产出 user→user 边的机制。当前因 V2 优先而成为死代码。
2. V1 的文本近似匹配在 demo 的 `TestBuildCallGraph_DirectCall` 和 `TestBuildCallGraph_CrossFileCall` 测试中正常工作。
3. 跨文件检测和无调用链信息是当前的硬限制——"一个函数的完整上下文"如果没有 callers/callees 就不完整。

### Rejected Alternatives
| 方案 | 否决原因 |
|------|---------|
| 重写 V2 使其支持 user→user | V2 基于 call_sites，call_sites 只追踪库函数。要追踪 user→user 需要改 parser，工作量远超 V1 复用 |
| 删除 V1，保持现状 | 调用链/被调用链信息永久缺失，跨文件检测不可能 |
| AST 级调用图 | 需要完整 AST 遍历，与当前轻量架构冲突 |

### Consequences
- 好：调用图同时包含 user→user 和 user→lib 边。`main → parse_task_name` 等关系出现。
- 好：函数级上下文可以包含 callers 和 callees 信息。
- 不好：V1 假边风险（短函数名误匹配）仍然存在。合并时按 `(caller, callee, file)` 去重可部分缓解。

---

## ADR-010: 函数级上下文替代信号级 batch

### Decision
`partition-signals.py` 新增 `--group-by function` 模式。按函数分组后，同一函数的全部 call_sites + variable_writes + pointer_validations + taint_flows 作为一个 batch 交给 LLM。
一个函数可能分配给多个 rule（因为包含不同类型的信号），但每个 `(rule, function)` 组合是一个独立 batch。

### Reason
1. 当前 per-signal 模式：LLM 看到孤立的信号，无法识别配对关系和上下文。`llm_malloc`/`llm_free` 如果分在不同 batch，LLM 无法做语义配对。
2. Per-function 模式：LLM 看到一个函数的"全景图"——所有调用、变量流转、控制流摘要。这更接近人类 code review 的方式。
3. 批量效果：demo 项目从 32 个 batch（per-signal）降到预计 ~12 个 batch（per-function），每个 batch 信息密度更高。

### Rejected Alternatives
| 方案 | 否决原因 |
|------|---------|
| per-file 分组 | 文件内可能包含多个不相关函数，上下文噪音大 |
| per-variable 分组 | 需要完整 def-use chain，索引器未实现 |
| 保持 per-signal 不变 | 不自包含的上下文导致 LLM 无法做语义配对，企业自定义分配器场景失效 |
| 完全 LLM 自主调查（无预筛无分组） | 生产规模下 batch-suppression 必然复发 |

### Consequences
- 好：LLM 的语义能力（配对识别、模式识别）被充分利用。
- 好：batch 数量大幅减少（32 → ~12 for demo），每个 batch 质量大幅上升。
- 好：企业自定义分配器（`llm_malloc`/`llm_free`）无需配置即可被 LLM 语义识别。
- 不好：大函数可能超过上下文预算。设置 `MAX_FUNCTION_LINES=300` 硬限制，超过则切片处理。

---

## ADR-011: 跨语言能力分层

### Decision
按语言的索引器能力分 Tier，每层支持不同的预筛深度。架构不强制补齐低 Tier 语言的能力，而是在能力不足时自动降级到"callee 路由 + 函数分组 + LLM 全权判断"。

### Reason
1. C/C++ 是唯一有 CFG/taint/alloc_free/pointer_valid 的语言。Python/Java/Go 的 tree-sitter 解析器目前不产出这些数据。
2. 全语言补齐 CFG/taint 是 FEATURE-002 M2+ 的长期目标，不应阻塞 P1/P3/P4 在当前能支持的语言上落地。
3. 分层设计允许逐语言增量增强，不强求一次性全语言等价。

### Rejected Alternatives
| 方案 | 否决原因 |
|------|---------|
| 全语言统一功能（等补齐后再做） | 推迟 P0 问题的修复，C++ 用户继续承受噪音爆炸 |
| C++ only（不做跨语言） | 非 C++ 语言仍然可以用 callee 路由 + 函数分组 + 调用图修复，不应放弃 |

### Consequences
- 好：C++ 可以立即受益（P1-P4 全覆盖），其他语言至少获得 P1+P3+P4。
- 好：增加 Tier 的路径清晰——某个语言补齐了 CFG 数据，升级到 Tier 1 即可启用 P2 预筛。
- 不好：跨语言行为不一致。需在文档中明确各语言的当前能力层级。

---

## ADR-012: buffer_overflow 检测对标业界三层模型

### Decision
buffer_overflow 的预筛不依赖"安全变体即安全"的简化判断。采用业界（Coverity/SAL/Clang）的三层模型：
1. **容量追踪**：从 declarations/allocations 推导每个缓冲区的实际字节容量
2. **写入校验**：在 strcpy/memcpy/sprintf 调用点验证写入量 ≤ 缓冲区容量
3. **安全变体验证**：不将 `_s` 函数等同于安全——而是验证其 size 参数与实际容量是否一致

当前数据能力边界：
- 第 1 层栈数组容量：✅ declarations.array_size
- 第 1 层堆分配容量：❌ 需要追踪 `malloc(n)` 中 n 的实际值
- 第 1 层参数容量：❌ 需要 `SAL_size(n)` 类注解或启发式推断
- 第 2 层写入量：✅ call_sites 参数已知，可提取常量写入量
- 第 3 层安全变体：✅ 已有 prescreener 的 sizeof 匹配（仅栈数组）

### Reason
1. `strcpy_s(dst, sizeof(dst), src)` 的安全性是**有条件**的：仅当 dst 是栈数组时 sizeof 才正确。如果 dst 是指针参数，`sizeof(dst)` = 8，产生虚假安全感。
2. 安全变体是运行时保护（截断或返回错误），不是编译时证明。检测工具的职责是验证运行时保护是否正确配置。
3. Index Out of Bounds（`dst[user_input] = x`）和 buffer overflow 共享同样的容量追踪基础。先建立容量追踪，再扩展检测范围。

### Rejected Alternatives
| 方案 | 否决原因 |
|------|---------|
| "安全变体 = 安全"的简化模型 | 用户指出：sizeof(ptr) 误用、size 参数错误、Index Out of Bounds 全部漏检 |
| 不追踪容量，只做模式匹配 | 传统正则 SAST 的做法，已证明精度低、误报高 |
| 完整 inter-procedural 数据流 | 当前 M2 目标，不在本 Feature 范围内 |

### Consequences
- 好：buffer_overflow 检测从"安全变体标记"升级为"容量-写入校验"，与 Coverity/CodeQL 对齐
- 好：Index Out of Bounds（CWE-129）可以在同一容量追踪基础上扩展
- 不好：堆分配的容量追踪需要变量级数据流，栈数组容量追踪只能覆盖部分场景。LLM 仍需处理堆缓冲区溢出
- 不好：需要维护各库函数的"写入量计算规则"——例如 `sprintf(buf, "%s-%d", s, n)` 的写入量估算不是常量
