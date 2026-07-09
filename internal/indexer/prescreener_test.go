package indexer

import (
	"testing"

	"github.com/secguardian/internal/parser"
)

// ── Helper: build a buffer declaration ──────────────────────────────

func makeDecl(name string, arraySize int) parser.Declaration {
	return parser.Declaration{
		Name:      name,
		TypeName:  "char",
		ArraySize: arraySize,
		IsPointer: arraySize == 0,
		IsConst:   false,
		Category:  "buffer",
	}
}

func makeCallSite(callee string, file string, line uint, args []string, safeVariant bool, category string) parser.CallSite {
	return parser.CallSite{
		CalleeName:    callee,
		File:          file,
		Line:          line,
		Arguments:     args,
		IsSafeVariant: safeVariant,
		Category:      category,
	}
}

// ── Tests ───────────────────────────────────────────────────────────

func TestPrescreen_BufferOverflow_SafeSizeofMatch(t *testing.T) {
	// T1: strcpy_s(dst, sizeof(dst), src) with char dst[64]
	sites := []parser.CallSite{
		makeCallSite("strcpy_s", "main.c", 42, []string{"dst", "sizeof(dst)", "src"}, true, "string"),
	}
	decls := []parser.Declaration{
		makeDecl("dst", 64),
	}
	filtered, audit := PrescreenCallSites(sites, decls)
	if len(filtered) != 0 {
		t.Errorf("expected all filtered (safe), got %d remaining", len(filtered))
	}
	if audit.SafeCount != 1 {
		t.Errorf("expected 1 safe, got %d", audit.SafeCount)
	}
	if audit.UnknownCount != 0 {
		t.Errorf("expected 0 unknown, got %d", audit.UnknownCount)
	}
}

func TestPrescreen_BufferOverflow_NoSizeofInArgs(t *testing.T) {
	// T2: strcpy_s(dst, dst_len, src) — dst_len is a variable, not sizeof(dst)
	sites := []parser.CallSite{
		makeCallSite("strcpy_s", "main.c", 42, []string{"dst", "dst_len", "src"}, true, "string"),
	}
	decls := []parser.Declaration{
		makeDecl("dst", 128),
	}
	filtered, audit := PrescreenCallSites(sites, decls)
	if len(filtered) != 1 {
		t.Errorf("expected 1 remaining (unknown — no sizeof in args), got %d remaining", len(filtered))
	}
	if audit.SafeCount != 0 {
		t.Errorf("expected 0 safe, got %d", audit.SafeCount)
	}
}

func TestPrescreen_BufferOverflow_PtrNotInDecls(t *testing.T) {
	// T3: strcpy_s(ptr, size, src) — ptr is a pointer param, not in declarations
	sites := []parser.CallSite{
		makeCallSite("strcpy_s", "main.c", 42, []string{"ptr", "size", "src"}, true, "string"),
	}
	// No declarations for "ptr"
	filtered, audit := PrescreenCallSites(sites, nil)
	if len(filtered) != 1 {
		t.Errorf("expected 1 remaining (unknown — ptr not in decls), got %d remaining", len(filtered))
	}
	if audit.SafeCount != 0 {
		t.Errorf("expected 0 safe, got %d", audit.SafeCount)
	}
}

func TestPrescreen_BufferOverflow_UnsafeVariant(t *testing.T) {
	// T4: strcpy(dst, src) — unsafe variant (no _s), must not be prescreened
	sites := []parser.CallSite{
		makeCallSite("strcpy", "main.c", 42, []string{"dst", "src"}, false, "string"),
	}
	decls := []parser.Declaration{
		makeDecl("dst", 64),
	}
	filtered, audit := PrescreenCallSites(sites, decls)
	if len(filtered) != 1 {
		t.Errorf("expected 1 remaining (unsafe → unknown), got %d remaining", len(filtered))
	}
	if audit.SafeCount != 0 {
		t.Errorf("expected 0 safe for unsafe variant, got %d", audit.SafeCount)
	}
	if audit.UnknownCount != 1 {
		t.Errorf("expected 1 unknown for unsafe variant, got %d", audit.UnknownCount)
	}
}

func TestPrescreen_BufferOverflow_DynamicSource(t *testing.T) {
	// T5: strcpy_s(dst, sizeof(dst), malloc(100)) — source is dynamic allocation
	sites := []parser.CallSite{
		makeCallSite("strcpy_s", "main.c", 42, []string{"dst", "sizeof(dst)", "malloc"}, true, "string"),
	}
	decls := []parser.Declaration{
		makeDecl("dst", 64),
	}
	filtered, audit := PrescreenCallSites(sites, decls)
	if len(filtered) != 1 {
		t.Errorf("expected 1 remaining (dynamic source → unknown), got %d remaining", len(filtered))
	}
	if audit.SafeCount != 0 {
		t.Errorf("expected 0 safe for dynamic source, got %d", audit.SafeCount)
	}
}

func TestPrescreen_BufferOverflow_SnprintfSafe(t *testing.T) {
	// T6: snprintf(buf, sizeof(buf), "fmt", val) with char buf[256]
	sites := []parser.CallSite{
		makeCallSite("snprintf", "main.c", 50, []string{"buf", "sizeof(buf)", "\"%s\"", "val"}, true, "string"),
	}
	decls := []parser.Declaration{
		makeDecl("buf", 256),
	}
	filtered, audit := PrescreenCallSites(sites, decls)
	if len(filtered) != 0 {
		t.Errorf("expected 0 remaining (safe sizeof match), got %d", len(filtered))
	}
	if audit.SafeCount != 1 {
		t.Errorf("expected 1 safe, got %d", audit.SafeCount)
	}
}

