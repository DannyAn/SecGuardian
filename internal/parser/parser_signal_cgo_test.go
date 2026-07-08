//go:build cgo

package parser

import (
	"os"
	"testing"
)

func TestDeclarationExtraction(t *testing.T) {
	f := "../../examples/cpp-vuln-demo/src/crypto.c"
	result, err := ParseFile(f, "c")
	if err != nil {
		t.Fatalf("ParseFile error: %v", err)
	}
	if len(result.Declarations) == 0 {
		t.Fatal("Expected declarations in crypto.c")
	}
	foundWeakKey := false
	for _, d := range result.Declarations {
		if d.Name == "key" && d.ArraySize == 7 {
			foundWeakKey = true
			if d.Category != "key" {
				t.Errorf("Expected key[7] category='key', got '%s'", d.Category)
			}
		}
	}
	if !foundWeakKey {
		t.Error("Expected to find key[7] with array_size=7 in crypto.c declarations")
	}
	t.Logf("Declarations: %d", len(result.Declarations))
	for _, d := range result.Declarations {
		t.Logf("  %s type=%s size=%d cat=%s fn=%s", d.Name, d.TypeName, d.ArraySize, d.Category, d.Function)
	}
}

func TestControlFlowExtraction(t *testing.T) {
	f := "../../examples/cpp-vuln-demo/src/crypto.c"
	result, err := ParseFile(f, "c")
	if err != nil {
		t.Fatalf("ParseFile error: %v", err)
	}
	if len(result.ControlFlow) == 0 {
		t.Fatal("Expected control flow signals in crypto.c")
	}
	t.Logf("Control flow signals: %d", len(result.ControlFlow))
	for _, cf := range result.ControlFlow {
		t.Logf("  L%d fn=%s cat=%s hasReturn=%v cond=%s", cf.Line, cf.Function, cf.Category, cf.HasReturn, cf.Condition)
	}
}

func TestTmpFileDeclarations(t *testing.T) {
	source := []byte(`
void test_fn() {
    unsigned char key[7];
    unsigned char buf[32];
    int counter;
    char data[128];
    size_t len;
    unsigned char auth_token[64];
}
`)
	tmpFile := "/tmp/test_decl_signal.c"
	if err := os.WriteFile(tmpFile, source, 0644); err != nil {
		t.Fatal(err)
	}
	result, err := ParseFile(tmpFile, "c")
	if err != nil {
		t.Fatal(err)
	}
	if len(result.Declarations) != 6 {
		t.Errorf("Expected 6 declarations, got %d", len(result.Declarations))
	}
	for _, d := range result.Declarations {
		switch d.Name {
		case "key":
			if d.ArraySize != 7 || d.Category != "key" {
				t.Errorf("key: expected size=7 cat=key, got size=%d cat=%s", d.ArraySize, d.Category)
			}
		case "buf":
			if d.ArraySize != 32 {
				t.Errorf("buf: expected size=32, got %d", d.ArraySize)
			}
		case "counter":
			if d.Category != "counter" {
				t.Errorf("counter: expected cat=counter, got %s", d.Category)
			}
		case "data":
			if d.ArraySize != 128 {
				t.Errorf("data: expected size=128, got %d", d.ArraySize)
			}
		}
	}
}
