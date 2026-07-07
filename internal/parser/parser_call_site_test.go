package parser

import (
	"os"
	"path/filepath"
	"testing"
)

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

func TestCallSitesOnFiles(t *testing.T) {
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

func TestCallSitesEdgeCases(t *testing.T) {
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

	if len(result.CallSites) != 9 {
		t.Errorf("Expected 9 call_sites, got %d", len(result.CallSites))
		for _, cs := range result.CallSites {
			t.Logf("  %s:%d", cs.CalleeName, cs.Line)
		}
	}

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
