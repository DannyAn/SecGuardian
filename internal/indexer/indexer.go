package indexer

import (
	"os"
	"strings"

	"github.com/secguardian/internal/parser"
)

type SymbolIndex struct {
	Functions []parser.FunctionInfo `json:"functions"`
	Variables []parser.VariableInfo `json:"variables"`
	Types     []parser.TypeInfo     `json:"types"`
}

type CallGraphEdge struct {
	Caller string `json:"caller"`
	Callee string `json:"callee"`
	File   string `json:"file"`
	Line   uint   `json:"line"`
}

type CallGraph struct {
	Edges []CallGraphEdge `json:"edges"`
}

type FreeSite struct {
	File string `json:"file"`
	Line uint   `json:"line"`
}

type AllocFreePair struct {
	AllocFunc string     `json:"alloc_func"`
	AllocFile string     `json:"alloc_file"`
	AllocLine uint       `json:"alloc_line"`
	FreeSites []FreeSite `json:"free_sites"`
}

type AllocFreeMap struct {
	Pairs []AllocFreePair `json:"pairs"`
}

type LockUsage struct {
	MutexName  string `json:"mutex_name"`
	LockLine   uint   `json:"lock_line"`
	UnlockLine uint   `json:"unlock_line"`
	File       string `json:"file"`
}

type LockGraph struct {
	Mutexes []LockUsage `json:"mutexes"`
}

func ExtractSymbols(parsed map[string]*parser.ParseResult) SymbolIndex {
	idx := SymbolIndex{}
	for _, result := range parsed {
		idx.Functions = append(idx.Functions, result.Functions...)
		idx.Variables = append(idx.Variables, result.Variables...)
		idx.Types = append(idx.Types, result.Types...)
	}
	return idx
}

// isCommentLine checks if a trimmed line looks like a comment line (heuristic).
func isCommentLine(line string) bool {
	trimmed := strings.TrimSpace(line)
	return strings.HasPrefix(trimmed, "//") || strings.HasPrefix(trimmed, "/*") ||
		strings.HasPrefix(trimmed, "* ")
}

// BuildCallGraph scans each function body for calls to other known functions.
func BuildCallGraph(parsed map[string]*parser.ParseResult, symbols SymbolIndex) CallGraph {
	cg := CallGraph{}

	for _, result := range parsed {
		content, err := os.ReadFile(result.File)
		if err != nil {
			continue
		}
		lines := strings.Split(string(content), "\n")

		for _, fn := range result.Functions {
			start := int(fn.StartLine) - 1
			end := int(fn.EndLine)
			if start < 0 {
				start = 0
			}
			if end > len(lines) {
				end = len(lines)
			}
			body := strings.Join(lines[start:end], " ")

			for _, callee := range symbols.Functions {
				if callee.Name == fn.Name {
					continue
				}
				if strings.Contains(body, callee.Name+"(") || strings.Contains(body, callee.Name+" (") {
					// Skip if the call appears only in comment lines
					foundInCode := false
					for i := start; i < end; i++ {
						if i >= len(lines) {
							break
						}
						if isCommentLine(lines[i]) {
							continue
						}
						if strings.Contains(lines[i], callee.Name+"(") || strings.Contains(lines[i], callee.Name+" (") {
							foundInCode = true
							break
						}
					}
					if !foundInCode {
						continue
					}
					cg.Edges = append(cg.Edges, CallGraphEdge{
						Caller: fn.Name,
						Callee: callee.Name,
						File:   fn.File,
						Line:   fn.StartLine,
					})
				}
			}
		}
	}
	return cg
}

