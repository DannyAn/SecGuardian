# FEATURE-004: AnalysisContext CallSites Integration

> **对应 Task**: 1.4
> **文件**: `internal/context/context.go`
> **验证**: `go build ./...`

## 规格

在 `AnalysisContext` 中新增 `CallSites` 字段，使 Analyzer/Dispatcher 可直接访问调用点信号。

## 实现

```go
type AnalysisContext struct {
	Path            string              `json:"path"`
	FileCount       int                 `json:"file_count"`
	FunctionCount   int                 `json:"function_count"`
	CallEdgeCount   int                 `json:"call_edge_count"`
	PrimaryLanguage string              `json:"primary_language"`
	Files           []string            `json:"files"`
	Symbols         indexer.SymbolIndex `json:"symbols"`
	CallGraph       indexer.CallGraph   `json:"call_graph"`
	AllocFree       indexer.AllocFreeMap `json:"alloc_free"`
	LockGraph       indexer.LockGraph   `json:"lock_graph"`
	CallSites       []parser.CallSite   `json:"call_sites"`  // ← 新增
}
```

## 影响

| 文件 | 变更 |
|------|------|
| `internal/context/context.go` | 新增 `CallSites` 字段 |
| `internal/main.go` | 在 Phase 6 中将 parsed 中的 call_sites 聚合赋值给 ctx.CallSites |

## 约束

- `CallSites` 序列化为 JSON 时，空切片应为 `[]` 而非 `null`（在 main.go 聚合时初始化空切片）
- 不新增额外的验证/处理逻辑——只是数据传递
