package parser

import (
	"regexp"
	"strings"
)



// ── Signal Matrix (EPIC-007) ─────────────────────────────────

// CallSite represents a library function call detected in source code.
// S1 signal — the core driver for memory safety, injection, and resource analysis.
type CallSite struct {
	CallerFunction string   `json:"caller"`
	CalleeName     string   `json:"callee"`
	File           string   `json:"file"`
	Line           uint     `json:"line"`
	Arguments      []string `json:"arguments"`
	IsSafeVariant  bool     `json:"safe_variant"`
	Category       string   `json:"category"`
	ReceiverExpr   string   `json:"receiver,omitempty"`
	ReceiverType   string   `json:"receiver_type,omitempty"`
}

// StringLiteral represents a string constant detected in source code.
// S2 signal — for hardcoded secrets, credentials, tokens, URLs.
type StringLiteral struct {
	File    string   `json:"file"`
	Line    uint     `json:"line"`
	Value   string   `json:"value"`
	Length  int      `json:"length"`
	Context string   `json:"context"` // enclosing function name, "global", or assignment target
	Kinds   []string `json:"kinds"`   // inferred: "secret","password","api_key","jwt","url","cipher_name","sql","generic"
}

// Declaration represents a type/variable declaration with size information.
// S3 signal — for key length, buffer size, struct field analysis.
type Declaration struct {
	File      string `json:"file"`
	Line      uint   `json:"line"`
	Name      string `json:"name"`
	TypeName  string `json:"type_name"`
	ArraySize int    `json:"array_size,omitempty"`
	IsPointer bool   `json:"is_pointer"`
	IsConst   bool   `json:"is_const"`
	Function  string `json:"function,omitempty"`
	Category  string `json:"category"` // "buffer","key","credential","counter"
}

// ValueConstant represents a numeric/algorithm constant in source code.
// S4 signal — for weak algorithm, short key, insecure mode detection.
type ValueConstant struct {
	File      string `json:"file"`
	Line      uint   `json:"line"`
	Value     string `json:"value"`
	ValueType string `json:"value_type"` // "number","identifier","function_ref","enum"
	Context   string `json:"context,omitempty"`
	Category  string `json:"category"` // "algorithm","key_length","mode","flag","constant"
}

// Import represents an include/import/module statement.
// S5 signal — for dependency audit and deprecated-API detection.
type Import struct {
	File     string `json:"file"`
	Line     uint   `json:"line"`
	Path     string `json:"path"`
	Kind     string `json:"kind"`     // "system","user","module","package"
	Category string `json:"category"` // "crypto","net","sys","db","web","unsafe","generic"
}

// ConfigPattern represents a security-relevant configuration assignment.
// S6 signal — for TLS, CORS, CSP, auth middleware config audit.
type ConfigPattern struct {
	File     string `json:"file"`
	Line     uint   `json:"line"`
	Key      string `json:"key"`
	Value    string `json:"value"`
	Category string `json:"category"` // "tls","cors","auth","session","csp","generic"
}

// ControlFlowSignal represents a control-flow guard pattern.
// S7 signal — for auth bypass, missing error check, missing validation detection.
type ControlFlowSignal struct {
	File      string `json:"file"`
	Line      uint   `json:"line"`
	Function  string `json:"function"`
	Kind      string `json:"kind"`                // "if_guard","return","error_check","loop"
	Condition string `json:"condition,omitempty"` // guard condition (max 128 chars)
	HasReturn bool   `json:"has_return,omitempty"`
	Target    string `json:"target,omitempty"`
	Category  string `json:"category"` // "auth","error","validation","bound_check"
}

// ── S8: PointerValidation — 指针入参校验信号 ──

