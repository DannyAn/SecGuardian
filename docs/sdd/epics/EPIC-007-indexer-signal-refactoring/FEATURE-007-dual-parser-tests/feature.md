# FEATURE-007: Dual-Parser Consistency Tests

> **对应 Task**: 1.7
> **文件**: `internal/parser/parser_ts_test.go`, `internal/parser/parser_re_test.go`
> **验证**: `go test ./internal/parser/...`

## 规格

编写对比测试，验证 Tree-sitter 解析器（CGO 启用）和正则回退解析器（CGO 禁用）对同一源文件提取的 `call_sites` 一致。不一致的调用点以 Tree-sitter 为准，正则解析器需要修正。

## 实现

### 1. parser_re_test.go — 正则解析器单元测试

```go
// go:build !cgo

package parser

import (
	"os"
	"path/filepath"
	"testing"
)

func TestRegexCallSites(t *testing.T) {
	files := []string{
		"../../examples/cpp-vuln-demo/src/allocator.c",
		"../../examples/cpp-vuln-demo/src/system.c",
		"../../examples/cpp-vuln-demo/src/crypto.c",
		"../../examples/cpp-vuln-demo/src/concurrency.c",
		"../../examples/cpp-vuln-demo/src/network.c",
	}

	for _, f := range files {
		t.Run(filepath.Base(f), func(t *testing.T) {
			result, err := ParseFile(f, "c")
			if err != nil {
				t.Fatalf("ParseFile(%s) error: %v", f, err)
			}
			if len(result.CallSites) == 0 {
				t.Errorf("Expected at least 1 call_site in %s, got 0", f)
			}
			for _, cs := range result.CallSites {
				if cs.CalleeName == "" {
					t.Errorf("Empty callee name at line %d", cs.Line)
				}
				if cs.Category == "" {
					t.Errorf("Empty category for %s at line %d", cs.CalleeName, cs.Line)
				}
				if cs.Line == 0 {
					t.Errorf("Zero line number for %s", cs.CalleeName)
				}
			}
			t.Logf("%s: %d call_sites", filepath.Base(f), len(result.CallSites))
			for _, cs := range result.CallSites {
				t.Logf("  %s:%d: %s(%s) [%s safe=%v]",
					cs.CallerFunction, cs.Line, cs.CalleeName,
					joinArgs(cs.Arguments), cs.Category, cs.IsSafeVariant)
			}
		})
	}
}

func joinArgs(args []string) string {
	s := ""
	for i, a := range args {
		if i > 0 {
			s += ", "
		}
		s += a
	}
	return s
}

func TestRegexCallSiteEdgeCases(t *testing.T) {
	// Create a temp file with various call patterns
	content := []byte(`
void test() {
	strcpy(dst, src);
	strcpy_s(dst, sizeof(dst), src);  // safe variant
	memcpy(dst, src, n);
	memcpy_s(dst, sizeof(dst), src, n);
	malloc(1024);
	calloc(1, 1024);
	system("ls -la");
	// strcpy(comment_dst, comment_src);  // should NOT match
	pthread_mutex_lock(&m);
	pthread_mutex_unlock(&m);
}
`)

	tmpFile := filepath.Join(t.TempDir(), "test_edge.c")
	if err := os.WriteFile(tmpFile, content, 0644); err != nil {
		t.Fatal(err)
	}

	result, err := ParseFile(tmpFile, "c")
	if err != nil {
		t.Fatalf("ParseFile error: %v", err)
	}

	// Should have 9 call sites (comment line excluded)
	if len(result.CallSites) != 9 {
		t.Errorf("Expected 9 call_sites, got %d", len(result.CallSites))
		for _, cs := range result.CallSites {
			t.Logf("  %s:%d", cs.CalleeName, cs.Line)
		}
	}

	// Verify safe variant markers
	safeCount := 0
	for _, cs := range result.CallSites {
		if cs.IsSafeVariant {
			safeCount++
		}
	}
	if safeCount != 2 {
		t.Errorf("Expected 2 safe variants (strcpy_s, memcpy_s), got %d", safeCount)
	}
}
```

### 2. parser_ts_test.go — Tree-sitter 解析器测试（可选，占位）

```go
//go:build cgo

package parser

import (
	"testing"
)

func TestTsCallSites(t *testing.T) {
	// Run the same tests as regex to verify consistency
	TestRegexCallSites(t)
}
```

注意：由于 TestRegexCallSites 使用 `package parser`（非 `parser_test`），可以在 Tree-sitter 测试中复用。但 build tags 会导致冲突——需要确保两个测试文件有不同的 build tag。

更干净的方案：定义共享测试函数在一个无 build tag 的文件中（如 `parser_call_site_test.go`）：

```go
// parser_call_site_test.go — no build tag (used by both)
package parser

func verifyCallSiteConsistency(t *testing.T, tsResult, reResult *ParseResult) {
	tsMap := make(map[string]CallSite)
	for _, cs := range tsResult.CallSites {
		key := fmt.Sprintf("%s:%d:%s", cs.File, cs.Line, cs.CalleeName)
		tsMap[key] = cs
	}

	reMap := make(map[string]CallSite)
	for _, cs := range reResult.CallSites {
		key := fmt.Sprintf("%s:%d:%s", cs.File, cs.Line, cs.CalleeName)
		reMap[key] = cs
	}

	// Check Tree-sitter results are subset of regex results
	missing := 0
	for key, tsCS := range tsMap {
		if _, ok := reMap[key]; !ok {
			t.Logf("Regex missing call_site: %s:%d %s", tsCS.File, tsCS.Line, tsCS.CalleeName)
			missing++
		}
	}

	total := len(tsMap)
	if total > 0 {
		matchRate := float64(total-missing) / float64(total) * 100
		t.Logf("Consistency: %.1f%% (%d/%d match)", matchRate, total-missing, total)
		if matchRate < 95.0 {
			t.Errorf("Consistency below 95%%: %.1f%%", matchRate)
		}
	}
}
```

## 验证准则

| 场景 | 预期 | 说明 |
|------|------|------|
| 同一行多个调用 | 各自独立 CallSite | `strcpy(d, s); strcat(d, s);` → 2 个 |
| 注释中的函数名 | 不提取 | `// strcpy(...)` 排除 |
| 宏展开中的调用 | 不提取（当前限制） | 宏内 `STRCPY(d,s)` 可能被忽略 |
| 安全变体 _s | IsSafeVariant=true | `strcpy_s(` ✅ |
| 字符串参数 | Arguments 含原始内容 | `Arguments: ["\"hello\""]` |
| 嵌套调用 | 提取外层 | `memcpy(dst, src, strlen(src))` → 1 个 memcpy 条目 |

## 约束

- 一致性测试仅在 CGO=1（Tree-sitter 可用）时运行
- 不一致的 case 记录到 t.Log 而非 t.Error（容许小的分歧，但不高于 5%）
- 在 CI 中，`go test -tags cgo ./internal/parser/...` 和 `go test ./internal/parser/...` 都应通过