func TestPrescreen_BufferOverflow_MemcpySSafe(t *testing.T) {
	// T7: memcpy_s(dst, sizeof(dst), src, n) with char dst[64]
	sites := []parser.CallSite{
		makeCallSite("memcpy_s", "main.c", 60, []string{"dst", "sizeof(dst)", "src", "n"}, true, "memory"),
	}
	decls := []parser.Declaration{
		makeDecl("dst", 64),
	}
	filtered, audit := PrescreenCallSites(sites, decls)
	if len(filtered) != 0 {
		t.Errorf("expected 0 remaining (safe memcpy_s), got %d", len(filtered))
	}
	if audit.SafeCount != 1 {
		t.Errorf("expected 1 safe, got %d", audit.SafeCount)
	}
}

func TestPrescreen_BufferOverflow_MemcpyUnsafe(t *testing.T) {
	// T8: memcpy(dst, src, n) — unsafe variant, must remain
	sites := []parser.CallSite{
		makeCallSite("memcpy", "main.c", 60, []string{"dst", "src", "n"}, false, "memory"),
	}
	decls := []parser.Declaration{
		makeDecl("dst", 64),
	}
	filtered, audit := PrescreenCallSites(sites, decls)
	if len(filtered) != 1 {
		t.Errorf("expected 1 remaining (unsafe memcpy), got %d", len(filtered))
	}
	if audit.SafeCount != 0 {
		t.Errorf("expected 0 safe for unsafe memcpy, got %d", audit.SafeCount)
	}
}

func TestPrescreen_BufferOverflow_EmptySignals(t *testing.T) {
	// T9: empty signal list
	filtered, audit := PrescreenCallSites(nil, nil)
	if len(filtered) != 0 {
		t.Errorf("expected 0 remaining for empty input, got %d", len(filtered))
	}
	if audit.TotalSignals != 0 {
		t.Errorf("expected TotalSignals=0, got %d", audit.TotalSignals)
	}
}

func TestPrescreen_BufferOverflow_NoDeclarations(t *testing.T) {
	// T10: call_sites exists but no decls map — all remain as unknown
	sites := []parser.CallSite{
		makeCallSite("strcpy_s", "main.c", 42, []string{"buf", "sizeof(buf)", "src"}, true, "string"),
		makeCallSite("strcpy", "main.c", 50, []string{"buf", "src"}, false, "string"),
	}
	filtered, audit := PrescreenCallSites(sites, nil)
	if len(filtered) != 2 {
		t.Errorf("expected 2 remaining (no decls → all unknown), got %d", len(filtered))
	}
	if audit.SafeCount != 0 {
		t.Errorf("expected 0 safe without decls, got %d", audit.SafeCount)
	}
	if audit.UnknownCount != 2 {
		t.Errorf("expected 2 unknown without decls, got %d", audit.UnknownCount)
	}
}

func TestPrescreen_BufferOverflow_GetsSSafe(t *testing.T) {
	// T11: gets_s(buf, sizeof(buf)) with char buf[128]
	sites := []parser.CallSite{
		makeCallSite("gets_s", "main.c", 70, []string{"buf", "sizeof(buf)"}, true, "string"),
	}
	decls := []parser.Declaration{
		makeDecl("buf", 128),
	}
	filtered, audit := PrescreenCallSites(sites, decls)
	if len(filtered) != 0 {
		t.Errorf("expected 0 remaining (safe gets_s), got %d", len(filtered))
	}
	if audit.SafeCount != 1 {
		t.Errorf("expected 1 safe, got %d", audit.SafeCount)
	}
}

func TestPrescreen_BufferOverflow_MixedSignals(t *testing.T) {
	// T12: 3 safe + 2 unknown signals
	sites := []parser.CallSite{
		makeCallSite("strcpy_s", "a.c", 10, []string{"a", "sizeof(a)", "s"}, true, "string"),   // safe
		makeCallSite("strcpy_s", "a.c", 20, []string{"b", "sizeof(b)", "s"}, true, "string"),   // safe
		makeCallSite("strcpy_s", "a.c", 30, []string{"c", "sizeof(c)", "s"}, true, "string"),   // safe
		makeCallSite("strcpy_s", "b.c", 10, []string{"p", "n", "s"}, true, "string"),           // unknown (ptr)
		makeCallSite("strcpy", "b.c", 20, []string{"d", "s"}, false, "string"),                  // unknown (unsafe)
	}
	decls := []parser.Declaration{
		makeDecl("a", 64),
		makeDecl("b", 128),
		makeDecl("c", 256),
	}
	filtered, audit := PrescreenCallSites(sites, decls)
	if len(filtered) != 2 {
		t.Errorf("expected 2 remaining, got %d", len(filtered))
	}
	if audit.SafeCount != 3 {
		t.Errorf("expected 3 safe, got %d", audit.SafeCount)
	}
	if audit.UnknownCount != 2 {
		t.Errorf("expected 2 unknown, got %d", audit.UnknownCount)
	}
	if audit.TotalSignals != 5 {
		t.Errorf("expected TotalSignals=5, got %d", audit.TotalSignals)
	}
	// Verify safe details contain the right callees
	safeCallees := make(map[string]bool)
	for _, r := range audit.SafeDetails {
		safeCallees[r.Callee] = true
	}
	if !safeCallees["strcpy_s"] {
		t.Errorf("expected strcpy_s in safe details, got %v", safeCallees)
	}
	// Verify safety reasons mention sizeof match
	hasSizeofReason := false
	for _, r := range audit.SafeDetails {
		if r.Reason != "" {
			hasSizeofReason = true
			break
		}
	}
	if !hasSizeofReason {
		t.Error("expected at least one safe detail to have a reason")
	}
}
