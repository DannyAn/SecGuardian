package parser

// CallSite represents a library function call detected in source code.
// Unlike FunctionInfo which tracks function definitions, CallSite tracks
// each invocation of a known library function (strcpy, malloc, system, etc.).
// This is the primary signal source for Worker scheduling in the
// Dispatcher-Worker paradigm (EPIC-3).
type CallSite struct {
	CallerFunction string   `json:"caller"`
	CalleeName     string   `json:"callee"`
	File           string   `json:"file"`
	Line           uint     `json:"line"`
	Arguments      []string `json:"arguments"`
	IsSafeVariant  bool     `json:"safe_variant"`
	Category       string   `json:"category"`
}

type ParseResult struct {
	File      string         `json:"file"`
	Language  string         `json:"language"`
	Functions []FunctionInfo `json:"functions"`
	Variables []VariableInfo `json:"variables"`
	Types     []TypeInfo     `json:"types"`
	CallSites []CallSite     `json:"call_sites"`
}

type FunctionInfo struct {
	Name      string `json:"name"`
	File      string `json:"file"`
	StartLine uint   `json:"start_line"`
	EndLine   uint   `json:"end_line"`
}

type VariableInfo struct {
	Name string `json:"name"`
	File string `json:"file"`
	Line uint   `json:"line"`
}

type TypeInfo struct {
	Name      string `json:"name"`
	Kind      string `json:"kind"`
	File      string `json:"file"`
	StartLine uint   `json:"start_line"`
}