// PointerValidation tracks whether function pointer parameters are checked for
// NULL before being dereferenced. Drives exec.input_validation rule expansion.
type PointerValidation struct {
	File           string `json:"file"`
	Line           uint   `json:"line"`
	Function       string `json:"function"`
	Variable       string `json:"variable"`
	ParamIndex     int    `json:"param_index,omitempty"` // -1 for local variables
	IsPointerParam bool   `json:"is_pointer_param"`
	HasNullCheck   bool   `json:"has_null_check"`   // if (!p) / if (p == NULL) found before use
	IsDereferenced bool   `json:"is_dereferenced"`  // *p / p->field without NULL check
	NullCheckLine  uint   `json:"null_check_line,omitempty"`
	DerefLine      uint   `json:"deref_line,omitempty"`
	Category       string `json:"category"` // "param_check" | "local_check"
}

// ── S9: StructInit — 结构体字段初始化状态信号 ──

// StructInit tracks whether all fields of a struct variable are initialized
// before first use. Drives memory.uninitialized rule.
type StructInit struct {
	File                string   `json:"file"`
	Line                uint     `json:"line"`
	StructType          string   `json:"struct_type"`
	Variable            string   `json:"variable"`
	TotalFields         int      `json:"total_fields"`
	InitializedFields   []string `json:"initialized_fields"`
	UninitializedFields []string `json:"uninitialized_fields"`
	IsHeapAlloc         bool     `json:"is_heap_alloc"`  // via malloc/calloc
	IsStackAlloc        bool     `json:"is_stack_alloc"` // local declaration without initializer
	Category            string   `json:"category"`       // "partial_init" | "full_init" | "no_init"
}

// ── S10: VariableWrite — 变量首次写追踪信号 ──

// VariableWrite tracks the relationship between variable declaration, first
// write, and first read. Drives detection of use-before-initialize.
type VariableWrite struct {
	File           string `json:"file"`
	Line           uint   `json:"line"`
	Function       string `json:"function"`
	Variable       string `json:"variable"`
	TypeName       string `json:"type_name"`
	DeclLine       uint   `json:"decl_line"`
	FirstReadLine  uint   `json:"first_read_line,omitempty"`  // >0 means read before write
	FirstWriteLine uint   `json:"first_write_line,omitempty"` // first assignment
	IsStructField  bool   `json:"is_struct_field"`
	FieldName      string `json:"field_name,omitempty"`
	IsInitialized  bool   `json:"is_initialized"` // has initializer at declaration
	Category       string `json:"category"`        // "read_before_write" | "written" | "declared_only"
}

// ── S11: SuspiciousExpression — 语义级可疑表达式模式 ──
//
// Engine-detected deterministic AST patterns that are classic semantic bug
// sources. The engine emits these so the LLM cannot miss them (engine recall
// floor); the LLM then judges intent (e.g. `if ((x = f()) != 0)` is intentional).
//
// Kind ∈:
//   assignment_in_condition — `if (x = 5)` (bare assignment as condition top-level)
//   operator_precedence     — `a & b == c` (lower-precedence op outer, no parens)
//   signed_unsigned_compare — `if (s < u)` signed vs unsigned operand (common case;
//                             complex-expression type inference is a future root-tech gap)
//   suspicious_boolean      — `!x = s` (negation of assignment), `a && b = c` (assignment in boolean)
type SuspiciousExpression struct {
	File     string `json:"file"`
	Line     uint   `json:"line"`
	Function string `json:"function"`
	Kind     string `json:"kind"`
	Detail   string `json:"detail"`   // human-readable explanation of why it's suspicious
	Snippet  string `json:"snippet"`  // the offending expression text
}

// ── S12: TaintFlow — Source→Sink 污点传播 ──
//
// Engine-detected intra-procedural taint: tainted data (from a Source API like
// getenv) flowing through assignments to a dangerous Sink (strcpy/system/...)
// without sanitization. This is the core capability traditional SAST has and
// SecGuardian previously lacked (EPIC-011 M2). Engine emits the flow (recall
// floor); LLM judges exploitability.
//
// v1 scope (honest limitations): return-tainted sources + assignment propagation
// + sink detection, intra-procedural, source-order (not path-sensitive).
// Arg-tainted sources (fgets/scanf/read write-to-arg), inter-procedural,
// path-sensitivity, aliasing are follow-ups.
type TaintFlow struct {
	File        string   `json:"file"`
	Function    string   `json:"function"`
	Source      string   `json:"source"`       // source API name (e.g. "getenv")
	SourceLine  uint     `json:"source_line"`
	Sink        string   `json:"sink"`         // sink API name (e.g. "strcpy")
	SinkLine    uint     `json:"sink_line"`
	TaintedVar  string   `json:"tainted_var"`
	Path        []string `json:"path"`         // ordered flow steps (human-readable)
	Category    string   `json:"category"`     // "overflow" | "injection" | "format_string" | "info"
}

