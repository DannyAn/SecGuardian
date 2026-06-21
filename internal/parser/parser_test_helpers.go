package parser

import (
	"os"
	"path/filepath"
	"testing"
)

// projectRoot attempts to find the project root relative to the test working directory.
// When running `go test` from internal/parser/, project root is ../..
// When running `go test ./...` from internal/, project root is ..
func projectRoot() string {
	// Try relative path from internal/parser/ (go test ./...)
	if _, err := os.Stat("../../examples"); err == nil {
		return "../.."
	}
	// Try relative path from internal/ (go test from internal/)
	if _, err := os.Stat("../examples"); err == nil {
		return ".."
	}
	// Fallback: try from current working directory
	if _, err := os.Stat("examples"); err == nil {
		return "."
	}
	return "../.."
}

// listExampleFiles discovers example source files for a given language.
func listExampleFiles(t *testing.T, lang string) []string {
	t.Helper()
	root := projectRoot()
	var dirs []string
	switch lang {
	case "c", "cpp":
		dirs = []string{filepath.Join(root, "examples/cpp-vuln-demo/src")}
	case "go":
		dirs = []string{filepath.Join(root, "examples/go-vuln-demo/src")}
	case "java":
		dirs = []string{filepath.Join(root, "examples/java-vuln-demo/src")}
	case "python":
		dirs = []string{filepath.Join(root, "examples/python-vuln-demo/src")}
	case "javascript":
		dirs = []string{filepath.Join(root, "examples/js-vuln-demo/src")}
	default:
		t.Fatalf("unknown language: %s", lang)
	}
	var files []string
	for _, dir := range dirs {
		entries, err := os.ReadDir(dir)
		if err != nil {
			t.Fatalf("reading example dir %s: %v", dir, err)
		}
		for _, e := range entries {
			if !e.IsDir() {
				files = append(files, filepath.Join(dir, e.Name()))
			}
		}
	}
	return files
}

// allLanguages returns the list of languages that have example files.
func allLanguages() []string {
	return []string{"c", "cpp", "go", "java", "python", "javascript"}
}

// assertParseResultValid checks common validity properties of a ParseResult.
func assertParseResultValid(t *testing.T, result *ParseResult, expectedFile string, expectedLang string) {
	t.Helper()
	if result.File != expectedFile {
		t.Errorf("File = %q, want %q", result.File, expectedFile)
	}
	if result.Language != expectedLang {
		t.Errorf("Language = %q, want %q", result.Language, expectedLang)
	}
	for i, fn := range result.Functions {
		if fn.Name == "" {
			t.Errorf("Function[%d] has empty Name", i)
		}
		if fn.StartLine == 0 {
			t.Errorf("Function[%d] (%s) has StartLine=0", i, fn.Name)
		}
		if fn.EndLine < fn.StartLine {
			t.Errorf("Function[%d] (%s) EndLine=%d < StartLine=%d", i, fn.Name, fn.EndLine, fn.StartLine)
		}
	}
	for i, typ := range result.Types {
		if typ.Name == "" {
			t.Errorf("Type[%d] has empty Name", i)
		}
		if typ.Kind == "" {
			t.Errorf("Type[%d] (%s) has empty Kind", i, typ.Name)
		}
	}
}
