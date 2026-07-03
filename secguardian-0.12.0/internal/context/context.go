package context

import "github.com/secguardian/internal/indexer"

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
}