// ParseResult holds all extracted information from a single file.
type ParseResult struct {
	File              string              `json:"file"`
	Language          string              `json:"language"`
	Functions         []FunctionInfo      `json:"functions"`
	Variables         []VariableInfo      `json:"variables"`
	Types             []TypeInfo          `json:"types"`
	CallSites         []CallSite          `json:"call_sites"`
	StringLiterals    []StringLiteral     `json:"string_literals,omitempty"`
	Declarations      []Declaration       `json:"declarations,omitempty"`
	ValueConstants    []ValueConstant     `json:"value_constants,omitempty"`
	Imports           []Import            `json:"imports,omitempty"`
	ConfigPatterns    []ConfigPattern     `json:"config_patterns,omitempty"`
	ControlFlow       []ControlFlowSignal `json:"control_flow,omitempty"`
	PointerValidations []PointerValidation `json:"pointer_validations,omitempty"`
	StructInits       []StructInit        `json:"struct_inits,omitempty"`
	VariableWrites    []VariableWrite     `json:"variable_writes,omitempty"`
	// CFG (EPIC-011 FEATURE-002): per-function control-flow graphs. Built only
	// on the tree-sitter (cgo) path; empty on the regex fallback path.
	CFGs []FunctionCFG `json:"cfgs,omitempty"`
	// S11 SuspiciousExpression (EPIC-011): semantic AST patterns. C/C++ for now.
	SuspiciousExpressions []SuspiciousExpression `json:"suspicious_expressions,omitempty"`
	// S12 TaintFlow (EPIC-011 M2): engine-detected Source→Sink taint. C/C++ v1.
	TaintFlows []TaintFlow `json:"taint_flows,omitempty"`
}

type FunctionInfo struct {
	Name       string `json:"name"`
	File       string `json:"file"`
	StartLine  uint   `json:"start_line"`
	EndLine    uint   `json:"end_line"`
	ClassName  string `json:"class_name,omitempty"`
	Visibility string `json:"visibility,omitempty"`
	IsStatic   bool   `json:"is_static,omitempty"`
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

// FileScope holds per-file type information for local type inference (FEATURE-003).
// Used only by Java tree-sitter parser to resolve CallSite.ReceiverType.
type FileScope struct {
	File      string
	Imports   map[string]string // short name -> FQN (e.g. "Map" -> "java.util.Map")
	Variables map[string]string // var name -> resolved type
	Fields    map[string]string // field name -> resolved type
}

func NewFileScope(file string) *FileScope {
	return &FileScope{
		File:      file,
		Imports:   make(map[string]string),
		Variables: make(map[string]string),
		Fields:    make(map[string]string),
	}
}


// ════════════════════════════════════════════════════════════════
// Shared Signal Extraction (used by both cgo and non-cgo builds)
// ════════════════════════════════════════════════════════════════

// ── S4: Value constant extraction ──────────────────────────

// extractValueConstants collects numeric literals and algorithm identifiers
// at the file level and inside function bodies.
func extractValueConstants(source []byte, file string) []ValueConstant {
	var vals []ValueConstant
	content := string(source)
	lines := strings.Split(content, "\n")

	for lineIdx, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "//") || strings.HasPrefix(trimmed, "/*") {
			continue
		}

		// Detect algorithm identifier patterns: EVP_aes_*, EVP_des_*, etc.
		algPat := algorithmRefPattern
		if matches := algPat.FindStringSubmatch(line); len(matches) > 1 {
			line := uint(lineIdx + 1)
			algo := matches[1]
			cat := "algorithm"
			switch {
			case strings.Contains(algo, "des"), strings.Contains(algo, "rc4"):
				cat = "algorithm"
			case strings.Contains(algo, "aes"), strings.Contains(algo, "chacha"):
				cat = "algorithm"
			case strings.Contains(algo, "md5"):
				cat = "algorithm"
			}
			vals = append(vals, ValueConstant{
				File:      file,
				Line:      line,
				Value:     algo,
				ValueType: "identifier",
				Category:  cat,
			})
		}

		// Detect key length numbers: key[7], key[56], key[128]
		keyPat := keyLenPattern
		if matches := keyPat.FindStringSubmatch(line); len(matches) > 1 {
			vals = append(vals, ValueConstant{
				File:      file,
				Line:      uint(lineIdx + 1),
				Value:     matches[1],
				ValueType: "number",
				Category:  "key_length",
			})
		}

		// Detect mode flags: DES_ENCRYPT, DES_DECRYPT, NID_*
		modePat := modeFlagPattern
		if matches := modePat.FindStringSubmatch(line); len(matches) > 1 {
			vals = append(vals, ValueConstant{
				File:      file,
				Line:      uint(lineIdx + 1),
				Value:     matches[1],
				ValueType: "enum",
				Category:  "flag",
			})
		}

		// Detect ECB mode name
		if strings.Contains(strings.ToLower(line), "ecb") &&
			strings.Contains(line, `"`) {
			vals = append(vals, ValueConstant{
				File:      file,
				Line:      uint(lineIdx + 1),
				Value:     "ECB",
				ValueType: "identifier",
				Category:  "mode",
			})
		}
	}
	return vals
}

