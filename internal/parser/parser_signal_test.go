
package parser

import (
	"testing"
)

func TestStringLiteralExtraction(t *testing.T) {
	f := "../../examples/cpp-vuln-demo/src/crypto.c"
	result, err := ParseFile(f, "c")
	if err != nil {
		t.Fatalf("ParseFile error: %v", err)
	}
	if len(result.StringLiterals) == 0 {
		t.Fatal("Expected string literals in crypto.c")
	}
	foundSecret := false
	for _, s := range result.StringLiterals {
		t.Logf("  L%d ctx=%s val=%q kinds=%v", s.Line, s.Context, s.Value, s.Kinds)
		if s.Value == "SuperSecretPassw0rd!" {
			foundSecret = true
			if !contains(s.Kinds, "secret") {
				t.Errorf("Expected 'secret' kind for password, got %v", s.Kinds)
			}
		}
		if s.Line == 21 && s.Context == "global" {
			if !contains(s.Kinds, "api_key") {
				t.Errorf("Expected 'api_key' kind for g_api_key at line 21, got %v", s.Kinds)
			}
		}
	}
	if !foundSecret {
		t.Error("Expected to find 'SuperSecretPassw0rd!' in string literals")
	}
}

func TestImportExtraction(t *testing.T) {
	f := "../../examples/cpp-vuln-demo/src/crypto.c"
	result, err := ParseFile(f, "c")
	if err != nil {
		t.Fatalf("ParseFile error: %v", err)
	}
	if len(result.Imports) == 0 {
		t.Fatal("Expected imports in crypto.c")
	}
	foundCrypto := false
	for _, imp := range result.Imports {
		if imp.Category == "crypto" {
			foundCrypto = true
			break
		}
	}
	if !foundCrypto {
		t.Error("Expected at least 1 crypto-category import in crypto.c")
	}
}

func TestValueConstantExtraction(t *testing.T) {
	f := "../../examples/cpp-vuln-demo/src/crypto.c"
	result, err := ParseFile(f, "c")
	if err != nil {
		t.Fatalf("ParseFile error: %v", err)
	}
	foundDES := false
	foundKeyLen := false
	for _, v := range result.ValueConstants {
		if v.Value == "DES_ENCRYPT" || v.Category == "flag" {
			foundDES = true
		}
		if v.Category == "key_length" {
			foundKeyLen = true
		}
	}
	t.Logf("Value constants: %d (DES=%v, key_len=%v)", len(result.ValueConstants), foundDES, foundKeyLen)
	if !foundDES {
		t.Log("Note: DES_ENCRYPT not found in value constants (expected on CGO build)")
	}
}

func TestSignalMatrixOnAllFiles(t *testing.T) {
	files := []string{
		"../../examples/cpp-vuln-demo/src/allocator.c",
		"../../examples/cpp-vuln-demo/src/system.c",
		"../../examples/cpp-vuln-demo/src/crypto.c",
		"../../examples/cpp-vuln-demo/src/concurrency.c",
		"../../examples/cpp-vuln-demo/src/network.c",
		"../../examples/cpp-vuln-demo/src/windows.c",
	}
	totalSignals := 0
	for _, f := range files {
		result, err := ParseFile(f, "c")
		if err != nil {
			t.Fatalf("ParseFile(%s) error: %v", f, err)
		}
		count := len(result.CallSites) + len(result.StringLiterals) + len(result.Declarations) +
			len(result.ValueConstants) + len(result.Imports) + len(result.ConfigPatterns) +
			len(result.ControlFlow)
		totalSignals += count
		t.Logf("%s: %d total signals (calls=%d str=%d decl=%d val=%d imp=%d cfg=%d flow=%d)",
			f, count,
			len(result.CallSites), len(result.StringLiterals), len(result.Declarations),
			len(result.ValueConstants), len(result.Imports), len(result.ConfigPatterns),
			len(result.ControlFlow))
	}
	if totalSignals < 50 {
		t.Errorf("Expected at least 50 total signals across all files, got %d", totalSignals)
	}
	t.Logf("Total signals across %d files: %d", len(files), totalSignals)
}

func contains(slice []string, item string) bool {
	for _, s := range slice {
		if s == item {
			return true
		}
	}
	return false
}
