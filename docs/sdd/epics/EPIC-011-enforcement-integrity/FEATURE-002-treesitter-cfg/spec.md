# FEATURE-002: Tree-sitter Primary + CFG Construction（Pillar 0）

> **隶属 Epic**: EPIC-011 Enforcement Integrity
> **支柱**: Pillar 0（引擎 recall 基线）
> **创建**: 2026-07-10
> **优先**: P0
> **修复致命项**: F5, F6 + 架构升级（CFG 新能力）
> **用户指令落点**: "Tree-sitter 打败 AST" + "CFG 不可忽视"

---

## 1. Problem Statement

### 1.1 双解析器非等价（F5，实证确认）
`parser_ts.go` 用 `go-tree-sitter` v0.25.0（**经实证：该库含 15 个 .c 文件，`CGO_ENABLED=0` 时语法库 `bindings/go` 的 build constraint 排除所有 Go 文件 → tree-sitter 确需 CGO**）。`package.sh:74-78` 对 linux/windows 用 `CGO_ENABLED=0` 强制走 `parser_re.go` 正则回退。正则路径 `EndLine==StartLine`（`parser_re.go:73`）致函数体边界失效，调用图 caller 全空、alloc-free 错配回退整文件、S8/S9/S10 信号近空。**同一仓库 darwin-arm64 与跨平台产出完全不同的 index.json**——"打败 AST"在跨平台构建上沦为"比 AST 更差"。

### 1.2 prescreener 死代码（F6，实证确认）
S3 `Declarations` 信号从未被任何解析器填充，`allDecls` 恒空，prescreener 每站返回 `VerdictUnknown`，EPIC-009 降噪 0%；`TestDeclarationExtraction` CGO 测试已红。

### 1.3 无 CFG（架构缺口，AGENTS.md 显式标注 ❌）
当前索引器能力边界明确"无控制流图，无可达性分析"。后果：
- 无法判断"NULL 检查是否支配解引用点"——LLM 只能空想控制流，误报/漏报
- 无法做死代码/不可达 sink 分析
- 未来 DFG/污点传播缺地基

### 1.4 对北极星的破坏
- 支柱 1（recall 对等）：跨平台构建索引器失明，SAST 能检的它检不到
- "打败 AST"：正则回退比 AST 更差，背离用户指令
- CFG 缺失：误报无法结构性消减，LLM 语义判断缺事实地基

---

## 2. Design Goals

| ID | 目标 | 度量 |
|----|------|------|
| G1 | tree-sitter 成为全平台唯一解析器 | linux/windows 二进制与 darwin 产出等价 index.json（fixture 对比）|
| G2 | 删除正则回退 | `parser_re.go` 移除；无 `!cgo` 路径 |
| G3 | CFG 构建 | 5 语言按函数产出基本块 + 控制边，写入 `AnalysisContext.cfg` |
| G4 | 可达性/必经性 API | `IsReachable`/`Dominates` 查询可用，单测覆盖 |
| G5 | S3 Declarations 填充 | prescreener `SafeCount > 0`，红测试转绿 |
| G6 | "打败 AST"可证 | CFG 事实使误报结构性下降（由 FEATURE-001 oracle 度量 precision 提升）|

---

## 3. Requirements

### REQ-101: zig cc 交叉编译（tree-sitter 全平台）
- **REQ-101a** `package.sh` 改用 `CC='zig cc -target ...'` `CGO_ENABLED=1` 交叉编译 linux/windows/arm64，tree-sitter 在所有平台生效
- **REQ-101b** 删除 `parser_re.go` 及其 `//go:build !cgo` 路径；`parser_ts.go` 移除 `//go:build cgo` tag（改为唯一解析器）
- **REQ-101c** `mattn/go-pointer` stale 依赖清理
- **REQ-101d** CI/Dockerfile 安装 zig（`go install` 或包管理器）

### REQ-102: CFG 构建
- **REQ-102a** 新增 `internal/indexer/cfg.go`，基于 tree-sitter CST 按函数构建 CFG
- **REQ-102b** 基本块（BB）：顺序语句 maximal block；控制边类型：`true`/`false`/`fallthrough`/`return`/`break`/`continue`/`throw`/`call_return`
- **REQ-102c** 支持控制节点：if/else/for/while/switch/case/try/catch/return/break/continue/throw/goto（语言差异在适配层处理）
- **REQ-102d** CFG 序列化进 `AnalysisContext.cfg`：`{functions: [{name, file, entry_bb, bbs: [{id, stmts:[line], succ:[{to, type}]}]}]}`

