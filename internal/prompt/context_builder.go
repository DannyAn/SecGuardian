package prompt

import (
	"github.com/secguardian/internal/context"
	"github.com/secguardian/internal/indexer"
	"github.com/secguardian/internal/parser"
)

// ContextSlice contains the minimal prompt context for a single skill execution.
type ContextSlice struct {
	// Target function info
	TargetFile   string `json:"target_file"`
	TargetLine   uint   `json:"target_line"`
	FunctionName string `json:"function_name"`
	FunctionBody string `json:"function_body"`

	// One-hop callers and callees
	Callers []CallerInfo `json:"callers,omitempty"`
	Callees []CalleeInfo `json:"callees,omitempty"`

	// Relevant symbols (types, variables used in target function)
	RelevantTypes     []parser.TypeInfo     `json:"relevant_types,omitempty"`
	RelevantVariables []parser.VariableInfo `json:"relevant_variables,omitempty"`

	// Alloc/free pairs relevant to target function
	AllocFreePairs []indexer.AllocFreePair `json:"alloc_free_pairs,omitempty"`

	// Estimated token count
	EstimatedTokens int `json:"estimated_tokens"`
}

// CallerInfo describes a function that calls the target.
type CallerInfo struct {
	Name string `json:"name"`
	File string `json:"file"`
	Line uint   `json:"line"`
}

// CalleeInfo describes a function that the target calls.
type CalleeInfo struct {
	Name string `json:"name"`
	File string `json:"file"`
	Line uint   `json:"line"`
}

// BuildSlice builds a ContextSlice from the AnalysisContext targeting a specific file:line.
// It extracts only the information relevant to that location.
func BuildSlice(actx *context.AnalysisContext, targetFile string, targetLine uint) ContextSlice {
	slice := ContextSlice{
		TargetFile: targetFile,
		TargetLine: targetLine,
	}

	// Find the function containing this line
	for _, fn := range actx.Symbols.Functions {
		if fn.File == targetFile && targetLine >= fn.StartLine && targetLine <= fn.EndLine {
			slice.FunctionName = fn.Name
			break
		}
	}

	// Find callers (1-hop up)
	for _, edge := range actx.CallGraph.Edges {
		if edge.Callee == slice.FunctionName {
			slice.Callers = append(slice.Callers, CallerInfo{
				Name: edge.Caller,
				File: edge.File,
				Line: edge.Line,
			})
		}
	}

	// Find callees (1-hop down)
	for _, edge := range actx.CallGraph.Edges {
		if edge.Caller == slice.FunctionName {
			slice.Callees = append(slice.Callees, CalleeInfo{
				Name: edge.Callee,
				File: edge.File,
				Line: edge.Line,
			})
		}
	}

	// Add types defined in the same file
	for _, t := range actx.Symbols.Types {
		if t.File == targetFile {
			slice.RelevantTypes = append(slice.RelevantTypes, t)
		}
	}

	// Add variables defined in the same function
	for _, v := range actx.Symbols.Variables {
		if v.File == targetFile {
			// Approximate: include file-level variables
			slice.RelevantVariables = append(slice.RelevantVariables, v)
		}
	}

	// Add alloc/free pairs from same file
	for _, p := range actx.AllocFree.Pairs {
		if p.AllocFile == targetFile {
			slice.AllocFreePairs = append(slice.AllocFreePairs, p)
		}
	}

	// Estimate tokens (rough: 1 token ≈ 4 chars)
	total := 0
	total += len(slice.FunctionName) / 4
	total += len(slice.FunctionBody) / 4
	total += len(slice.Callers) * 10
	total += len(slice.Callees) * 10
	total += len(slice.RelevantTypes) * 5
	total += len(slice.RelevantVariables) * 3
	total += len(slice.AllocFreePairs) * 8
	slice.EstimatedTokens = total

	return slice
}
