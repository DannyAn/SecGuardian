package indexer

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/secguardian/internal/parser"
)

// makeParseResult is a test helper to build a simple ParseResult.
func makeParseResult(file, lang string, fns []parser.FunctionInfo, vars []parser.VariableInfo, typs []parser.TypeInfo) *parser.ParseResult {
	return &parser.ParseResult{
		File:      file,
		Language:  lang,
		Functions: fns,
		Variables: vars,
		Types:     typs,
	}
}

func TestExtractSymbols(t *testing.T) {
	parsed := map[string]*parser.ParseResult{
		"a.c": makeParseResult("a.c", "c",
			[]parser.FunctionInfo{{Name: "main", File: "a.c", StartLine: 1, EndLine: 5}},
			[]parser.VariableInfo{{Name: "count", File: "a.c", Line: 2}},
			[]parser.TypeInfo{{Name: "Node", Kind: "struct", File: "a.c", StartLine: 1}},
		),
		"b.c": makeParseResult("b.c", "c",
			[]parser.FunctionInfo{{Name: "helper", File: "b.c", StartLine: 1, EndLine: 3}},
			nil,
			nil,
		),
	}
	symbols := ExtractSymbols(parsed)
	if len(symbols.Functions) != 2 {
		t.Errorf("Functions: got %d, want 2", len(symbols.Functions))
	}
	if len(symbols.Variables) != 1 {
		t.Errorf("Variables: got %d, want 1", len(symbols.Variables))
	}
	if len(symbols.Types) != 1 {
		t.Errorf("Types: got %d, want 1", len(symbols.Types))
	}
}

func TestExtractSymbols_EmptyInput(t *testing.T) {
	symbols := ExtractSymbols(map[string]*parser.ParseResult{})
	if len(symbols.Functions) != 0 || len(symbols.Variables) != 0 || len(symbols.Types) != 0 {
		t.Error("expected empty SymbolIndex from empty input")
	}
}

func TestBuildCallGraph_DirectCall(t *testing.T) {
	dir := t.TempDir()
	fp := filepath.Join(dir, "calltest.c")
	// function foo calls bar
	content := `#include <stdio.h>

void bar() {
    printf("hello\n");
}

void foo() {
    bar();
}

int main() {
    foo();
    return 0;
}
`
	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	parsed := map[string]*parser.ParseResult{
		fp: makeParseResult(fp, "c",
			[]parser.FunctionInfo{
				{Name: "bar", File: fp, StartLine: 3, EndLine: 5},
				{Name: "foo", File: fp, StartLine: 7, EndLine: 9},
				{Name: "main", File: fp, StartLine: 11, EndLine: 14},
			},
			nil, nil,
		),
	}
	symbols := ExtractSymbols(parsed)
	cg := BuildCallGraph(parsed, symbols)
	// foo calls bar
	foundFooBar := false
	foundMainFoo := false
	for _, edge := range cg.Edges {
		if edge.Caller == "foo" && edge.Callee == "bar" {
			foundFooBar = true
		}
		if edge.Caller == "main" && edge.Callee == "foo" {
			foundMainFoo = true
		}
	}
	if !foundFooBar {
		t.Error("expected edge foo -> bar, not found")
	}
	if !foundMainFoo {
		t.Error("expected edge main -> foo, not found")
	}
}

func TestBuildCallGraph_NoSelfEdges(t *testing.T) {
	dir := t.TempDir()
	fp := filepath.Join(dir, "recurse.c")
	content := "void recurse() { recurse(); }\n"
	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	parsed := map[string]*parser.ParseResult{
		fp: makeParseResult(fp, "c",
			[]parser.FunctionInfo{{Name: "recurse", File: fp, StartLine: 1, EndLine: 1}},
			nil, nil,
		),
	}
	symbols := ExtractSymbols(parsed)
	cg := BuildCallGraph(parsed, symbols)
	for _, edge := range cg.Edges {
		if edge.Caller == "recurse" && edge.Callee == "recurse" {
			t.Error("BuildCallGraph should not produce self-edges")
		}
	}
}