// ── S6: Config pattern extraction ──────────────────────────

func extractConfigPatterns(source []byte, file string) []ConfigPattern {
	var patterns []ConfigPattern
	content := string(source)
	lines := strings.Split(content, "\n")

	for lineIdx, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "" || strings.HasPrefix(trimmed, "//") || strings.HasPrefix(trimmed, "/*") {
			continue
		}

		for _, cp := range configPatternEntries {
			if matches := cp.pattern.FindStringSubmatch(trimmed); len(matches) > 1 {
				val := ""
				if len(matches) > 2 {
					val = matches[2]
				} else if len(matches) > 1 {
					val = matches[1]
				}
				patterns = append(patterns, ConfigPattern{
					File:     file,
					Line:     uint(lineIdx + 1),
					Key:      matches[1],
					Value:    truncate(val, 128),
					Category: cp.category,
				})
				break
			}
		}
	}
	return patterns
}

type configPatternEntry struct {
	pattern  *regexp.Regexp
	category string
}

var configPatternEntries = []configPatternEntry{
	// TLS version
	{regexp.MustCompile(`(?i)(tls_version|min_version|ssl_version)\s*[=:]\s*["']?(1\.0|1\.1|ssl[_]?v3)["']?`), "tls"},
	{regexp.MustCompile(`(?i)(tls_version|min_version|ssl_version)\s*[=:]\s*["']?(1\.2|1\.3)["']?`), "tls"},

	// CORS
	{regexp.MustCompile(`(?i)(allow_origin|allowed_origins|cors_origin)\s*[=:]\s*["']?\*["']?`), "cors"},
	{regexp.MustCompile(`(?i)(access-control-allow-origin)\s*[=:]\s*["']?\*["']?`), "cors"},

	// Auth bypass
	{regexp.MustCompile(`(?i)(auth|authentication|require_auth)\s*[=:]\s*(false|off|none|disabled)`), "auth"},
	{regexp.MustCompile(`(?i)(enable_auth|auth_enabled)\s*[=:]\s*(false|off|0)`), "auth"},

	// Session security
	{regexp.MustCompile(`(?i)(secure)\s*[=:]\s*(false|off|0)`), "session"},
	{regexp.MustCompile(`(?i)(httponly|http_only)\s*[=:]\s*(false|off|0)`), "session"},
	{regexp.MustCompile(`(?i)(samesite)\s*[=:]\s*["']?none["']?`), "session"},

	// CSP
	{regexp.MustCompile(`(?i)(content-security-policy|csp)\s*[=:]`), "csp"},
}

