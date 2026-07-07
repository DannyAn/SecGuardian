# FEATURE-005: Indexer JSON Output with call_sites

> **对应 Task**: 1.5
> **文件**: `internal/main.go`
> **验证**: `secguardian-index --path examples/cpp-vuln-demo --output /tmp/test.json && jq '.call_sites | length' /tmp/test.json`

## 规格

在 `main.go` 的 Phase 6 中，将所有解析结果的 `CallSites` 聚合到 `AnalysisContext.CallSites` 并输出到 index.json。

## 实现

### Phase 5.5: 聚合 CallSites（在 Phase 5 LockGraph 之后、Phase 6 之前）

```go
// Phase 5.5: Collect all call sites
allCallSites := make([]parser.CallSite, 0)
for _, result := range parsed {
	allCallSites = append(allCallSites, result.CallSites...)
}
fmt.Printf("  Call sites: %d\n", len(allCallSites))
```

### Phase 6: 写入 CallSites

```go
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
	CallSites:       allCallSites,  // ← 新增
}
```

## 输出示例

```json
{
  "call_sites": [
    {
      "caller": "alloc_entry",
      "callee": "malloc",
      "file": "examples/cpp-vuln-demo/src/allocator.c",
      "line": 28,
      "arguments": ["sizeof(AllocEntry)"],
      "safe_variant": false,
      "category": "memory"
    },
    {
      "caller": "execute_user_command",
      "callee": "snprintf",
      "file": "examples/cpp-vuln-demo/src/system.c",
      "line": 26,
      "arguments": ["cmd", "sizeof(cmd)", "\"grep '%s' /var/log/syslog\"", "user_input"],
      "safe_variant": false,
      "category": "string"
    },
    {
      "caller": "execute_user_command",
      "callee": "system",
      "file": "examples/cpp-vuln-demo/src/system.c",
      "line": 27,
      "arguments": ["cmd"],
      "safe_variant": false,
      "category": "exec"
    }
  ]
}
```

## 验证

```bash
go build -o /tmp/secguardian-index ./internal/
/tmp/secguardian-index --path examples/cpp-vuln-demo/src --output /tmp/test.json

# call_sites 数量验证
jq '.call_sites | length' /tmp/test.json

# safe_variant 验证（应该有 strcpy_s, memcpy_s 等）
jq '.call_sites[] | select(.safe_variant == true) | .callee' /tmp/test.json

# 类别分布
jq '[.call_sites[].category] | unique' /tmp/test.json

# 调用者/被调用者拓扑
jq '[.call_sites[] | {caller: .caller, callee: .callee, line: .line}] | unique_by(.line)' /tmp/test.json
```