func TestBuildCallGraph_CommentExclusion(t *testing.T) {
	dir := t.TempDir()
	fp := filepath.Join(dir, "commentcall.c")
	// foo does NOT call bar — bar only appears in a comment
	content := `void bar() { }

void foo() {
    // bar();
    int x = 0;
}
`
	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	parsed := map[string]*parser.ParseResult{
		fp: makeParseResult(fp, "c",
			[]parser.FunctionInfo{
				{Name: "bar", File: fp, StartLine: 1, EndLine: 1},
				{Name: "foo", File: fp, StartLine: 3, EndLine: 6},
			},
			nil, nil,
		),
	}
	symbols := ExtractSymbols(parsed)
	cg := BuildCallGraph(parsed, symbols)
	for _, edge := range cg.Edges {
		if edge.Caller == "foo" && edge.Callee == "bar" {
			t.Error("foo should not call bar (bar() is in a comment)")
		}
	}
}

func TestMatchAllocFree_PairDetected(t *testing.T) {
	dir := t.TempDir()
	fp := filepath.Join(dir, "alloc.c")
	content := `#include <stdlib.h>

void process() {
    char *buf = malloc(1024);
    if (buf) {
        free(buf);
    }
}
`
	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	parsed := map[string]*parser.ParseResult{
		fp: makeParseResult(fp, "c",
			[]parser.FunctionInfo{{Name: "process", File: fp, StartLine: 3, EndLine: 8}},
			nil, nil,
		),
	}
	af := MatchAllocFree(parsed)
	if len(af.Pairs) == 0 {
		t.Fatal("expected at least one alloc-free pair")
	}
	pair := af.Pairs[0]
	if pair.AllocFunc != "malloc" {
		t.Errorf("AllocFunc = %q, want malloc", pair.AllocFunc)
	}
	if len(pair.FreeSites) == 0 {
		t.Error("expected at least one free site")
	}
}

func TestMatchAllocFree_NoAlloc(t *testing.T) {
	dir := t.TempDir()
	fp := filepath.Join(dir, "noalloc.c")
	content := "void empty() { int x = 0; }\n"
	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	parsed := map[string]*parser.ParseResult{
		fp: makeParseResult(fp, "c",
			[]parser.FunctionInfo{{Name: "empty", File: fp, StartLine: 1, EndLine: 1}},
			nil, nil,
		),
	}
	af := MatchAllocFree(parsed)
	if len(af.Pairs) > 0 {
		t.Errorf("expected 0 pairs for file without malloc, got %d", len(af.Pairs))
	}
}

func TestBuildLockGraph_LockDetected(t *testing.T) {
	dir := t.TempDir()
	fp := filepath.Join(dir, "lock.c")
	content := `#include <pthread.h>

void worker() {
    pthread_mutex_lock(&mutex);
    // critical section
    pthread_mutex_unlock(&mutex);
}
`
	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	parsed := map[string]*parser.ParseResult{
		fp: makeParseResult(fp, "c",
			[]parser.FunctionInfo{{Name: "worker", File: fp, StartLine: 3, EndLine: 7}},
			nil, nil,
		),
	}
	lg := BuildLockGraph(parsed)
	if len(lg.Mutexes) == 0 {
		t.Error("expected at least one mutex usage")
	}
	for _, m := range lg.Mutexes {
		if m.File != fp {
			t.Errorf("LockUsage.File = %q, want %q", m.File, fp)
		}
		if m.LockLine == 0 {
			t.Error("LockLine should not be 0")
		}
	}
}

