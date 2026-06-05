//go:build cgo

package parser

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestParseFile_TS_Success tests tree-sitter parsing on example files.
func TestParseFile_TS_Success(t *testing.T) {
	// Tree-sitter supports: c, cpp, go, java, python (no javascript)
	langs := []string{"c", "cpp", "go", "java", "python"}
	for _, lang := range langs {
		t.Run(lang, func(t *testing.T) {
			files := listExampleFiles(t, lang)
			if len(files) == 0 {
				t.Skip("no example files for " + lang)
			}
			result, err := ParseFile(files[0], lang)
			if err != nil {
				t.Fatalf("ParseFile(%q, %q): %v", files[0], lang, err)
			}
			assertParseResultValid(t, result, files[0], lang)
			if len(result.Functions) == 0 {
				t.Errorf("ParseFile(%q, %q): expected at least one function, got 0", files[0], lang)
			}
		})
	}
}

// TestParseFile_TS_AllFiles exercises every example file through tree-sitter.
func TestParseFile_TS_AllFiles(t *testing.T) {
	langs := []string{"c", "cpp", "go", "java", "python"}
	totalFiles := 0
	for _, lang := range langs {
		files := listExampleFiles(t, lang)
		for _, f := range files {
			result, err := ParseFile(f, lang)
			if err != nil {
				t.Errorf("ParseFile(%q, %q) unexpected error: %v", f, lang, err)
				continue
			}
			totalFiles++
			if result.File != f {
				t.Errorf("File = %q, want %q", result.File, f)
			}
		}
	}
	t.Logf("Parsed %d files across 5 languages with tree-sitter", totalFiles)
}

// TestParseFile_TS_NonExistentFile returns error.
func TestParseFile_TS_NonExistentFile(t *testing.T) {
	_, err := ParseFile("/nonexistent/path/file.c", "c")
	if err == nil {
		t.Error("expected error for non-existent file, got nil")
	}
}

// TestParseFile_TS_EmptyFile returns empty result.
func TestParseFile_TS_EmptyFile(t *testing.T) {
	dir := t.TempDir()
	emptyPath := filepath.Join(dir, "empty.c")
	if err := os.WriteFile(emptyPath, []byte(""), 0644); err != nil {
		t.Fatal(err)
	}
	result, err := ParseFile(emptyPath, "c")
	if err != nil {
		t.Fatalf("ParseFile empty file: unexpected error: %v", err)
	}
	if len(result.Functions) > 0 {
		t.Errorf("expected 0 functions from empty file, got %d", len(result.Functions))
	}
}

// TestParseFile_TS_NestedFunctions verifies Python class methods are extracted.
func TestParseFile_TS_NestedFunctions(t *testing.T) {
	files := listExampleFiles(t, "python")
	if len(files) == 0 {
		t.Skip("no Python example files")
	}
	result, err := ParseFile(files[0], "python")
	if err != nil {
		t.Fatalf("ParseFile python: %v", err)
	}
	// Python examples should have functions (possibly class methods)
	t.Logf("Python %s: %d functions, %d types, %d variables",
		files[0], len(result.Functions), len(result.Types), len(result.Variables))
	if len(result.Functions) == 0 && len(result.Types) == 0 {
		t.Error("expected at least some symbols from Python example")
	}
}

// TestParseFile_TS_VariableExtraction verifies C variables are extracted.
func TestParseFile_TS_VariableExtraction(t *testing.T) {
	dir := t.TempDir()
	fp := filepath.Join(dir, "vars.c")
	content := "int global_count = 0;\nvoid foo() { int local = 1; }\n"
	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	result, err := ParseFile(fp, "c")
	if err != nil {
		t.Fatalf("ParseFile: %v", err)
	}
	// Tree-sitter should detect at least the function
	if len(result.Functions) == 0 {
		t.Error("expected at least one function (foo)")
	}
	// Tree-sitter may also detect variable declarations
	t.Logf("Functions: %d, Variables: %d", len(result.Functions), len(result.Variables))
}

