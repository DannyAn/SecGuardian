package parser

type ParseResult struct {
	File      string         `json:"file"`
	Language  string         `json:"language"`
	Functions []FunctionInfo `json:"functions"`
	Variables []VariableInfo `json:"variables"`
	Types     []TypeInfo     `json:"types"`
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