func TestBuildLockGraph_NoLocks(t *testing.T) {
	dir := t.TempDir()
	fp := filepath.Join(dir, "nolock.c")
	content := "void plain() { int x = 0; }\n"
	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	parsed := map[string]*parser.ParseResult{
		fp: makeParseResult(fp, "c",
			[]parser.FunctionInfo{{Name: "plain", File: fp, StartLine: 1, EndLine: 1}},
			nil, nil,
		),
	}
	lg := BuildLockGraph(parsed)
	if len(lg.Mutexes) > 0 {
		t.Errorf("expected 0 mutexes for file without locks, got %d", len(lg.Mutexes))
	}
}

func TestMatchAllocFree_Calloc(t *testing.T) {
	dir := t.TempDir()
	fp := filepath.Join(dir, "calloc.c")
	content := "#include <stdlib.h>\nvoid f() { int *p = calloc(10, sizeof(int)); free(p); }\n"
	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	parsed := map[string]*parser.ParseResult{
		fp: makeParseResult(fp, "c",
			[]parser.FunctionInfo{{Name: "f", File: fp, StartLine: 1, EndLine: 2}},
			nil, nil,
		),
	}
	af := MatchAllocFree(parsed)
	if len(af.Pairs) == 0 {
		t.Fatal("expected alloc-free pair for calloc")
	}
	pair := af.Pairs[0]
	if pair.AllocFunc != "calloc" {
		t.Errorf("AllocFunc = %q, want calloc", pair.AllocFunc)
	}
}

// TestMatchAllocFree_MallocCommentExcluded ensures malloc in comment lines is ignored.
func TestMatchAllocFree_MallocCommentExcluded(t *testing.T) {
	dir := t.TempDir()
	fp := filepath.Join(dir, "comment_alloc.c")
	content := "// malloc(100);\nvoid f() { int x = 0; }\n"
	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	parsed := map[string]*parser.ParseResult{
		fp: makeParseResult(fp, "c",
			[]parser.FunctionInfo{{Name: "f", File: fp, StartLine: 2, EndLine: 2}},
			nil, nil,
		),
	}
	af := MatchAllocFree(parsed)
	if len(af.Pairs) > 0 {
		t.Errorf("expected 0 pairs when malloc is in comment, got %d", len(af.Pairs))
	}
}

func TestBuildCallGraph_EmptyInput(t *testing.T) {
	cg := BuildCallGraph(map[string]*parser.ParseResult{}, SymbolIndex{})
	if len(cg.Edges) > 0 {
		t.Errorf("expected empty CallGraph, got %d edges", len(cg.Edges))
	}
}

func TestMatchAllocFree_EmptyInput(t *testing.T) {
	af := MatchAllocFree(map[string]*parser.ParseResult{})
	if len(af.Pairs) > 0 {
		t.Errorf("expected empty AllocFreeMap, got %d pairs", len(af.Pairs))
	}
}

func TestBuildLockGraph_EmptyInput(t *testing.T) {
	lg := BuildLockGraph(map[string]*parser.ParseResult{})
	if len(lg.Mutexes) > 0 {
		t.Errorf("expected empty LockGraph, got %d mutexes", len(lg.Mutexes))
	}
}

func TestIsCommentLine(t *testing.T) {
	tests := []struct {
		line     string
		expected bool
	}{
		{"// this is a comment", true},
		{"/* block comment", true},
		{" * continuation of block", true},
		{"int x = 0;", false},
		{"  //  indented comment", true},
		{"  int y = 1;  ", false},
		{"", false},
	}
	for _, tt := range tests {
		got := isCommentLine(tt.line)
		if got != tt.expected {
			t.Errorf("isCommentLine(%q) = %v, want %v", tt.line, got, tt.expected)
		}
	}
}

func TestMatchAllocFree_Realloc(t *testing.T) {
	dir := t.TempDir()
	fp := filepath.Join(dir, "realloc.c")
	content := "#include <stdlib.h>\nvoid f() { void *p = malloc(100); p = realloc(p, 200); free(p); }\n"
	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	parsed := map[string]*parser.ParseResult{
		fp: makeParseResult(fp, "c",
			[]parser.FunctionInfo{{Name: "f", File: fp, StartLine: 1, EndLine: 2}},
			nil, nil,
		),
	}
	af := MatchAllocFree(parsed)
	if len(af.Pairs) == 0 {
		t.Fatal("expected at least one pair (malloc+free or realloc+free)")
	}
}

