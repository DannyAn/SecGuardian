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

// ParseResult holds all extracted information from a single file.
type ParseResult struct {
	File            string             `json:"file"`
	Language        string             `json:"language"`
	Functions       []FunctionInfo     `json:"functions"`
	Variables       []VariableInfo     `json:"variables"`
	Types           []TypeInfo         `json:"types"`
	CallSites       []CallSite         `json:"call_sites"`
	StringLiterals  []StringLiteral    `json:"string_literals,omitempty"`
	Declarations    []Declaration      `json:"declarations,omitempty"`
	ValueConstants  []ValueConstant    `json:"value_constants,omitempty"`
	Imports         []Import           `json:"imports,omitempty"`
	ConfigPatterns  []ConfigPattern    `json:"config_patterns,omitempty"`
	ControlFlow     []ControlFlowSignal `json:"control_flow,omitempty"`
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