// ── Utility ────────────────────────────────────────────────


// ── Shared: String kind inference (used by all parsers, no build tag) ──

func inferStringKind(val string) []string {
	var kinds []string
	lower := strings.ToLower(val)
	trimmed := strings.Trim(val, "\"'")

	// API keys and secrets
	if strings.HasPrefix(trimmed, "sk-") && len(trimmed) > 20 {
		kinds = append(kinds, "api_key")
	}
	if strings.Contains(lower, "api_key") || strings.Contains(lower, "apikey") {
		kinds = append(kinds, "api_key")
	}
	if strings.Contains(lower, "password") || strings.Contains(lower, "passwd") || strings.Contains(lower, "p@ssw0rd") {
		kinds = append(kinds, "password")
	}
	if strings.HasPrefix(trimmed, "eyJ") || strings.HasPrefix(trimmed, "eyj") {
		kinds = append(kinds, "jwt")
	}
	if strings.Contains(lower, "secret") || strings.Contains(lower, "token") || strings.Contains(lower, "auth") {
		kinds = append(kinds, "secret")
	}
	if strings.Contains(lower, "aes") || strings.Contains(lower, "des_") || strings.Contains(lower, "chacha") {
		kinds = append(kinds, "cipher_name")
	}
	if strings.HasPrefix(lower, "http://") || strings.HasPrefix(lower, "https://") {
		kinds = append(kinds, "url")
	}
	if strings.Contains(lower, "select ") || strings.Contains(lower, "from ") || strings.Contains(lower, "where ") {
		kinds = append(kinds, "sql")
	}
	if len(kinds) == 0 {
		kinds = append(kinds, "generic")
	}
	return kinds
}

func truncate(s string, maxLen int) string {
	if len(s) <= maxLen {
		return s
	}
	return s[:maxLen] + "..."
}

// ParserMode is set by build-tag-gated files to indicate which parser is active.
// "tree-sitter (CGO)" when cgo build tag is set, "regex (!CGO)" otherwise.
var ParserMode string

// ── Regex patterns for value constant extraction (S4) ──

var algorithmRefPattern = regexp.MustCompile(`(?i)(EVP_[a-z0-9_]+|EVP_[A-Z][a-z]+_[0-9a-z_]+|NID_[a-z0-9_]+)`)
var keyLenPattern = regexp.MustCompile(`(?i)(?:key|size|len)\s*\[(7|8|16|24|32|40|56|64|80|128|168|192|256)\]`)
var modeFlagPattern = regexp.MustCompile(`(?i)(DES_ENCRYPT|DES_DECRYPT|NID_[A-Z_]+|AES_[A-Z]+|SSL_[A-Z]+|TLS_[A-Z]+)`)

// ── S8: PointerValidation extraction (regex fallback) ──

// ptrParamPattern matches function parameters declared as pointer types.
// Captures: function name at start of definition, then pointer params.
var ptrParamPattern = regexp.MustCompile(`(?m)^\s*(?:static\s+)?(?:inline\s+)?\w+\s*\*?\s*(\w+)\s*\([^)]*\)`)
var nullCheckPattern = regexp.MustCompile(`(?m)if\s*\(\s*!?\s*(\w+)\s*(?:==\s*NULL|!=\s*NULL)?\s*\)`)
var ptrDerefPattern = regexp.MustCompile(`(?m)(?:(\w+)\s*->|\(\s*\*\s*(\w+)\s*\))`)

