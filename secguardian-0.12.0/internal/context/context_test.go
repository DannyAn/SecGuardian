 package context

 import (
 	"encoding/json"
 	"testing"

 	"github.com/secguardian/internal/indexer"
 	"github.com/secguardian/internal/parser"
 )

 func TestJSONRoundTrip(t *testing.T) {
 	orig := AnalysisContext{
 		Path:  "/tmp/test-repo",
 		Files: []string{"src/main.c", "src/util.c"},
 		Symbols: indexer.SymbolIndex{
 			Functions: []parser.FunctionInfo{
 				{Name: "main", File: "src/main.c", StartLine: 1, EndLine: 30},
 				{Name: "helper", File: "src/util.c", StartLine: 5, EndLine: 20},
 			},
 			Variables: []parser.VariableInfo{
 				{Name: "g_counter", File: "src/main.c", Line: 10},
 			},
 			Types: []parser.TypeInfo{
 				{Name: "Config", Kind: "struct", File: "src/main.c", StartLine: 3},
 			},
 		},
 		CallGraph: indexer.CallGraph{
 			Edges: []indexer.CallGraphEdge{
 				{Caller: "main", Callee: "helper", File: "src/main.c", Line: 25},
 			},
 		},
 		AllocFree: indexer.AllocFreeMap{
 			Pairs: []indexer.AllocFreePair{
 				{AllocFunc: "malloc", AllocFile: "src/main.c", AllocLine: 15, FreeSites: []indexer.FreeSite{{File: "src/main.c", Line: 28}}},
 			},
 		},
 		LockGraph: indexer.LockGraph{
 			Mutexes: []indexer.LockUsage{
 				{MutexName: "g_mutex", LockLine: 12, UnlockLine: 18, File: "src/main.c"},
 			},
 		},
 	}

 	data, err := json.Marshal(orig)
 	if err != nil {
 		t.Fatalf("json.Marshal failed: %v", err)
 	}

 	var decoded AnalysisContext
 	if err := json.Unmarshal(data, &decoded); err != nil {
 		t.Fatalf("json.Unmarshal failed: %v", err)
 	}

 	// Verify path
 	if decoded.Path != orig.Path {
 		t.Errorf("Path: got %q, want %q", decoded.Path, orig.Path)
 	}
 	// Verify files length
 	if len(decoded.Files) != len(orig.Files) {
 		t.Errorf("Files length: got %d, want %d", len(decoded.Files), len(orig.Files))
 	}
 	// Verify function count
 	if len(decoded.Symbols.Functions) != len(orig.Symbols.Functions) {
 		t.Errorf("Functions: got %d, want %d", len(decoded.Symbols.Functions), len(orig.Symbols.Functions))
 	}
 	// Verify function name
 	if decoded.Symbols.Functions[0].Name != "main" {
 		t.Errorf("Function[0].Name: got %q, want %q", decoded.Symbols.Functions[0].Name, "main")
 	}
 	// Verify call graph edge count
 	if len(decoded.CallGraph.Edges) != 1 {
 		t.Errorf("CallGraph edges: got %d, want 1", len(decoded.CallGraph.Edges))
 	}
 	// Verify alloc/free pair count
 	if len(decoded.AllocFree.Pairs) != 1 {
 		t.Errorf("AllocFree pairs: got %d, want 1", len(decoded.AllocFree.Pairs))
 	}
 	// Verify lock graph mutex count
 	if len(decoded.LockGraph.Mutexes) != 1 {
 		t.Errorf("LockGraph mutexes: got %d, want 1", len(decoded.LockGraph.Mutexes))
 	}
 	// Verify JSON contains all expected top-level keys
 	var raw map[string]interface{}
 	if err := json.Unmarshal(data, &raw); err != nil {
 		t.Fatalf("json.Unmarshal to map failed: %v", err)
 	}
 	expectedKeys := []string{"path", "files", "symbols", "call_graph", "alloc_free", "lock_graph"}
 	for _, key := range expectedKeys {
 		if _, ok := raw[key]; !ok {
 			t.Errorf("JSON missing top-level key: %s", key)
 		}
 	}
 }

 func TestEmptyContext(t *testing.T) {
 	ctx := AnalysisContext{}

 	data, err := json.Marshal(ctx)
 	if err != nil {
 		t.Fatalf("json.Marshal empty context failed: %v", err)
 	}

 	var raw map[string]interface{}
 	if err := json.Unmarshal(data, &raw); err != nil {
 		t.Fatalf("json.Unmarshal to map failed: %v", err)
 	}

 	// Empty context should still contain all top-level keys
 	expectedKeys := []string{"path", "files", "symbols", "call_graph", "alloc_free", "lock_graph"}
 	for _, key := range expectedKeys {
 		if _, ok := raw[key]; !ok {
 			t.Errorf("Empty context JSON missing key: %s", key)
 		}
 	}
 }
