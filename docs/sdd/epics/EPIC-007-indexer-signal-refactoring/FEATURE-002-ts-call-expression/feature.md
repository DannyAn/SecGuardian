# FEATURE-002: Tree-sitter call_expression Extraction

> **对应 Task**: 1.2
> **文件**: `internal/parser/parser_ts.go`
> **验证**: `go test -tags cgo ./internal/parser/...`

## 规格

在 `walkTopLevel` 中对 C/C++ `function_definition` 分支，提取函数体内的 `call_expression` 子节点：

```
function_definition
└── body (compound_statement)
    └── expression_statement
        └── call_expression          ← 提取此节点
            ├── function            ← callee 名称（identifier 或 field_expression）
            └── argument_list       ← 参数摘要
```

## 实现

### 1. 新增库函数识别集合

```go
type libFuncEntry struct {
	name        string
	safeVariant string // "" if no safe variant exists
	isSafe      bool
	category    string
}

var knownLibFuncs = map[string]libFuncEntry{
	// String operations
	"strcpy":   {"strcpy", "strcpy_s", false, "string"},
	"strcpy_s": {"strcpy_s", "", true, "string"},
	"strcat":   {"strcat", "strcat_s", false, "string"},
	"strcat_s": {"strcat_s", "", true, "string"},
	"sprintf":  {"sprintf", "sprintf_s", false, "string"},
	"sprintf_s":{"sprintf_s", "", true, "string"},
	"snprintf": {"snprintf", "", false, "string"},
	"gets":     {"gets", "gets_s", false, "string"},
	"gets_s":   {"gets_s", "", true, "string"},

	// Memory operations
	"memcpy":   {"memcpy", "memcpy_s", false, "memory"},
	"memcpy_s": {"memcpy_s", "", true, "memory"},
	"memmove":  {"memmove", "memmove_s", false, "memory"},
	"memmove_s":{"memmove_s", "", true, "memory"},
	"malloc":   {"malloc", "", false, "memory"},
	"calloc":   {"calloc", "", false, "memory"},
	"realloc":  {"realloc", "", false, "memory"},
	"free":     {"free", "", false, "memory"},

	// I/O operations
	"fopen":    {"fopen", "fopen_s", false, "io"},
	"fclose":   {"fclose", "", false, "io"},
	"open":     {"open", "", false, "io"},
	"close":    {"close", "", false, "io"},
	"tmpfile":  {"tmpfile", "tmpfile_s", false, "io"},
	"socket":   {"socket", "", false, "io"},

	// Execution
	"system": {"system", "", false, "exec"},
	"popen":  {"popen", "", false, "exec"},
	"getenv": {"getenv", "", false, "exec"},

	// Sync
	"pthread_mutex_lock":   {"pthread_mutex_lock", "", false, "sync"},
	"pthread_mutex_unlock": {"pthread_mutex_unlock", "", false, "sync"},

	// Crypto
	"RAND_bytes": {"RAND_bytes", "", false, "crypto"},
	"DES_set_key_unchecked": {"DES_set_key_unchecked", "", false, "crypto"},
}
```

### 2. 新增 extractCallSites 函数

```go
func extractCallSites(body *treesitter.Node, content []byte, callerName, file string) []CallSite {
	var sites []CallSite
	for i := uint(0); i < body.ChildCount(); i++ {
		child := body.Child(i)
		if child == nil {
			continue
		}
		extractCallExpr(child, content, callerName, file, &sites)
	}
	return sites
}

func extractCallExpr(node *treesitter.Node, content []byte, callerName, file string, sites *[]CallSite) {
	for i := uint(0); i < node.ChildCount(); i++ {
		child := node.Child(i)
		if child == nil {
			continue
		}
		if child.Kind() == "call_expression" {
			cs := parseCallExpr(child, content, callerName, file)
			if cs != nil {
				*sites = append(*sites, *cs)
			}
		}
		extractCallExpr(child, content, callerName, file, sites)
	}
}
```

### 3. 新增 parseCallExpr

```go
func parseCallExpr(node *treesitter.Node, content []byte, callerName, file string) *CallSite {
	// First child should be the function identifier
	fnNode := node.Child(0)
	if fnNode == nil {
		return nil
	}
	callee := safeText(content, fnNode.StartByte(), fnNode.EndByte())
	entry, ok := knownLibFuncs[callee]
	if !ok {
		return nil // not a known library function
	}

	// Second child is argument_list
	argNode := node.Child(1)
	var args []string
	if argNode != nil && argNode.Kind() == "argument_list" {
		for j := uint(0); j < argNode.ChildCount(); j++ {
			sub := argNode.Child(j)
			if sub == nil {
				continue
			}
			argText := safeText(content, sub.StartByte(), sub.EndByte())
			if len(argText) > 128 {
				argText = argText[:128] + "..."
			}
			args = append(args, argText)
		}
	}

	return &CallSite{
		CallerFunction: callerName,
		CalleeName:     callee,
		File:           file,
		Line:           node.StartPosition().Row + 1,
		Arguments:      args,
		IsSafeVariant:  entry.isSafe,
		Category:       entry.category,
	}
}
```

### 4. walkTopLevel 集成

在 `function_definition` 的 `case` 分支中，获取 body 后调用 `extractCallSites`：

```go
case "function_definition":
	if fn := extractIdent(child, content, file, "function_declarator"); fn.Name != "" {
		fn.StartLine = child.StartPosition().Row + 1
		fn.EndLine = child.EndPosition().Row + 1
		result.Functions = append(result.Functions, fn)
		// 新增：提取函数体内的库函数调用
		body := findBody(child)
		if body != nil {
			result.CallSites = append(result.CallSites, extractCallSites(body, content, fn.Name, file)...)
		}
	}
```

### 5. 辅助函数 findBody

```go
func findBody(node *treesitter.Node) *treesitter.Node {
	for i := uint(0); i < node.ChildCount(); i++ {
		child := node.Child(i)
		if child == nil {
			continue
		}
		if child.Kind() == "compound_statement" || child.Kind() == "body" {
			return child
		}
	}
	return nil
}
```

## nil 守卫检查清单

| 位置 | 检查 |
|------|------|
| `extractCallExpr` | `node.Child(i)` 后每次 nil 检查 |
| `parseCallExpr` | `node.Child(0)`, `node.Child(1)` 后 nil 检查 |
| `findBody` | `node.Child(i)` 后 nil 检查 |

## 验证

```bash
# 对 cpp-vuln-demo 文件测试 Tree-sitter 解析
go test -tags cgo -run TestCallSites ./internal/parser/...
# 单文件手动验证
go run ./internal/main.go --path examples/cpp-vuln-demo/src --output /tmp/index.json
# 检查 call_sites >= 30
jq '.call_sites | length' /tmp/index.json
```