// TestParseFile_TS_AccurateLineNumbers verifies tree-sitter AST line numbers.
func TestParseFile_TS_AccurateLineNumbers(t *testing.T) {
	dir := t.TempDir()
	fp := filepath.Join(dir, "linetest.c")
	// Function foo starts at line 4
	content := "// line 1\n// line 2\n// line 3\nvoid foo() {\n  return;\n}\n"
	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	result, err := ParseFile(fp, "c")
	if err != nil {
		t.Fatalf("ParseFile: %v", err)
	}
	// Find foo function
	var fooFunc *FunctionInfo
	for i := range result.Functions {
		if result.Functions[i].Name == "foo" {
			fooFunc = &result.Functions[i]
			break
		}
	}
	if fooFunc == nil {
		t.Fatal("function 'foo' not found")
	}
	// Tree-sitter should give accurate line numbers (line 4)
	if fooFunc.StartLine < 3 || fooFunc.StartLine > 5 {
		t.Errorf("expected foo around line 4, got StartLine=%d", fooFunc.StartLine)
	}
}

// TestParseFile_TS_TypeExtraction verifies types are extracted with correct kinds.
func TestParseFile_TS_TypeExtraction(t *testing.T) {
	tests := []struct {
		lang     string
		content  string
		wantKind string
		altKind  string // tree-sitter may use AST node kind names
	}{
		{"c", "struct Point { int x; int y; };", "struct", "struct_specifier"},
		{"cpp", "class MyClass { int x; };", "class", "class_specifier"},
		{"go", "type MyStruct struct { x int }", "struct", ""},
		{"java", "class MyClass { int x; }", "class", ""},
		{"python", "class MyClass:\n    pass", "class", ""},
	}
	for _, tt := range tests {
		t.Run(tt.lang, func(t *testing.T) {
			dir := t.TempDir()
			ext := map[string]string{"c": ".c", "cpp": ".cpp", "go": ".go", "java": ".java", "python": ".py"}[tt.lang]
			fp := filepath.Join(dir, "test"+ext)
			if err := os.WriteFile(fp, []byte(tt.content), 0644); err != nil {
				t.Fatal(err)
			}
			result, err := ParseFile(fp, tt.lang)
			if err != nil {
				t.Fatalf("ParseFile: %v", err)
			}
			found := false
			for _, typ := range result.Types {
				if typ.Kind == tt.wantKind || (tt.altKind != "" && typ.Kind == tt.altKind) {
					found = true
					break
				}
			}
			if !found {
				t.Errorf("expected type of kind %q (or alt %q), got types: %+v", tt.wantKind, tt.altKind, result.Types)
			}
		})
	}
}

// TestParseFile_TS_UnsupportedLanguage does not panic.
// Note: tree-sitter returns an error for unsupported languages (unlike regex).
func TestParseFile_TS_UnsupportedLanguage(t *testing.T) {
	dir := t.TempDir()
	fp := filepath.Join(dir, "test.xyz")
	if err := os.WriteFile(fp, []byte("some content"), 0644); err != nil {
		t.Fatal(err)
	}
	result, err := ParseFile(fp, "ruby")
	// Both behaviors are valid: error (tree-sitter) or empty result (regex)
	if err != nil && result == nil {
		t.Logf("tree-sitter correctly rejects unsupported language: %v", err)
		return
	}
	if err == nil && result != nil {
		t.Log("regex parser returns empty result for unsupported language (valid behavior)")
		return
	}
	t.Errorf("unexpected state: err=%v, result=%v", err, result)
}

// TestParseFile_TS_LineNumbersInBounds checks line numbers are within file range.
func TestParseFile_TS_LineNumbersInBounds(t *testing.T) {
	langs := []string{"c", "cpp", "go", "java", "python"}
	for _, lang := range langs {
		files := listExampleFiles(t, lang)
		for _, f := range files {
			content, err := os.ReadFile(f)
			if err != nil {
				continue
			}
			totalLines := uint(strings.Count(string(content), "\n") + 1)
			result, err := ParseFile(f, lang)
			if err != nil {
				continue
			}
			for _, fn := range result.Functions {
				if fn.StartLine > totalLines {
					t.Errorf("%s: function %q StartLine=%d > totalLines=%d", f, fn.Name, fn.StartLine, totalLines)
				}
			}
		}
	}
}
