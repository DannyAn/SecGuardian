package indexer

import (
	"fmt"
	"strings"

	"github.com/secguardian/internal/parser"
)

// ── Verdict types ──────────────────────────────────────────────────

// PrescreenVerdict is the result of prescreening a single call site.
type PrescreenVerdict int

const (
	// VerdictUnknown — cannot be deterministically proven safe; keep for LLM.
	VerdictUnknown PrescreenVerdict = iota
	// VerdictSafe — deterministically proven safe; remove from LLM input.
	VerdictSafe
)

// PrescreenResult holds the prescreen outcome for a single call site.
type PrescreenResult struct {
	Callee  string           // function name
	File    string           // source file
	Line    uint             // line number
	Verdict PrescreenVerdict // safe or unknown
	Reason  string           // human-readable justification
}

// PrescreenAudit aggregates prescreening statistics across all call sites.
type PrescreenAudit struct {
	TotalSignals   int
	SafeCount      int
	UnknownCount   int
	SafeDetails    []PrescreenResult
	UnknownDetails []PrescreenResult
}

// ── Function tables ─────────────────────────────────────────────────

// safeVariantCallees are _s (Annex K) and other equivalent safe-variant
// function names whose buffer-overflow risk can be assessed via sizeof matching.
var safeVariantCallees = map[string]bool{
	"strcpy_s":  true,
	"strcat_s":  true,
	"sprintf_s": true,
	"memcpy_s":  true,
	"gets_s":    true,
	"snprintf":  true,
}

// dynamicAllocFuncs are allocation functions. When their name appears as a
// call-site argument (the source of a copy), the call remains suspicious
// even if sizeof matches — the allocated size may be insufficient.
var dynamicAllocFuncs = map[string]bool{
	"malloc":  true,
	"calloc":  true,
	"realloc": true,
}

// ── Public API ──────────────────────────────────────────────────────

// PrescreenCallSites applies deterministic pre-screening rules to a set of
// call sites. Sites classified VerdictSafe are removed from the returned
// slice — only suspect / unknown sites are passed through to the LLM.
//
// A conservative strategy is used: only high-confidence safe verdicts
// result in removal; any uncertainty keeps the site in the returned list.
func PrescreenCallSites(allSites []parser.CallSite, allDecls []parser.Declaration) (filtered []parser.CallSite, audit PrescreenAudit) {
	declMap := make(map[string]parser.Declaration)
	for _, d := range allDecls {
		declMap[d.Name] = d
	}

	audit = PrescreenAudit{TotalSignals: len(allSites)}
	filtered = make([]parser.CallSite, 0, len(allSites))

	for _, site := range allSites {
		r := prescreenCallSite(site, declMap)
		switch r.Verdict {
		case VerdictSafe:
			audit.SafeCount++
			audit.SafeDetails = append(audit.SafeDetails, r)
		default:
			audit.UnknownCount++
			audit.UnknownDetails = append(audit.UnknownDetails, r)
			filtered = append(filtered, site)
		}
	}
	return
}

// ── Per-signal prescreening ─────────────────────────────────────────

func prescreenCallSite(site parser.CallSite, declMap map[string]parser.Declaration) PrescreenResult {
	r := PrescreenResult{
		Callee: site.CalleeName,
		File:   site.File,
		Line:   site.Line,
	}

	// Only safe-variant callees can be prescreened.
	if !safeVariantCallees[site.CalleeName] {
		r.Verdict = VerdictUnknown
		r.Reason = "not a safe variant — pass through"
		return r
	}

	// Need at least a destination buffer and a size argument.
	if len(site.Arguments) < 2 {
		r.Verdict = VerdictUnknown
		r.Reason = "too few arguments to validate"
		return r
	}

	dest := site.Arguments[0]
	decl, ok := declMap[dest]
	if !ok {
		r.Verdict = VerdictUnknown
		r.Reason = fmt.Sprintf("'%s' not found in declarations", dest)
		return r
	}
	if decl.ArraySize <= 0 {
		r.Verdict = VerdictUnknown
		r.Reason = fmt.Sprintf("'%s' is not a known stack array (ArraySize=%d)", dest, decl.ArraySize)
		return r
	}

	// Check for sizeof(dest) in any argument past the first one.
	sizeofPattern := fmt.Sprintf("sizeof(%s)", dest)
	foundSizeof := false
	for _, arg := range site.Arguments[1:] {
		if strings.Contains(arg, sizeofPattern) {
			foundSizeof = true
			break
		}
	}
	if !foundSizeof {
		r.Verdict = VerdictUnknown
		r.Reason = fmt.Sprintf("no sizeof(%s) found in arguments", dest)
		return r
	}

	// If the source argument is a dynamic-allocation function name,
	// sizeof correctness alone is not sufficient proof of safety.
	for _, arg := range site.Arguments {
		trimmed := strings.TrimSpace(arg)
		if dynamicAllocFuncs[trimmed] {
			r.Verdict = VerdictUnknown
			r.Reason = fmt.Sprintf("sizeof(%s)=%d matches but source is dynamic (%s)", dest, decl.ArraySize, trimmed)
			return r
		}
	}

	r.Verdict = VerdictSafe
	r.Reason = fmt.Sprintf("sizeof(%s)=%d matches char[%d]", dest, decl.ArraySize, decl.ArraySize)
	return r
}