// extractPointerValidationsRegex uses simple heuristics: find functions that
// take pointer parameters, then check for NULL guards before dereferences.
// Regex-only approach is deliberately conservative — false negatives are
// acceptable (TreeSitter path provides precision); false positives are not.
func extractPointerValidationsRegex(source []byte, file string, functions []FunctionInfo) []PointerValidation {
	var results []PointerValidation
	content := string(source)
	lines := strings.Split(content, "\n")

	for _, fn := range functions {
		// Collect pointer params from function signature
		funcLines := lines[fn.StartLine-1 : min(int(fn.EndLine), len(lines))]
		funcBody := strings.Join(funcLines, "\n")

		// Find pointer dereferences (-> or *ptr)
		derefMatches := ptrDerefPattern.FindAllStringSubmatch(funcBody, -1)
		if len(derefMatches) == 0 {
			continue
		}

		derefVars := make(map[string]uint)
		for _, dm := range derefMatches {
			varName := dm[1]
			if varName == "" {
				varName = dm[2]
			}
			if varName != "" && varName != "if" && varName != "while" && varName != "for" && varName != "return" && varName != "sizeof" {
				for i, dl := range funcLines {
					if strings.Contains(dl, "->"+varName) || strings.Contains(dl, varName+"->") || strings.Contains(dl, "*"+varName) {
						derefVars[varName] = uint(int(fn.StartLine) + i)
						break
					}
				}
			}
		}

		// Find NULL checks
		nullCheckVars := make(map[string]uint)
		nullMatches := nullCheckPattern.FindAllStringSubmatch(funcBody, -1)
		for _, nm := range nullMatches {
			varName := nm[1]
			if varName != "" {
				for i, nl := range funcLines {
					if strings.Contains(nl, "!"+varName) || strings.Contains(nl, varName+" ==") || strings.Contains(nl, varName+" !=") {
						nullCheckVars[varName] = uint(int(fn.StartLine) + i)
						break
					}
				}
			}
		}

		// For each dereferenced variable, check if there's a NULL guard
		for v, derefLine := range derefVars {
			checkLine, hasCheck := nullCheckVars[v]
			results = append(results, PointerValidation{
				File:           file,
				Line:           derefLine,
				Function:       fn.Name,
				Variable:       v,
				IsPointerParam: true,
				HasNullCheck:   hasCheck,
				IsDereferenced: true,
				NullCheckLine:  checkLine,
				DerefLine:      derefLine,
				Category:       "param_check",
			})
		}
	}
	return results
}

// ── S9: StructInit extraction (regex fallback) ──

var structDeclPattern = regexp.MustCompile(`(?m)(?:struct\s+(\w+)\s+(\w+)\s*;|(\w+)\s*=\s*(?:\(\s*\w+\s*\*\)\s*)?malloc\s*\(\s*sizeof\s*\(\s*(\w+)\s*\)\s*\))`)
var structFieldAssignPattern = regexp.MustCompile(`(?m)(\w+)\s*->\s*(\w+)\s*=`)

// extractStructInitsRegex identifies struct variable declarations and tracks
// field assignments to detect partial initialization.
func extractStructInitsRegex(source []byte, file string, types []TypeInfo) []StructInit {
	var results []StructInit
	content := string(source)
	lines := strings.Split(content, "\n")

	// Build set of known struct type names
	structTypes := make(map[string]bool)
	for _, t := range types {
		if t.Kind == "typedef" {
			structTypes[t.Name] = true
		}
	}

	for lineIdx, line := range lines {
		trimmed := strings.TrimSpace(line)

		// Stack allocation: StructType var; (no initializer)
		for st := range structTypes {
			// Simple pattern: struct_name var_name;
			if strings.Contains(trimmed, st+" ") && strings.HasSuffix(strings.TrimSpace(trimmed), ";") && !strings.Contains(trimmed, "=") && !strings.Contains(trimmed, "(") {
				parts := strings.Fields(trimmed)
				for pi, p := range parts {
					if p == st && pi+1 < len(parts) {
						varName := strings.TrimSuffix(parts[pi+1], ";")
						varName = strings.TrimRight(varName, "[]*")
						if varName != "" && varName != "*" && varName != "struct" {
							results = append(results, StructInit{
								File:         file,
								Line:         uint(lineIdx + 1),
								StructType:   st,
								Variable:     varName,
								IsStackAlloc: true,
								Category:     "no_init",
							})
						}
					}
				}
			}
			// Heap allocation: malloc(sizeof(StructType))
			if strings.Contains(trimmed, "malloc") && strings.Contains(trimmed, st) {
				results = append(results, StructInit{
					File:         file,
					Line:         uint(lineIdx + 1),
					StructType:   st,
					IsHeapAlloc:  true,
					Category:     "partial_init",
				})
			}
		}
	}
	return results
}

