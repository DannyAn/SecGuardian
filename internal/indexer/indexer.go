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
					pair := AllocFreePair{
						AllocFunc: afn,
						AllocFile: result.File,
						AllocLine: uint(i + 1),
					}
					for j, fline := range lines {
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
