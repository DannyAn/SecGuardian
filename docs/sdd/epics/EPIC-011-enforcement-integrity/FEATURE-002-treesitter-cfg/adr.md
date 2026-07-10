# ADR — FEATURE-002: Tree-sitter Primary + CFG Construction

> **隶属**: EPIC-011 / FEATURE-002
> **日期**: 2026-07-10

---

## ADR-101: zig cc 交叉编译使 tree-sitter 成为全平台唯一解析器

**状态**: ✅ Accepted

### Decision
用 `zig cc` 作为 C 交叉编译器，`CGO_ENABLED=1` 构建 linux/windows/arm64，使 tree-sitter（CGO）在所有平台生效；删除 `parser_re.go` 正则回退，`parser_ts.go` 成为唯一解析器。

### Reason
1. **实证发现**：`go-tree-sitter@v0.25.0` 含 15 个 .c 文件，`CGO_ENABLED=0` 时语法库 `bindings/go` 的 build constraint 排除所有 Go 文件——tree-sitter 确需 CGO，双解析器非等价（F5）的根因是"跨平台避免 C 交叉编译"而非"tag 误标"
2. zig cc 是 Go 社区事实标准的 CGO 交叉编译工具链（单二进制、多目标），让 tree-sitter 全平台一致
3. 删除正则回退从根因消灭 F5，"打败 AST"在所有平台成立
4. 单解析器 = 单一行为 = 可测试、可回归

### Rejected Alternatives
| 方案 | 否决原因 |
|------|---------|
| 保留正则回退，仅修 EndLine/signals | 不"打败 AST"——跨平台仍用比 AST 更差的近似；F5 仅缓解不根除 |
| 寻找纯 Go tree-sitter 移植（modernc 风格）| 2026-07 核实受限于搜索可用性，无法确认 5 语言纯 Go 移植成熟度；可作为未来 ADR supersede，但不阻塞当前 |
| 仅 darwin 用 tree-sitter，跨平台不发布二进制 | 退化为单平台工具，背离分发目标 |
| 保留双解析器 + 等价测试守卫 | 守卫只能检测不等价，不能消除；维护两套逻辑成本永久存在 |

### Consequences
- 好：F5 根除；单一解析器行为；"打败 AST"全平台成立
- 不好：CI/构建环境需安装 zig；初次 zig 交叉编译调试成本
- 过渡：zig 全绿前可保留正则回退为**显式降级模式**（输出标 `degraded:regex`），但终态删除

---

## ADR-102: CFG 构建在 tree-sitter CST 之上，按函数粒度

**状态**: ✅ Accepted

### Decision
新增 `internal/indexer/cfg.go`，基于 tree-sitter CST 按函数构建控制流图（基本块 + 控制边），序列化进 `AnalysisContext.cfg`，并提供 `IsReachable`/`Dominates` 查询。

### Reason
1. AGENTS.md 能力边界显式标注"无 CFG，无可达性分析"——这是误报无法结构性消减的根因
2. CFG 是"AI 辅助超越 SAST"的关键地基：引擎提供控制流事实（可达性/必经性），LLM 在事实之上做语义判断，而非空想
3. 按函数粒度（非全程序）规模可控，迭代法支配树足够，无需复杂算法
4. tree-sitter CST 已有统一节点位置与 kind，CFG 构建可语言无关 + 适配层

### Rejected Alternatives
| 方案 | 否决原因 |
|------|---------|
| 不建 CFG，让 LLM 推理控制流 | LLM 控制流推理不可靠且不可校验；正是当前误报之源 |
| 直接做 DFG/污点传播跳过 CFG | DFG 依赖 CFG（汇合点、路径敏感性），跳过不可行 |
| 用外部 SSA 框架（如 golang.org/x/tools/go/ssa）| 仅适用 Go，不支持 C/C++/Java/Python；违背多语言统一 |
| 全程序 CFG（含过程间）| 规模与复杂度过大；per-function CFG + 调用图组合已满足当前需求 |

### Consequences
- 好：可达性/必经性成为引擎事实；null_dereference 等 Q3 可机器校验；DFG 未来有地基
- 好：CFG 作为 AI 证据源，强化"超越 SAST"两根支柱
- 不好：index.json 体积增加（仅行号+边，可控）；CFG 构建增加索引时延（per-function，可接受）
- 不好：某语言控制结构遗漏风险（`cfg_incomplete` 标记缓解）

---

## ADR-103: S3 Declarations 填充并接通 prescreener，而非废弃 prescreener

**状态**: ✅ Accepted

### Decision
在 `parser_ts.go` 符号提取阶段填充 `Declarations`，接通 prescreener，使 EPIC-009 的 safe-variant 降噪真正生效。

### Reason
1. prescreener 逻辑本身正确，仅缺 S3 数据（F6 实证：`allDecls` 恒空）
2. safe-variant 降噪（`strcpy_s`/`memcpy_s`/`snprintf`）是降低 LLM 噪声的有效机制，废弃浪费
3. 单解析器（ADR-101）后，Declarations 填充只需在一处实现

### Rejected Alternatives
| 方案 | 否决原因 |
|------|---------|
| 废弃 prescreener | 损失 safe-variant 降噪；EPIC-009 投资浪费 |
| 保留死代码现状 | F6 致命项未修，`SafeCount` 永远 0 |

### Consequences
- 好：F6 修复，红测试转绿，降噪生效
- 不好：需验证 safe-variant 判定在真实代码上的准确率（由 FEATURE-001 oracle 度量）

---

## ADR-104: CFG 按函数构建 + 按需切片，不全量序列化喂 LLM（生产规模约束）

**状态**: ✅ Accepted

### Decision
CFG 按**函数**粒度构建（per-function，非全程序），序列化进 index.json 时仅存 BB 的行号 + 后继边（不存源码）。LLM 调查某 signal 时，**只取该 signal 所在函数的 CFG + 支配/可达子图**作为上下文切片，绝不把全量 CFG 喂给 LLM。

### Reason
1. **生产规模**：用户实测 684 个 C 文件。全程序 CFG 体积与时延不可接受；per-function CFG 规模可控（单函数通常 <100 BB）。
2. **LLM 上下文预算**：684 文件 + CFG 的 index 约 13MB+，全量喂 LLM 会触发 batch-suppression（v0.18.0 的 1358→0 根因）。CFG 必须按需切片。
3. 当前实现已是 per-file 流式 + per-function 构建（`extractCFGs` 按函数节点遍历），天然满足规模约束；序列化只存行号+边，体积可控。
4. `IsReachable`/`Dominates` 查询是 per-function 的 O(n)~O(n²)，单函数规模下可接受，不引入全程序开销。

### Rejected Alternatives
| 方案 | 否决原因 |
|------|---------|
| 全程序 CFG（含过程间）| 684 文件规模下体积/时延爆炸；LLM 上下文无法承载 |
| CFG 全量序列化喂 LLM | 直接触发 batch-suppression，违背上下文预算约束 |
| CFG 存源码片段 | 体积膨胀；源码可按需从原文件按行号取，无需冗余存 |

### Consequences
- 好：per-function CFG 规模可控；按需切片保护 LLM 上下文预算；查询 API 支持精准取证
- 不好：跨函数控制流（如 caller→callee 的可达性）需配合调用图组合，非单 CFG 能答；后续 DFG/污点传播需明确跨函数策略
- 不好：index.json 仍随仓库增长，需 FEATURE-006 的分片查询接口避免全量加载