### REQ-103: 可达性/必经性查询
- **REQ-103a** `IsReachable(fromBB, toBB)` — BFS/DFS
- **REQ-103b** `Dominates(checkBB, useBB)` — 支配树（Lengauer-Tarjan 或简单迭代数据流）
- **REQ-103c** 查询 API 供检测器与 AI Investigator 调用（先 Go API，后通过 index.json 暴露）

### REQ-104: S3 Declarations 填充 + prescreener 接通（F6）
- **REQ-104a** `parser_ts.go` 在符号提取阶段填充 `Declarations`（C/C++ `declaration` 节点、Go `var_specifier`、Java `field_declaration`、Python 赋值/`def`）
- **REQ-104b** prescreener `declMap` 非空，`SafeCount` 反映真实 safe-variant 过滤
- **REQ-104c** `TestDeclarationExtraction` 转绿

### REQ-105: Go sink 同步（F5 子项）
- **REQ-105a** tree-sitter 路径 `knownLibFuncs` 已含 Go sink（确认）；单解析器后正则缺失自动消失

---

## 4. Design

### 4.1 单解析器架构（升级后）

```
源码 → tree-sitter CST（全平台，zig cc 交叉编译 CGO）
         ↓
      Symbols + Declarations + CallSites + Signals
         ↓
      CFG 构建（per-function，CST → BB 图）
         ↓
      AnalysisContext（含 cfg 字段）
```

### 4.2 CFG 构建算法（语言无关骨架）

```
buildCFG(funcNode):
  entry = newBB()
  current = entry
  for stmt in walkStatements(funcNode):
    switch stmt.kind:
      case If: 
        thenBB, elseBB, mergeBB = newBBs()
        current.succ += [thenBB(true), elseBB(false)]
        current = buildBlock(stmt.then, thenBB); current.succ += mergeBB(fallthrough)
        current = buildBlock(stmt.else, elseBB); current.succ += mergeBB(fallthrough)
        current = mergeBB
      case For/While:
        condBB, bodyBB, exitBB = newBBs()
        current.succ += condBB; condBB.succ += [bodyBB(true), exitBB(false)]
        buildBlock(stmt.body, bodyBB).succ += condBB  // back-edge
        current = exitBB
      case Return/Break/Continue/Throw:
        current.succ += exitEdge(type); current = newUnreachableBB()
      default:
        current.stmts += stmt
  return entry
```
语言适配层把 tree-sitter 节点 kind 映射到统一控制节点（如 C `if_statement`、Go `if_statement`、Python `if_statement` 都映射 `If`）。

### 4.3 支配树
按函数构建支配树：`Dom(entry)=entry`，`Dom(n) = {n} ∪ (∩ Dom(p) for p in preds(n))`，迭代至不动点。`Dominates(a,b)` = b ∈ Dom(a) 的支配者集合。规模可控（per-function，通常 <100 BB），迭代法足够。

### 4.4 CFG 作为 AI 证据源
检测器与 Investigator 不再"猜测"控制流，而是查询引擎事实：
- null_dereference：`Dominates(nullCheckBB, derefBB)` → 有缓解
- double-free：`IsReachable(freeBB1, freeBB2)` 且无中间 reinit → 可疑
- 这把 F7 Q3（"是否存在有效缓解"）从 LLM 自评转为引擎可校验（与 FEATURE-001 gate、FEATURE-003 Q-matrix 协同）

---

## 5. Risks & Constraints

| 风险 | 缓解 |
|------|------|
| zig 未安装，CI 需新增依赖 | zig 单二进制，CI 装 `chmod +x` 即可；本地 brew install zig |
| zig cc 交叉编译某平台失败 | 分平台验证；保留 `CGO_ENABLED=0` 正则回退作为**显式降级**（输出标注 `degraded:regex`）至 zig 全绿——但这是临时过渡，非终态 |
| CFG 构建对某语言控制结构遗漏 | 每语言单测 + fixture；CFG 缺口时该函数标记 `cfg_incomplete`，不静默 |
| CFG 增大 index.json 体积 | 仅记录 BB 的 stmt 行号 + succ 边，不存源码；必要时按需查询而非全量序列化 |
| 支配树算法复杂 | per-function 规模小，迭代法 O(n²) 足够；不引入 Lengauer-Tarjan 除非 profiling 要求 |

## 6. Out of Scope
- DFG/污点传播（依赖 CFG 先落地，后续 Feature）
- 检测器语义改写（CFG 作为新证据源接入，由 FEATURE-003 消费）
- 纯 Go tree-sitter 移植评估（未来 ADR，需 web 验证成熟度）
