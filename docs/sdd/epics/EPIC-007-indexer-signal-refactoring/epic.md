# EPIC-007: Indexer Signal Refactoring — From Symbol Table to Call-Site Signal Graph

> **状态**: Active
> **创建**: 2026-07-07
> **目标版本**: v0.18.0
> **Spec 来源**: `docs/sdd/req=20260707.md` §2.1 (EPIC-1)

## 动机

当前索引器产出与检测器消费完全脱节。`symbols.functions` 只记录函数定义（如 `idm_access_token_init`），不记录函数体内的库函数调用。检测器预筛在符号表中查找 `strcpy`/`malloc` 等 API 名称时永远找不到，导致所有检测器被跳过，系统在生产仓库上产出 0 发现。

**修复索引器是架构重构的前置条件**。没有 `call_sites`，后续的 Dispatcher-Worker 范式（EPIC-2/3）无从调度。本 EPIC 的目标是将索引器从"符号表"升级为"调用点信号图"，为每个 Worker 提供精准的聚焦信号。

## 范围

| 包含 | 不包含 |
|------|--------|
| `CallSite` 数据结构定义 (types.go) | Skill 体系建设 (EPIC-2) |
| Tree-sitter call_expression 提取 | Dispatcher 协议重写 (EPIC-3) |
| 正则回退解析器调用点提取 | 基准测试集 (EPIC-4) |
| AnalysisContext 集成 CallSites | 非 C/C++ 语言的 call_sites 深度覆盖 |
| index.json 输出 call_sites | 全量 CFG/DFG/SSA 数据流分析 |
| 调用图重构为基于 call_sites | Windows 内核驱动特有函数支持 |
| 双解析器一致性测试 | 性能优化（当前先正确，再优化） |

## 设计决策

### D1: CallSite 只覆盖 C/C++ 库函数，不覆盖跨语言泛库

**决策**: C/C++ 场景（idm 仓库）是首次生产验证目标。Python/Java/Go/JS 的调用点提取延后到 EPIC-2 阶段。

**理由**: 67 个 guard-rule 中 C/C++ 占绝大多数（43 个）。Python 等语言的漏洞模式更多是逻辑/配置类，信号聚焦收益低。

### D2: `_s` 安全变体标记为 `IsSafeVariant=true`，不跳过

**决策**: 安全变体（`strcpy_s`、`memcpy_s`）在 `CallSite` 中标记 `IsSafeVariant=true`，仍然作为信号发出。Worker 对其执行**参数审计**而非跳过。

**理由**: 灵码验证了 `_s` 函数同样存在误用风险（dsize != sizeof(dst)、dst 是指针而非数组）。当前知识库错误地排除了 `_s` 变体，导致 `_s` 密集代码库 100% 免疫检测。

### D3: 调用图也纳入库函数调用边

**决策**: `BuildCallGraphV2` 不再限制只匹配用户自定义函数间的调用。库函数调用也作为边加入调用图。

**理由**: 当前调用图只有 5 条边（仅用户函数间），无法追踪数据流。纳入库函数后，对 idm 仓库预期边数 ≥ 3000，Worker 可利用调用图进行浅层数据流追踪。

### D4: 两个解析器对同一文件产出相同 call_sites 是硬约束

**决策**: Task 1.7 需要对比测试验证 Tree-sitter 和正则解析器的输出一致性。不一致的调用点以 Tree-sitter 为准，正则解析器需要修正。

**理由**: CI 环境部分场景没有 CGO（禁用 Tree-sitter），必须依赖正则回退。两个解析器产出不同 call_sites 会导致 Worker 行为不一致。

## 数据流

```
源文件 (.c/.cpp)
    │
    ├── Tree-sitter (CGO enabled)
    │   ├── walkTopLevel → function_definition
    │   │   └── 对 body 遍历 call_expression
    │   │       ├── function → callee name
    │   │       └── argument_list → args
    │   └── 分类: memory/string/io/exec/sync/crypto
    │
    └── 正则回退 (CGO disabled)
        ├── 对每行匹配 callSitePatterns
        └── 分类: 同 Tree-sitter
            │
            ▼
    ParseResult.CallSites ([]CallSite)
            │
            ▼
    indexer.BuildCallGraphV2(callSites, symbols)
            │
            ▼
    AnalysisContext {
        CallSites:   []CallSite     ← 新增
        CallGraph:   CallGraph      ← 基于 call_sites 重建
        Symbols:     SymbolIndex
        AllocFree:   AllocFreeMap
        LockGraph:   LockGraph
    }
            │
            ▼
    index.json {
        "call_sites": [...]          ← 新增
        "call_graph": {"edges": [...]}
        ...
    }
```

## 验收标准

| 指标 | 当前值 | 目标值 | 验证方法 |
|------|--------|--------|---------|
| `call_sites` 数量 | 0 | ≥ 30 (cpp-vuln-demo) | `jq '.call_sites \| length' index.json` |
| 调用图边数 | 5 | ≥ 200 (cpp-vuln-demo) | `jq '.call_graph.edges \| length' index.json` |
| 调用图边数 | — | ≥ 3000 (idm 仓库) | `jq '.call_graph.edges \| length' index.json` |
| safe_variant 标记 | — | 所有 _s 调用正确标记 | `jq '.call_sites[] \| select(.safe_variant==true) \| length'` |
| 双解析器一致性 | — | 同一文件 ≥ 95% 调用点匹配 | `go test ./internal/parser/...` |
| nil panic | 有风险 | 0 | 全部 `node.Child(i) != nil` 守卫 |

## 任务拆解

| Task | 文件 | 内容 | 验证命令 |
|------|------|------|---------|
| 1.1 | `internal/parser/types.go` | 新增 CallSite 结构体 + ParseResult.CallSites 字段 | `go build ./...` |
| 1.2 | `internal/parser/parser_ts.go` | walkTopLevel 提取 call_expression 节点 | `go test -tags cgo ./internal/parser/...` |
| 1.3 | `internal/parser/parser_re.go` | 正则模式提取调用点 | `go test ./internal/parser/...` |
| 1.4 | `internal/context/context.go` | AnalysisContext 新增 CallSites 字段 | `go build ./...` |
| 1.5 | `internal/main.go` | index.json 输出 call_sites | `secguardian-index --path examples/cpp-vuln-demo --output /tmp/test.json && jq '.call_sites \| length' /tmp/test.json` |
| 1.6 | `internal/indexer/indexer.go` | BuildCallGraphV2 基于 call_sites | 验证边数 ≥ 预期 |
| 1.7 | `internal/parser/parser_ts_test.go`, `parser_re_test.go` | 双解析器一致性测试 | `go test ./internal/parser/...` |

## 相关文档

- `docs/sdd/req=20260707.md` §2.1 — EPIC-1 完整规格
- `docs/sdd/req=20260707.md` §3.1 — Phase 1 任务拆解
- `docs/sdd/req=20260707.md` §4.1-4.5 — 关键设计决策
