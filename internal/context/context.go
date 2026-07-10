package context

import (
	"github.com/secguardian/internal/indexer"
	"github.com/secguardian/internal/parser"
)

// AnalysisContext is the shared, pre-indexed understanding of a codebase.
// Built once by the indexer, consumed by all skills/detectors.
type AnalysisContext struct {
	Path            string              `json:"path"`
	FileCount       int                 `json:"file_count"`
	FunctionCount   int                 `json:"function_count"`
	CallEdgeCount   int                 `json:"call_edge_count"`
	PrimaryLanguage string              `json:"primary_language"`
	Files           []string            `json:"files"`
	Symbols   indexer.SymbolIndex `json:"symbols"`
	CallGraph indexer.CallGraph  `json:"call_graph"`
	AllocFree indexer.AllocFreeMap `json:"alloc_free"`
	LockGraph indexer.LockGraph  `json:"lock_graph"`
	// Signal Matrix (EPIC-007)
	CallSites         []parser.CallSite          `json:"call_sites"`
	StringLiterals    []parser.StringLiteral     `json:"string_literals,omitempty"`
	Declarations      []parser.Declaration       `json:"declarations,omitempty"`
	ValueConstants    []parser.ValueConstant     `json:"value_constants,omitempty"`
	Imports           []parser.Import            `json:"imports,omitempty"`
	ConfigPatterns    []parser.ConfigPattern     `json:"config_patterns,omitempty"`
	ControlFlow       []parser.ControlFlowSignal `json:"control_flow,omitempty"`
	PointerValidations []parser.PointerValidation `json:"pointer_validations,omitempty"`
	StructInits       []parser.StructInit        `json:"struct_inits,omitempty"`
	VariableWrites    []parser.VariableWrite     `json:"variable_writes,omitempty"`
	// CFG (EPIC-011 FEATURE-002): per-function control-flow graphs. Provides
	// engine-grounded reachability/dominance facts to detectors and the AI
	// Investigator. Empty on the regex (non-cgo) fallback path.
	CFGs []parser.FunctionCFG `json:"cfgs,omitempty"`
	// S11 SuspiciousExpression (EPIC-011): engine-detected semantic AST patterns.
	SuspiciousExpressions []parser.SuspiciousExpression `json:"suspicious_expressions,omitempty"`
}