// ── S10: VariableWrite extraction (regex fallback) ──

var varDeclPattern = regexp.MustCompile(`(?m)^\s*(?:const\s+)?(\w+(?:\s*\*)?)\s+(\w+)\s*(?:=\s*(.+?))?\s*;`)
var varReadPattern = regexp.MustCompile(`(?m)(?:\bif\s*\(|\bwhile\s*\(|\bfor\s*\(|\bswitch\s*\(|\breturn\s+|=\s*|[+\-*/%&|^<>!]=?\s*|\bprintf\s*\(|\bfprintf\s*\(|[,(]\s*)(\w+)`)

// extractVariableWritesRegex identifies variable declarations and tracks
// whether they are written before being read.
func extractVariableWritesRegex(source []byte, file string, functions []FunctionInfo) []VariableWrite {
	var results []VariableWrite
	content := string(source)
	lines := strings.Split(content, "\n")

	for _, fn := range functions {
		if fn.StartLine == 0 || fn.EndLine == 0 {
			continue
		}
		startIdx := int(fn.StartLine) - 1
		endIdx := min(int(fn.EndLine), len(lines))

		// Track declared variables in this function
		declaredVars := make(map[string]uint)
		for i := startIdx; i < endIdx; i++ {
			line := lines[i]
			matches := varDeclPattern.FindStringSubmatch(line)
			if len(matches) >= 3 {
				typeName, varName := matches[1], matches[2]
				hasInit := len(matches) > 3 && matches[3] != ""
				if varName != "" && typeName != "if" && typeName != "while" && typeName != "for" && typeName != "return" && typeName != "goto" && typeName != "sizeof" {
					declaredVars[varName] = uint(i + 1)
					isStructField := strings.Contains(typeName, "->")
					fieldName := ""
					if isStructField {
						parts := strings.SplitN(varName, ".", 2)
						if len(parts) == 2 {
							fieldName = parts[1]
						}
					}
					results = append(results, VariableWrite{
						File:          file,
						Line:          uint(i + 1),
						Function:      fn.Name,
						Variable:      varName,
						TypeName:      typeName,
						DeclLine:      uint(i + 1),
						IsStructField: isStructField,
						FieldName:     fieldName,
						IsInitialized: hasInit,
						Category:      "declared_only",
					})
				}
			}
		}

		// Check for read-before-write: scan lines again, mark first read/write
		for ri := range results {
			r := &results[ri]
			varName := r.Variable
			for i := startIdx; i < endIdx; i++ {
				line := lines[i]
				lineNo := uint(i + 1)
				// Skip the declaration line itself
				if lineNo == r.DeclLine {
					// Check if there's an initializer at declaration
					if strings.Contains(line, "=") && !strings.Contains(line, "==") && !strings.Contains(line, "!=") && !strings.Contains(line, "<=") && !strings.Contains(line, ">=") {
						r.FirstWriteLine = lineNo
						r.IsInitialized = true
						r.Category = "written"
					}
					continue
				}
				// Check for write: var = ... or →var or var→
				if strings.Contains(line, varName+" =") || strings.Contains(line, varName+"=") || strings.Contains(line, "->"+varName) || strings.Contains(line, varName+"->") || strings.Contains(line, "*"+varName+" =") || strings.Contains(line, "&"+varName) || strings.Contains(line, "("+varName+")") {
					if r.FirstWriteLine == 0 {
						r.FirstWriteLine = lineNo
						r.Category = "written"
					}
				}
				// Check for read: var used in expression before write
				if r.FirstWriteLine == 0 && r.FirstReadLine == 0 {
					if strings.Contains(line, varName) && !strings.Contains(line, varName+" =") && !strings.Contains(line, varName+"=") && !strings.Contains(line, "char") && !strings.Contains(line, "int") && !strings.Contains(line, "void") {
						r.FirstReadLine = lineNo
						r.Category = "read_before_write"
					}
				}
			}
		}
	}
	return results
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

