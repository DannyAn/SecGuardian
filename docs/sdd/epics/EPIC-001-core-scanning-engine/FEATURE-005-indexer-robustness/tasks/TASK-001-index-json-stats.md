# TASK-001: index.json 增加聚合统计字段

> **Feature**: FEATURE-005 (Indexer Robustness)
> **REQ**: REQ-004
> **ADR**: ADR-003

## Goal

`secguardian-index` 输出的 `index.json` 顶层增加 4 个聚合字段，使 AI Agent 无需写 Python 解析就能直接获取扫描统计：

```json
{
  "file_count": 225,
  "function_count": 392,
  "call_edge_count": 1213,
  "primary_language": "java",
  "path": "./src",
  "files": [...]
}
```

## Done

- [ ] `internal/context/context.go`: 在 `AnalysisContext` struct 增加 `FileCount`、`FunctionCount`、`CallEdgeCount`、`PrimaryLanguage` 四个字段，带 json tag
- [ ] `internal/main.go`: 在 Phase 6 组装 context 前计算并赋值四个字段
- [ ] Go build 通过
- [ ] 对 Java 示例项目验证 index.json 包含新字段

## Files Changed

### internal/context/context.go

在 `AnalysisContext` struct 中新增 4 个字段，位置在 `Path` 之后、`Files` 之前：

```go
type AnalysisContext struct {
    Path             string              `json:"path"`
    FileCount        int                 `json:"file_count"`
    FunctionCount    int                 `json:"function_count"`
    CallEdgeCount    int                 `json:"call_edge_count"`
    PrimaryLanguage  string              `json:"primary_language"`
    Files            []string            `json:"files"`
    Symbols          indexer.SymbolIndex `json:"symbols"`
    CallGraph        indexer.CallGraph   `json:"call_graph"`
    AllocFree        indexer.AllocFreeMap `json:"alloc_free"`
    LockGraph        indexer.LockGraph   `json:"lock_graph"`
}
```

### internal/main.go

在 Phase 6（line 105~118 附近）组装 `ctx` 之前加入计算：

```go
// Phase 6: Assemble and write context
primaryLang := *langFlag
if primaryLang == "auto" {
    // Detect primary language from file extensions
    extCount := make(map[string]int)
    for _, f := range files {
        ext := filepath.Ext(f)
        // map extension to language name (reuse detectLanguage logic)
        extCount[detectLanguage(f, "auto")]++
    }
    // Pick the most frequent language
    maxCount := 0
    for lang, count := range extCount {
        if count > maxCount {
            maxCount = count
            primaryLang = lang
        }
    }
    if primaryLang == "auto" {
        primaryLang = "c" // fallback
    }
}

ctx := context.AnalysisContext{
    Path:            *pathFlag,
    FileCount:       len(files),
    FunctionCount:   len(symbols.Functions),
    CallEdgeCount:   len(cg.Edges),
    PrimaryLanguage: primaryLang,
    Files:           files,
    Symbols:         symbols,
    CallGraph:       cg,
    AllocFree:       af,
    LockGraph:       lg,
}
```

## Verification

```bash
# Build + verify
cd /Users/kongan/workbench/github/secguardian
go build ./...
go run . --path examples/java-vuln-demo --output /tmp/task001-index.json

# Check new fields exist
python3 -c "
import json
d = json.load(open('/tmp/task001-index.json'))
assert 'file_count' in d, 'Missing file_count'
assert 'function_count' in d, 'Missing function_count'
assert 'call_edge_count' in d, 'Missing call_edge_count'
assert 'primary_language' in d, 'Missing primary_language'
assert d['file_count'] > 0, f'file_count should be > 0, got {d[\"file_count\"]}'
assert d['function_count'] > 0, f'function_count should be > 0, got {d[\"function_count\"]}'
print(f'✅ file_count={d[\"file_count\"]}')
print(f'✅ function_count={d[\"function_count\"]}')
print(f'✅ call_edge_count={d[\"call_edge_count\"]}')
print(f'✅ primary_language={d[\"primary_language\"]}')

# Check compatibility: old fields still present
assert 'path' in d
assert 'files' in d
assert 'symbols' in d
assert 'call_graph' in d
print('✅ Backward compatible — all old fields present')
"

# Go test
go test ./internal/... 2>&1 | tail -5
```
