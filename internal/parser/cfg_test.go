//go:build cgo

package parser

import (
	"testing"

	treesitter "github.com/tree-sitter/go-tree-sitter"
	c "github.com/tree-sitter/tree-sitter-c/bindings/go"
)

// parseC parses a C source snippet and returns the root CST node + content.
func parseC(t *testing.T, src string) (*treesitter.Node, []byte) {
	t.Helper()
	p := treesitter.NewParser()
	defer p.Close()
	p.SetLanguage(treesitter.NewLanguage(c.Language()))
	content := []byte(src)
	tree := p.Parse(content, nil)
	return tree.RootNode(), content
}

// findFirstDescendant does a BFS for the first node with the given kind.
func findFirstDescendant(root *treesitter.Node, kind string) *treesitter.Node {
	if root == nil {
		return nil
	}
	if root.Kind() == kind {
		return root
	}
	for i := uint(0); i < root.NamedChildCount(); i++ {
		if found := findFirstDescendant(root.NamedChild(i), kind); found != nil {
			return found
		}
	}
	return nil
}

func TestCFG_IfWithReturn(t *testing.T) {
	src := `int f(int x){
		if (x == 0) {
			return 1;
		}
		return 2;
	}`
	root, content := parseC(t, src)
	fn := findFirstDescendant(root, "function_definition")
	if fn == nil {
		t.Fatal("function_definition not found")
	}
	cfg := BuildCFG(fn, content, "f", "test.c")
	if cfg == nil {
		t.Fatal("BuildCFG returned nil")
	}
	if cfg.Function != "f" {
		t.Errorf("Function = %q, want f", cfg.Function)
	}
	if len(cfg.Blocks) == 0 {
		t.Fatal("no blocks built")
	}

	// Expect at least: entry(0), then-branch, else-branch, merge, plus the
	// unreachable block after `return 1`, plus the trailing `return 2`.
	// Structural assertions:
	//  - entry has a True edge and a False edge (the if split).
	hasTrue, hasFalse := false, false
	for _, e := range cfg.Blocks[0].Succ {
		if e.Type == EdgeTrue {
			hasTrue = true
		}
		if e.Type == EdgeFalse {
			hasFalse = true
		}
	}
	if !hasTrue || !hasFalse {
		t.Errorf("entry block missing true/false edges, got succ=%v", cfg.Blocks[0].Succ)
	}

	// At least one return edge must exist somewhere.
	foundReturn := false
	for _, b := range cfg.Blocks {
		for _, e := range b.Succ {
			if e.Type == EdgeReturn {
				foundReturn = true
			}
		}
	}
	if !foundReturn {
		t.Error("no return edge found")
	}
}

func TestCFG_IsReachable(t *testing.T) {
	src := `int f(int x){
		if (x) {
			return 1;
		}
		g();
		return 2;
	}`
	root, content := parseC(t, src)
	fn := findFirstDescendant(root, "function_definition")
	cfg := BuildCFG(fn, content, "f", "test.c")

	// Entry is reachable to itself and to every block that is not unreachable-after-return.
	// Find the block containing g() (line 5) and assert entry reaches it.
	gBlk := -1
	for i, b := range cfg.Blocks {
		for _, l := range b.Stmts {
			if l == 5 {
				gBlk = i
			}
		}
	}
	if gBlk == -1 {
		t.Fatalf("block containing g() not found; blocks=%v", cfg.Blocks)
	}
	if !cfg.IsReachable(cfg.Entry, gBlk) {
		t.Errorf("entry should reach g() block %d", gBlk)
	}
	// A block immediately after `return 1` (unreachable) should NOT be reachable
	// from the path that goes through the then-branch only if it has no preds.
	// At minimum: IsReachable(n,n) is true.
	if !cfg.IsReachable(gBlk, gBlk) {
		t.Error("IsReachable(n,n) should be true")
	}
}

func TestCFG_Dominates(t *testing.T) {
	src := `int f(int x){
		a();
		if (x) {
			b();
		}
		c();
		return 0;
	}`
	root, content := parseC(t, src)
	fn := findFirstDescendant(root, "function_definition")
	cfg := BuildCFG(fn, content, "f", "test.c")

	// Entry dominates every reachable block.
	for i := range cfg.Blocks {
		if !cfg.Dominates(cfg.Entry, i) {
			// Only unreachable-after-return blocks may not be dominated by entry;
			// those have no preds and are not reachable.
			if cfg.IsReachable(cfg.Entry, i) {
				t.Errorf("entry should dominate reachable block %d", i)
			}
		}
	}
	// Entry dominates itself.
	if !cfg.Dominates(cfg.Entry, cfg.Entry) {
		t.Error("entry should dominate itself")
	}
}

func TestCFG_LoopBackEdge(t *testing.T) {
	src := `int f(int n){
		int s = 0;
		for (int i = 0; i < n; i++) {
			s += i;
		}
		return s;
	}`
	root, content := parseC(t, src)
	fn := findFirstDescendant(root, "function_definition")
	cfg := BuildCFG(fn, content, "f", "test.c")

	// A loop must produce at least one back edge.
	foundBack := false
	for _, b := range cfg.Blocks {
		for _, e := range b.Succ {
			if e.Type == EdgeBack {
				foundBack = true
			}
		}
	}
	if !foundBack {
		t.Errorf("for-loop should produce a back edge; blocks=%v", cfg.Blocks)
	}
}