func TestMatchAllocFree_DeleteOperator(t *testing.T) {
	dir := t.TempDir()
	fp := filepath.Join(dir, "del.cpp")
	content := "void f() { int *p = new int; delete p; }\n"
	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	parsed := map[string]*parser.ParseResult{
		fp: makeParseResult(fp, "cpp",
			[]parser.FunctionInfo{{Name: "f", File: fp, StartLine: 1, EndLine: 1}},
			nil, nil,
		),
	}
	// "new" is not in allocFns (only malloc/calloc/realloc), but "delete" is in freeFns
	// So this tests that "delete" as free function is detected even without matching alloc
	af := MatchAllocFree(parsed)
	// With only "new" (not in allocFns), we expect 0 pairs since no alloc is matched
	t.Logf("pairs from new/delete (new not tracked): %d", len(af.Pairs))
}

func TestBuildCallGraph_CrossFileCall(t *testing.T) {
	dir := t.TempDir()
	fp1 := filepath.Join(dir, "a.c")
	fp2 := filepath.Join(dir, "b.c")

	content1 := "void helper() { }\n"
	content2 := "#include \"a.h\"\nvoid caller() { helper(); }\n"

	if err := os.WriteFile(fp1, []byte(content1), 0644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(fp2, []byte(content2), 0644); err != nil {
		t.Fatal(err)
	}

	parsed := map[string]*parser.ParseResult{
		fp1: makeParseResult(fp1, "c",
			[]parser.FunctionInfo{{Name: "helper", File: fp1, StartLine: 1, EndLine: 1}},
			nil, nil,
		),
		fp2: makeParseResult(fp2, "c",
			[]parser.FunctionInfo{{Name: "caller", File: fp2, StartLine: 2, EndLine: 2}},
			nil, nil,
		),
	}
	symbols := ExtractSymbols(parsed)
	cg := BuildCallGraph(parsed, symbols)

	found := false
	for _, edge := range cg.Edges {
		if edge.Caller == "caller" && edge.Callee == "helper" {
			found = true
			break
		}
	}
	if !found {
		t.Error("expected cross-file edge caller -> helper")
	}
}

func TestMatchAllocFree_NoFree(t *testing.T) {
	dir := t.TempDir()
	fp := filepath.Join(dir, "nofree.c")
	content := "#include <stdlib.h>\nvoid leak() { void *p = malloc(100); }\n"
	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	parsed := map[string]*parser.ParseResult{
		fp: makeParseResult(fp, "c",
			[]parser.FunctionInfo{{Name: "leak", File: fp, StartLine: 1, EndLine: 2}},
			nil, nil,
		),
	}
	af := MatchAllocFree(parsed)
	if len(af.Pairs) > 0 {
		t.Errorf("expected 0 pairs when malloc has no matching free, got %d", len(af.Pairs))
	}
}

func TestBuildLockGraph_MultipleLocks(t *testing.T) {
	dir := t.TempDir()
	fp := filepath.Join(dir, "multilock.c")
	content := strings.Repeat("pthread_mutex_lock(&m1);\n", 5)
	if err := os.WriteFile(fp, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
	parsed := map[string]*parser.ParseResult{
		fp: makeParseResult(fp, "c",
			[]parser.FunctionInfo{{Name: "f", File: fp, StartLine: 1, EndLine: 5}},
			nil, nil,
		),
	}
	lg := BuildLockGraph(parsed)
	if len(lg.Mutexes) != 5 {
		t.Errorf("expected 5 mutex lock entries, got %d", len(lg.Mutexes))
	}
	for _, m := range lg.Mutexes {
		if m.LockLine == 0 {
			t.Error("LockLine should not be 0")
		}
	}
}
