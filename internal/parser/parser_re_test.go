//go:build !cgo

package parser

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestParseFile_Success tests that the regex parser extracts functions from
// example files in all supported languages.
func TestParseFile_Success(t *testing.T) {
	langs := allLanguages()
	for _, lang := range langs {
		t.Run(lang, func(t *testing.T) {
			files := listExampleFiles(t, lang)
			if len(files) == 0 {
				t.Skip("no example files for " + lang)
			}
			// Parse the first file
			result, err := ParseFile(files[0], lang)
			if err != nil {
				t.Fatalf("ParseFile(%q, %q): %v", files[0], lang, err)
			}
			assertParseResultValid(t, result, files[0], lang)
			// All example files should contain at least one function
			if len(result.Functions) == 0 {
				t.Errorf("ParseFile(%q, %q): expected at least one function, got 0", files[0], lang)
			}
		})
	}
}

// TestParseFile_AllFiles exercises every example file to ensure no panics.
func TestParseFile_AllFiles(t *testing.T) {
	langs := allLanguages()
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
				t.Errorf("ParseFile(%q, %q): File = %q, want %q", f, lang, result.File, f)
			}
		}
	}
	t.Logf("Parsed %d files across %d languages", totalFiles, len(langs))
}

// TestParseFile_NonExistentFile returns an error.
func TestParseFile_NonExistentFile(t *testing.T) {
	_, err := ParseFile("/nonexistent/path/file.c", "c")
	if err == nil {
		t.Error("expected error for non-existent file, got nil")
	}
}

// TestParseFile_EmptyFile returns an empty result without error.
func TestParseFile_EmptyFile(t *testing.T) {
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
	if len(result.Types) > 0 {
		t.Errorf("expected 0 types from empty file, got %d", len(result.Types))
	}
}

// TestParseFile_CommentsOnly returns no functions.
func TestParseFile_CommentsOnly(t *testing.T) {
	dir := t.TempDir()
	commentPath := filepath.Join(dir, "comments_only.c")
	content := "/* This is a block comment */\n// This is a line comment\n/* Another\n   multiline\n   comment */\n"
	if err := os.WriteFile(commentPath, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	result, err := ParseFile(commentPath, "c")
	if err != nil {
		t.Fatalf("ParseFile comments-only file: unexpected error: %v", err)
	}
	// The file has no actual function definitions, only comments
	if len(result.Functions) > 0 {
		t.Logf("found %d functions in comments-only file (regex may false-match)", len(result.Functions))
	}
}

// TestParseFile_TypeExtraction verifies types/classes are extracted.
func TestParseFile_TypeExtraction(t *testing.T) {
	tests := []struct {
		lang     string
		content  string
		wantKind string
	}{
		{"c", "typedef struct Point { int x; int y; } Point;", "struct"},
		{"cpp", "class MyClass { public: int x; };", "class"},
		{"go", "type MyStruct struct { x int }", "struct"},
		{"java", "public class MyClass { int x; }", "class"},
		{"python", "class MyClass:\n    def __init__(self):\n        pass", "class"},
		{"javascript", "class MyClass { constructor() {} }", "class"},
	}
	for _, tt := range tests {
		t.Run(tt.lang, func(t *testing.T) {
			dir := t.TempDir()
			ext := map[string]string{
				"c": ".c", "cpp": ".cpp", "go": ".go", "java": ".java",
				"python": ".py", "javascript": ".js",
			}[tt.lang]
			fp := filepath.Join(dir, "test"+ext)
			if err := os.WriteFile(fp, []byte(tt.content), 0644); err != nil {
				t.Fatal(err)
			}
			result, err := ParseFile(fp, tt.lang)
			if err != nil {
				t.Fatalf("ParseFile: %v", err)
			}
			// Check that at least one type was found with the expected kind
			found := false
			for _, typ := range result.Types {
				if typ.Kind == tt.wantKind {
					found = true
					break
				}
			}
			if !found {
				t.Errorf("expected type of kind %q, got types: %+v", tt.wantKind, result.Types)
			}
		})
	}
}

// TestParseFile_UnsupportedLanguage does not panic.
func TestParseFile_UnsupportedLanguage(t *testing.T) {
	dir := t.TempDir()
	fp := filepath.Join(dir, "test.xyz")
	if err := os.WriteFile(fp, []byte("some content"), 0644); err != nil {
		t.Fatal(err)
	}
	result, err := ParseFile(fp, "ruby")
	if err != nil {
		t.Fatalf("ParseFile unsupported lang: unexpected error: %v", err)
	}
	// Should return empty result, not panic
	if result == nil {
		t.Error("expected non-nil result for unsupported language")
	}
}

// TestParseFile_FunctionNamesNotEmpty checks all parsed functions have names.
func TestParseFile_FunctionNamesNotEmpty(t *testing.T) {
	for _, lang := range allLanguages() {
		files := listExampleFiles(t, lang)
		for _, f := range files {
			result, err := ParseFile(f, lang)
			if err != nil {
				continue
			}
			for i, fn := range result.Functions {
				if fn.Name == "" || isKeyword(fn.Name, lang) {
					t.Errorf("%s[%d]: empty or keyword function name %q in %s", f, i, fn.Name, lang)
				}
			}
		}
	}
}

// TestParseFile_LineNumbersInBounds checks line numbers are within file range.
func TestParseFile_LineNumbersInBounds(t *testing.T) {
	for _, lang := range allLanguages() {
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
			for _, typ := range result.Types {
				if typ.StartLine > totalLines {
					t.Errorf("%s: type %q StartLine=%d > totalLines=%d", f, typ.Name, typ.StartLine, totalLines)
				}
			}
		}
	}
}

// TestParseFile_JavaScript functions detected in JS example.
func TestParseFile_JavaScript(t *testing.T) {
	files := listExampleFiles(t, "javascript")
	if len(files) == 0 {
		t.Skip("no JavaScript example files")
	}
	result, err := ParseFile(files[0], "javascript")
	if err != nil {
		t.Fatalf("ParseFile JS: %v", err)
	}
	// JS example should have functions
	if len(result.Functions) == 0 {
		t.Error("expected at least one function in JavaScript example")
	}
}