// MatchAllocFree finds malloc/calloc/realloc and their corresponding free/delete calls.
func MatchAllocFree(parsed map[string]*parser.ParseResult) AllocFreeMap {
	af := AllocFreeMap{}
	allocFns := map[string]bool{"malloc": true, "calloc": true, "realloc": true}
	freeFns := map[string]bool{"free": true, "delete": true}

	for _, result := range parsed {
		// Build function scopes from parse result (not re-reading file)
		type fnScope struct{ start, end uint }
		scopes := []fnScope{}
		for _, fn := range result.Functions {
			scopes = append(scopes, fnScope{fn.StartLine, fn.EndLine})
		}

		content, err := os.ReadFile(result.File)
		if err != nil {
			continue
		}
		lines := strings.Split(string(content), "\n")

		for i, line := range lines {
			if isCommentLine(line) {
				continue
			}
			for afn := range allocFns {
				if strings.Contains(line, afn+"(") {
					allocLine := uint(i + 1)

					// Find containing function scope to bound free search
					searchStart, searchEnd := 0, len(lines)
					for _, s := range scopes {
						if allocLine >= s.start && allocLine <= s.end {
							searchStart = int(s.start - 1) // 0-indexed
							searchEnd = int(s.end)
							break
						}
					}

					pair := AllocFreePair{
						AllocFunc: afn,
						AllocFile: result.File,
						AllocLine: allocLine,
					}
					for j := searchStart; j < searchEnd; j++ {
						fline := lines[j]
						if isCommentLine(fline) {
							continue
						}
						for ffn := range freeFns {
							if strings.Contains(fline, ffn+"(") {
								pair.FreeSites = append(pair.FreeSites, FreeSite{
									File: result.File,
									Line: uint(j + 1),
								})
							}
						}
					}
					if len(pair.FreeSites) > 0 {
						af.Pairs = append(af.Pairs, pair)
					}
				}
			}
		}
	}
	return af
}

// BuildLockGraph scans for mutex lock/unlock patterns.
func BuildLockGraph(parsed map[string]*parser.ParseResult) LockGraph {
	lg := LockGraph{}
	lockPatterns := []string{
		"pthread_mutex_lock", "pthread_mutex_unlock",
	}

	for _, result := range parsed {
		content, err := os.ReadFile(result.File)
		if err != nil {
			continue
		}
		lines := strings.Split(string(content), "\n")
		for i, line := range lines {
			for _, pat := range lockPatterns {
				if strings.Contains(line, pat) {
					lg.Mutexes = append(lg.Mutexes, LockUsage{
						File:     result.File,
						LockLine: uint(i + 1),
					})
				}
			}
		}
	}
	return lg
}

// BuildCallGraphV2 rebuilds the call graph directly from extracted call_sites.
// Unlike V1 which searches each function body for calls to other user-defined
// functions, V2 uses the already-extracted call_sites — including library calls.
// This yields orders-of-magnitude more edges and enables data-flow tracing.
func BuildCallGraphV2(callSites []parser.CallSite, symbols SymbolIndex) CallGraph {
	cg := CallGraph{}
	seen := make(map[string]bool)

	for _, cs := range callSites {
		key := cs.CallerFunction + ":" + cs.CalleeName + ":" + cs.File + ":" + itoa(cs.Line)
		if seen[key] {
			continue
		}
		seen[key] = true
		cg.Edges = append(cg.Edges, CallGraphEdge{
			Caller: cs.CallerFunction,
			Callee: cs.CalleeName,
			File:   cs.File,
			Line:   cs.Line,
		})
	}

	return cg
}

func itoa(n uint) string {
	if n == 0 {
		return "0"
	}
	var buf [20]byte
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	return string(buf[i:])
}

// MergeCallGraphs combines two call graphs, deduplicating edges by
// (caller, callee, file, line) — the same key used in BuildCallGraphV2.
func MergeCallGraphs(a, b CallGraph) CallGraph {
	seen := make(map[string]bool)
	merged := CallGraph{}
	for _, cg := range []CallGraph{a, b} {
		for _, e := range cg.Edges {
			key := e.Caller + ":" + e.Callee + ":" + e.File + ":" + itoa(e.Line)
			if seen[key] {
				continue
			}
			seen[key] = true
			merged.Edges = append(merged.Edges, e)
		}
	}
	return merged
}

