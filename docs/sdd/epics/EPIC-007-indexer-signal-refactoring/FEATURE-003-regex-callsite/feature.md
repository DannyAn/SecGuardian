# FEATURE-003: Regex Fallback Call-Site Extraction

> **对应 Task**: 1.3
> **文件**: `internal/parser/parser_re.go`
> **验证**: `go test ./internal/parser/...`

## 规格

在 `parser_re.go` 中新增正则模式，用于 CGO 禁用时回退提取调用点。使用预定义的模式列表匹配库函数调用，模式与 `knownLibFuncs` 一一对应。

## 实现

### 1. 新增调用点模式列表

```go
var callSitePatterns = []struct {
	name     string
	pattern  string
	isSafe   bool
	category string
}{
	// String operations
	{"strcpy",   `\bstrcpy\s*\(`, false, "string"},
	{"strcpy_s", `\bstrcpy_s\s*\(`, true, "string"},
	{"strcat",   `\bstrcat\s*\(`, false, "string"},
	{"strcat_s", `\bstrcat_s\s*\(`, true, "string"},
	{"sprintf",  `\bsprintf\s*\(`, false, "string"},
	{"sprintf_s", `\bsprintf_s\s*\(`, true, "string"},
	{"snprintf", `\bsnprintf\s*\(`, false, "string"},
	{"gets",     `\bgets\s*\(`, false, "string"},
	{"gets_s",   `\bgets_s\s*\(`, true, "string"},

	// Memory operations
	{"memcpy",   `\bmemcpy\s*\(`, false, "memory"},
	{"memcpy_s", `\bmemcpy_s\s*\(`, true, "memory"},
	{"memmove",  `\bmemmove\s*\(`, false, "memory"},
	{"memmove_s", `\bmemmove_s\s*\(`, true, "memory"},
	{"malloc",   `\bmalloc\s*\(`, false, "memory"},
	{"calloc",   `\bcalloc\s*\(`, false, "memory"},
	{"realloc",  `\brealloc\s*\(`, false, "memory"},
	{"free",     `\bfree\s*\(`, false, "memory"},

	// I/O operations
	{"fopen",   `\bfopen\s*\(`, false, "io"},
	{"fclose",  `\bfclose\s*\(`, false, "io"},
	{"open",    `\bopen\s*\(`, false, "io"},
	{"close",   `\bclose\s*\(`, false, "io"},
	{"tmpfile", `\btmpfile\s*\(`, false, "io"},
	{"socket",  `\bsocket\s*\(`, false, "io"},

	// Execution
	{"system", `\bsystem\s*\(`, false, "exec"},
	{"popen",  `\bpopen\s*\(`, false, "exec"},
	{"getenv", `\bgetenv\s*\(`, false, "exec"},

	// Sync
	{"pthread_mutex_lock",   `\bpthread_mutex_lock\s*\(`, false, "sync"},
	{"pthread_mutex_unlock", `\bpthread_mutex_unlock\s*\(`, false, "sync"},

	// Crypto
	{"RAND_bytes",             `\bRAND_bytes\s*\(`, false, "crypto"},
	{"DES_set_key_unchecked",  `\bDES_set_key_unchecked\s*\(`, false, "crypto"},
}
```

### 2. ParseFile 中新增调用点提取

在文件末尾（variables 提取之后），对 C/C++ 语言添加：

```go
// Extract call sites (C/C++ only in this phase)
if lang == "c" || lang == "cpp" {
	lines := strings.Split(string(content), "\n")
	for lineIdx, line := range lines {
		if isCommentLine(line) { // reuse existing helper, or inline check
			continue
		}
		for _, cp := range callSitePatterns {
			re := regexp.MustCompile(cp.pattern)
			locs := re.FindAllStringIndex(line, -1)
			for _, loc := range locs {
				// Find caller: look upward for nearest enclosing function
				caller := findEnclosingFunction(lineIdx+1, result.Functions)
				// Extract arguments (between parentheses)
				args := extractArgs(line[loc[1]:])

				result.CallSites = append(result.CallSites, CallSite{
					CallerFunction: caller,
					CalleeName:     cp.name,
					File:           filePath,
					Line:           uint(lineIdx + 1),
					Arguments:      args,
					IsSafeVariant:  cp.isSafe,
					Category:       cp.category,
				})
			}
		}
	}
}
```

### 3. 辅助函数

```go
// findEnclosingFunction returns the function name that contains the given line.
// Relies on previously extracted FunctionInfo (start_line, end_line).
func findEnclosingFunction(line uint, functions []FunctionInfo) string {
	for _, fn := range functions {
		if line >= fn.StartLine && line <= fn.EndLine {
			return fn.Name
		}
	}
	return ""
}

// extractArgs extracts comma-separated arguments from after call site pattern match.
// Takes the substring starting after '(' and reads until matching ')'.
func extractArgs(s string) []string {
	depth := 0
	var args []string
	var current strings.Builder
	inParen := false

	for i := 0; i < len(s); i++ {
		ch := s[i]
		switch {
		case ch == '(' && !inParen:
			inParen = true
		case ch == '(' && inParen:
			depth++
			current.WriteByte(ch)
		case ch == ')' && depth == 0:
			if current.Len() > 0 {
				arg := strings.TrimSpace(current.String())
				if len(arg) > 128 {
					arg = arg[:128] + "..."
				}
				args = append(args, arg)
			}
			return args
		case ch == ')' && depth > 0:
			depth--
			current.WriteByte(ch)
		case ch == ',' && depth == 0:
			arg := strings.TrimSpace(current.String())
			if len(arg) > 128 {
				arg = arg[:128] + "..."
			}
			args = append(args, arg)
			current.Reset()
		case inParen:
			current.WriteByte(ch)
		}
	}
	return args
}
```

### 4. isCommentLine 辅助

```go
func isCommentLine(line string) bool {
	trimmed := strings.TrimSpace(line)
	return strings.HasPrefix(trimmed, "//") || strings.HasPrefix(trimmed, "/*") ||
		strings.HasPrefix(trimmed, "*") || strings.HasPrefix(trimmed, "#")
}
```

注意：`isCommentLine` 在 `indexer/indexer.go` 中有同名函数。为避免重复定义，要么从 `parser_re.go` 中导出（首字母大写），要么在 `parser` 包内定义小写版本。建议在 `parser_re.go` 中定义小写版本，因为当前只有 `parser_re.go` 使用（CGO 禁用时调用），且与 `indexer` 包无依赖关系。

## 约束

- 正则解析只对 C/C++ 启用，其他语言在本阶段不提取 call_sites
- 注释/字符串内的函数前缀匹配要通过 `isCommentLine` 排除（但注意：字符串内的 `strcpy(` 等也可能是真实调用模式—在 ELF 注入式中—但 C/C++ 代码中极少）
- 同一行多个匹配（如 `strcpy(d1, s); strcpy(d2, s)`）应分别产生 CallSite 条目
