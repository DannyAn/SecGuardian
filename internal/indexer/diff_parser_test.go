package indexer

import (
	"testing"

	"github.com/secguardian/internal/parser"
)

func TestAffectedSymbols_Overlap(t *testing.T) {
	fns := []parser.FunctionInfo{
		{Name: "foo", File: "a.c", StartLine: 10, EndLine: 20},
	}
	changes := []Change{
		{StartLine: 15, EndLine: 18, Type: "modified"},
	}
	affected := AffectedSymbols(fns, changes)
	if len(affected) != 1 || affected[0] != "foo" {
		t.Errorf("expected [foo], got %v", affected)
	}
}

func TestAffectedSymbols_NoOverlap(t *testing.T) {
	fns := []parser.FunctionInfo{
		{Name: "foo", File: "a.c", StartLine: 10, EndLine: 20},
	}
	changes := []Change{
		{StartLine: 25, EndLine: 30, Type: "modified"},
	}
	affected := AffectedSymbols(fns, changes)
	if len(affected) > 0 {
		t.Errorf("expected empty, got %v", affected)
	}
}

func TestAffectedSymbols_Boundary(t *testing.T) {
	fns := []parser.FunctionInfo{
		{Name: "foo", File: "a.c", StartLine: 10, EndLine: 20},
	}
	// Change partially overlaps at the start
	changes := []Change{
		{StartLine: 8, EndLine: 12, Type: "modified"},
	}
	affected := AffectedSymbols(fns, changes)
	if len(affected) != 1 || affected[0] != "foo" {
		t.Errorf("expected [foo] for boundary overlap, got %v", affected)
	}
}

func TestAffectedSymbols_BoundaryEnd(t *testing.T) {
	fns := []parser.FunctionInfo{
		{Name: "foo", File: "a.c", StartLine: 10, EndLine: 20},
	}
	// Change partially overlaps at the end
	changes := []Change{
		{StartLine: 18, EndLine: 25, Type: "modified"},
	}
	affected := AffectedSymbols(fns, changes)
	if len(affected) != 1 || affected[0] != "foo" {
		t.Errorf("expected [foo] for boundary end overlap, got %v", affected)
	}
}

func TestAffectedSymbols_ExactMatch(t *testing.T) {
	fns := []parser.FunctionInfo{
		{Name: "foo", File: "a.c", StartLine: 10, EndLine: 20},
	}
	changes := []Change{
		{StartLine: 10, EndLine: 20, Type: "modified"},
	}
	affected := AffectedSymbols(fns, changes)
	if len(affected) != 1 || affected[0] != "foo" {
		t.Errorf("expected [foo] for exact match, got %v", affected)
	}
}

func TestAffectedSymbols_Deduplicates(t *testing.T) {
	fns := []parser.FunctionInfo{
		{Name: "foo", File: "a.c", StartLine: 10, EndLine: 20},
		{Name: "foo", File: "a.c", StartLine: 10, EndLine: 20}, // duplicate
	}
	changes := []Change{
		{StartLine: 15, EndLine: 16, Type: "modified"},
	}
	affected := AffectedSymbols(fns, changes)
	if len(affected) != 1 {
		t.Errorf("expected deduplicated [foo], got %v (len=%d)", affected, len(affected))
	}
}

func TestAffectedSymbols_MultipleFunctions(t *testing.T) {
	fns := []parser.FunctionInfo{
		{Name: "foo", File: "a.c", StartLine: 1, EndLine: 5},
		{Name: "bar", File: "a.c", StartLine: 10, EndLine: 15},
		{Name: "baz", File: "a.c", StartLine: 20, EndLine: 25},
	}
	changes := []Change{
		{StartLine: 3, EndLine: 12, Type: "modified"},
	}
	affected := AffectedSymbols(fns, changes)
	// foo (1-5) overlaps with 3-12, bar (10-15) overlaps with 3-12, baz (20-25) does not
	if len(affected) != 2 {
		t.Errorf("expected [foo bar], got %v", affected)
	}
}

func TestAffectedSymbols_Empty(t *testing.T) {
	affected := AffectedSymbols(nil, nil)
	if len(affected) > 0 {
		t.Errorf("expected empty, got %v", affected)
	}
}

func TestAffectedSymbols_NoChanges(t *testing.T) {
	fns := []parser.FunctionInfo{
		{Name: "foo", File: "a.c", StartLine: 1, EndLine: 5},
	}
	affected := AffectedSymbols(fns, nil)
	if len(affected) > 0 {
		t.Errorf("expected empty when no changes, got %v", affected)
	}
}

func TestParseGitDiff_InvalidRef(t *testing.T) {
	// Ref with shell metacharacters should be rejected
	_, err := ParseGitDiff(".", "--help; rm -rf /")
	if err == nil {
		t.Error("expected error for ref with shell metacharacters")
	}
}

func TestParseGitDiff_InvalidRefPipe(t *testing.T) {
	_, err := ParseGitDiff(".", "foo|bar")
	if err == nil {
		t.Error("expected error for ref with pipe character")
	}
}

func TestParseGitDiff_InvalidRefDoubleDash(t *testing.T) {
	_, err := ParseGitDiff(".", "foo--bar")
	if err == nil {
		t.Error("expected error for ref with double dash")
	}
}

func TestFmtSscanf(t *testing.T) {
	tests := []struct {
		input    string
		expected int
	}{
		{"42", 42},
		{"0", 0},
		{"123abc", 123},
		{"", 0},
		{"  99", 0},
		{"-5", 0},
	}
	for _, tt := range tests {
		got, err := fmtSscanf(tt.input)
		if err != nil {
			t.Errorf("fmtSscanf(%q) unexpected error: %v", tt.input, err)
		}
		if got != tt.expected {
			t.Errorf("fmtSscanf(%q) = %d, want %d", tt.input, got, tt.expected)
		}
	}
}