// GroupByFunction aggregates all call_sites and variable-level signals
// by function, producing a per-function context suitable for batch dispatch.
func GroupByFunction(
	parsed map[string]*parser.ParseResult,
	callSites []parser.CallSite,
	varWrites []parser.VariableWrite,
	ptrValidations []parser.PointerValidation,
	taintFlows []parser.TaintFlow,
	allocFree AllocFreeMap,
	callGraph CallGraph,
) []parser.FunctionCallContext {
	type funcMeta struct {
		file      string
		startLine uint
		endLine   uint
	}
	funcMap := make(map[string]funcMeta)
	for _, result := range parsed {
		for _, fn := range result.Functions {
			funcMap[fn.Name] = funcMeta{
				file:      result.File,
				startLine: fn.StartLine,
				endLine:   fn.EndLine,
			}
		}
	}

	type agg struct {
		callSites      []parser.CallSite
		varWrites      []parser.VariableWrite
		ptrValidations []parser.PointerValidation
		taintFlows     []parser.TaintFlow
		allocPairs     []AllocFreePair
		callers        map[string]bool
		callees        map[string]bool
	}
	aggs := make(map[string]*agg)

	for _, cs := range callSites {
		fn := cs.CallerFunction
		a := aggs[fn]
		if a == nil {
			a = &agg{callers: make(map[string]bool), callees: make(map[string]bool)}
			aggs[fn] = a
		}
		a.callSites = append(a.callSites, cs)
		a.callees[cs.CalleeName] = true
	}

	for _, vw := range varWrites {
		if vw.Function == "" {
			continue
		}
		a := aggs[vw.Function]
		if a == nil {
			a = &agg{callers: make(map[string]bool), callees: make(map[string]bool)}
			aggs[vw.Function] = a
		}
		a.varWrites = append(a.varWrites, vw)
	}

	for _, pv := range ptrValidations {
		if pv.Function == "" {
			continue
		}
		a := aggs[pv.Function]
		if a == nil {
			a = &agg{callers: make(map[string]bool), callees: make(map[string]bool)}
			aggs[pv.Function] = a
		}
		a.ptrValidations = append(a.ptrValidations, pv)
	}

	for _, tf := range taintFlows {
		if tf.Function == "" {
			continue
		}
		a := aggs[tf.Function]
		if a == nil {
			a = &agg{callers: make(map[string]bool), callees: make(map[string]bool)}
			aggs[tf.Function] = a
		}
		a.taintFlows = append(a.taintFlows, tf)
	}

	for _, pair := range allocFree.Pairs {
		for fnName, meta := range funcMap {
			if pair.AllocFile == meta.file &&
				pair.AllocLine >= meta.startLine &&
				pair.AllocLine <= meta.endLine {
				a := aggs[fnName]
				if a == nil {
					a = &agg{callers: make(map[string]bool), callees: make(map[string]bool)}
					aggs[fnName] = a
				}
				a.allocPairs = append(a.allocPairs, pair)
				break
			}
		}
	}

	for _, e := range callGraph.Edges {
		a := aggs[e.Callee]
		if a != nil {
			a.callers[e.Caller] = true
		}
	}

	result := make([]parser.FunctionCallContext, 0, len(aggs))
	for fnName, a := range aggs {
		meta, ok := funcMap[fnName]
		if !ok {
			continue
		}
		callerList := make([]string, 0, len(a.callers))
		for c := range a.callers {
			callerList = append(callerList, c)
		}
		calleeList := make([]string, 0, len(a.callees))
		for c := range a.callees {
			calleeList = append(calleeList, c)
		}
		// Convert AllocFreePair to parser.AllocFreeRef (avoid circular import)
		afRefs := make([]parser.AllocFreeRef, 0, len(a.allocPairs))
		for _, pair := range a.allocPairs {
			freeSites := make([]parser.FreeSite, 0, len(pair.FreeSites))
			for _, fs := range pair.FreeSites {
				freeSites = append(freeSites, parser.FreeSite{Line: fs.Line})
			}
			afRefs = append(afRefs, parser.AllocFreeRef{
				AllocFunc: pair.AllocFunc,
				AllocLine: pair.AllocLine,
				FreeSites: freeSites,
			})
		}
		result = append(result, parser.FunctionCallContext{
			Function:       fnName,
			File:           meta.file,
			StartLine:      meta.startLine,
			EndLine:        meta.endLine,
			Callers:        callerList,
			Callees:        calleeList,
			CallSites:      a.callSites,
			VariableWrites: a.varWrites,
			PointerChecks:  a.ptrValidations,
			TaintFlows:     a.taintFlows,
			AllocFreePairs: afRefs,
		})
	}
	return result
}
