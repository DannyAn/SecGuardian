//go:build cgo

package parser

import (
	"strings"

	treesitter "github.com/tree-sitter/go-tree-sitter"
)

// ── S12 TaintFlow (EPIC-011 M2) ──────────────────────────────
//
// Intra-procedural Source→Sink taint propagation. v1 (honest scope):
//   - return-tainted sources: x = source()  →  x tainted
//   - assignment propagation: x = y (y tainted)  →  x tainted
//   - sink detection: sink(..., tainted, ...)  →  TaintFlow emitted
//   - source-order walk (not path-sensitive); no aliasing; no inter-procedural
// Arg-tainted sources (fgets/scanf/read write-to-arg), inter-procedural, and
// path-sensitivity are follow-ups.

// Sources whose RETURN VALUE is tainted (assigned to a var → var tainted).
var taintReturnSources = map[string]bool{
	"getenv": true, "gets": true, "getchar": true, "tmpnam": true,
	"getlogin": true, "getwd": true, "readline": true, "vasprintf": true,
	"fgets": true, // returns its buf arg (tainted)
}

// Sources that TAINT AN ARGUMENT (write external data into a buffer arg).
// callee → index of the buffer arg that becomes tainted.
var taintArgSources = map[string]int{
	"fgets": 0, "gets": 0, "recv": 1, "read": 1, "fread": 0,
	"scanf": 1, "fscanf": 1, "getcwd": 0,
}

// Parameter-name substrings that indicate external (tainted) input.
var taintParamHints = []string{"input", "user", "request", "data", "cmd", "argv", "query", "msg"}

// Sinks: callee → vuln category.
var taintSinks = map[string]string{
	// buffer overflow
	"strcpy": "overflow", "strcat": "overflow", "sprintf": "overflow",
	"vsprintf": "overflow", "memcpy": "overflow", "memmove": "overflow",
	"sscanf": "overflow",
	// command injection
	"system": "injection", "popen": "injection",
	"execl": "injection", "execle": "injection", "execlp": "injection",
	"execv": "injection", "execvp": "injection", "execvpe": "injection",
	// format string
	"printf": "format_string", "fprintf": "format_string", "syslog": "format_string",
}

// collectTaintFlows walks each function's statements in source order, tracking
// tainted variables, and emits a TaintFlow when a tainted var reaches a sink.
func collectTaintFlows(root *treesitter.Node, content []byte, file, lang string) []TaintFlow {
	if root == nil || (lang != "c" && lang != "cpp") {
		return nil
	}
	var out []TaintFlow
	var walk func(n *treesitter.Node, curFunc string)
	walk = func(n *treesitter.Node, curFunc string) {
		if n == nil {
			return
		}
		if n.Kind() == "function_definition" {
			name := functionNameForNode(n, content)
			out = append(out, analyzeFunctionTaint(n, content, file, name)...)
			// still recurse for nested functions (C++ lambdas etc.) — but the
			// function itself is handled above; skip re-walking its body here.
			return
		}
		for i := uint(0); i < n.NamedChildCount(); i++ {
			walk(n.NamedChild(i), curFunc)
		}
	}
	walk(root, "")
	return out
}

// taintedVar tracks a variable tainted by a source.
type taintedVar struct {
	source     string
	sourceLine uint
}

func analyzeFunctionTaint(fn *treesitter.Node, content []byte, file, fnName string) []TaintFlow {
	body := findBody(fn)
	if body == nil {
		return nil
	}
	tainted := map[string]taintedVar{} // var name → source info
	var flows []TaintFlow

	// Seed taint from external-input parameters (argv, *input, *user_request, ...).
	for _, pname := range extractParams(fn, content) {
		if isExternalInputParam(pname) {
			tainted[pname] = taintedVar{source: "param:" + pname, sourceLine: fn.StartPosition().Row + 1}
		}
	}

	// Iterate body statements in source order.
	for i := uint(0); i < body.NamedChildCount(); i++ {
		stmt := body.NamedChild(i)
		if stmt == nil {
			continue
		}
		applyStatement(stmt, content, file, fnName, tainted, &flows)
	}
	return flows
}

// extractParams returns parameter identifier names from a function_definition.
func extractParams(fn *treesitter.Node, content []byte) []string {
	var params []string
	for i := uint(0); i < fn.NamedChildCount(); i++ {
		c := fn.NamedChild(i)
		if c == nil || c.Kind() != "function_declarator" {
			continue
		}
		for j := uint(0); j < c.NamedChildCount(); j++ {
			p := c.NamedChild(j)
			if p == nil || p.Kind() != "parameter_list" {
				continue
			}
			for k := uint(0); k < p.NamedChildCount(); k++ {
				pd := p.NamedChild(k)
				if pd == nil {
					continue
				}
				// parameter_declaration → identifier (or pointer_declarator>identifier)
				for m := uint(0); m < pd.NamedChildCount(); m++ {
					ch := pd.NamedChild(m)
					if ch == nil {
						continue
					}
					switch ch.Kind() {
					case "identifier", "field_identifier":
						params = append(params, safeText(content, ch.StartByte(), ch.EndByte()))
					case "pointer_declarator", "array_declarator":
						if inner := firstNamedChild(ch); inner != nil &&
							(inner.Kind() == "identifier" || inner.Kind() == "field_identifier") {
							params = append(params, safeText(content, inner.StartByte(), inner.EndByte()))
						}
					}
				}
			}
		}
		break
	}
	return params
}

func isExternalInputParam(name string) bool {
	if name == "argv" {
		return true
	}
	low := strings.ToLower(name)
	for _, hint := range taintParamHints {
		if strings.Contains(low, hint) {
			return true
		}
	}
	return false
}

// applyStatement updates taint state and emits flows for one statement.
// It handles: declaration-with-init, assignment_expression, call_expression.
func applyStatement(stmt *treesitter.Node, content []byte, file, fnName string,
	tainted map[string]taintedVar, flows *[]TaintFlow) {
	k := stmt.Kind()
	switch k {
	case "declaration":
		// `T x = <init>;`  (possibly multiple declarators)
		for i := uint(0); i < stmt.NamedChildCount(); i++ {
			c := stmt.NamedChild(i)
			if c == nil || c.Kind() != "init_declarator" {
				continue
			}
			var lhs, rhsNode = parseInitDeclarator(c, content)
			propagateTaint(lhs, rhsNode, content, stmt, tainted)
		}
	case "expression_statement":
		inner := firstNamedChild(stmt)
		if inner == nil {
			return
		}
		switch inner.Kind() {
		case "assignment_expression":
			lhs, rhsNode := parseAssignment(inner, content)
			propagateTaint(lhs, rhsNode, content, stmt, tainted)
		case "call_expression":
			handleCall(inner, content, file, fnName, tainted, flows)
		}
	case "compound_statement":
		// nested block — recurse to keep taint state (conservative: taint
		// persists across blocks; not scope-accurate but safe for recall).
		for i := uint(0); i < stmt.NamedChildCount(); i++ {
			applyStatement(stmt.NamedChild(i), content, file, fnName, tainted, flows)
		}
	}
}

// propagateTaint: if rhs is a source call → taint lhs; if rhs is a tainted
// identifier → taint lhs.
func propagateTaint(lhs string, rhs *treesitter.Node, content []byte, stmt *treesitter.Node,
	tainted map[string]taintedVar) {
	if lhs == "" || rhs == nil {
		return
	}
	if callee := callCallee(rhs, content); callee != "" {
		if taintReturnSources[callee] {
			tainted[lhs] = taintedVar{source: callee, sourceLine: stmt.StartPosition().Row + 1}
			return
		}
		// non-source call assigned: conservatively drop lhs taint (could be a
		// sanitizer/transform). Recall may miss inter-procedural flows.
		delete(tainted, lhs)
		return
	}
	if rhs.Kind() == "identifier" {
		name := safeText(content, rhs.StartByte(), rhs.EndByte())
		if src, ok := tainted[name]; ok {
			tainted[lhs] = taintedVar{source: src.source, sourceLine: src.sourceLine}
			return
		}
		delete(tainted, lhs)
		return
	}
	// other rhs (literal, binary expr, ...): not tainted
	delete(tainted, lhs)
}

func handleCall(call *treesitter.Node, content []byte, file, fnName string,
	tainted map[string]taintedVar, flows *[]TaintFlow) {
	callee := callCallee(call, content)
	if callee == "" {
		return
	}
	args := callArgs(call, content)
	callLine := call.StartPosition().Row + 1

	// arg-tainted source: fgets(buf,...)/recv(s,buf,...)/read(fd,buf,...) → taint buf
	if argIdx, ok := taintArgSources[callee]; ok {
		if argIdx < len(args) {
			buf := args[argIdx]
			if buf != "" {
				tainted[buf] = taintedVar{source: callee, sourceLine: callLine}
			}
		}
	}

	// sink: if a tainted var reaches this sink → emit flow
	cat, isSink := taintSinks[callee]
	if !isSink {
		return
	}
	for _, arg := range args {
		if tv, ok := tainted[arg]; ok {
			*flows = append(*flows, TaintFlow{
				File:       file,
				Function:   fnName,
				Source:     tv.source,
				SourceLine: tv.sourceLine,
				Sink:       callee,
				SinkLine:   callLine,
				TaintedVar: arg,
				Path: []string{
					sourceLabel(tv) + " → " + arg + " tainted",
					arg + " → " + callee + "() @ L" + uintStr(callLine),
				},
				Category: cat,
			})
		}
	}
}

func sourceLabel(tv taintedVar) string {
	if strings.HasPrefix(tv.source, "param:") {
		return tv.source + " @ L" + uintStr(tv.sourceLine)
	}
	return tv.source + "() @ L" + uintStr(tv.sourceLine)
}

// ── AST helpers ──────────────────────────────────────────────

func firstNamedChild(n *treesitter.Node) *treesitter.Node {
	if n == nil || n.NamedChildCount() == 0 {
		return nil
	}
	return n.NamedChild(0)
}

// parseInitDeclarator: `x = <init>` or `*x = <init>` → (lhsName, initNode).
func parseInitDeclarator(n *treesitter.Node, content []byte) (string, *treesitter.Node) {
	var lhs string
	var init *treesitter.Node
	for i := uint(0); i < n.NamedChildCount(); i++ {
		c := n.NamedChild(i)
		if c == nil {
			continue
		}
		switch c.Kind() {
		case "pointer_declarator", "array_declarator":
			if inner := firstNamedChild(c); inner != nil &&
				(inner.Kind() == "identifier" || inner.Kind() == "field_identifier") {
				lhs = safeText(content, inner.StartByte(), inner.EndByte())
			}
		case "identifier", "field_identifier":
			// first identifier is the declared name; a second one is the init (x = y)
			if lhs == "" {
				lhs = safeText(content, c.StartByte(), c.EndByte())
			} else if init == nil {
				init = c
			}
		case "call_expression", "binary_expression", "number_literal", "string_literal":
			init = c
		}
	}
	return lhs, init
}

// parseAssignment: `x = rhs` → (lhsName, rhsNode).
func parseAssignment(n *treesitter.Node, content []byte) (string, *treesitter.Node) {
	var lhs string
	var rhs *treesitter.Node
	for i := uint(0); i < n.NamedChildCount(); i++ {
		c := n.NamedChild(i)
		if c == nil {
			continue
		}
		switch c.Kind() {
		case "pointer_declarator", "subscript_expression":
			if inner := firstNamedChild(c); inner != nil &&
				(inner.Kind() == "identifier" || inner.Kind() == "field_identifier") {
				lhs = safeText(content, inner.StartByte(), inner.EndByte())
			}
		case "identifier", "field_identifier":
			// first identifier is lhs; a second is the rhs (x = y)
			if lhs == "" {
				lhs = safeText(content, c.StartByte(), c.EndByte())
			} else if rhs == nil {
				rhs = c
			}
		case "call_expression", "binary_expression", "number_literal", "string_literal":
			rhs = c
		}
	}
	return lhs, rhs
}

// callCallee returns the callee identifier name of a call_expression, or "".
func callCallee(call *treesitter.Node, content []byte) string {
	if call == nil || call.Kind() != "call_expression" {
		return ""
	}
	c := firstNamedChild(call)
	if c == nil {
		return ""
	}
	if c.Kind() == "identifier" || c.Kind() == "field_identifier" {
		return safeText(content, c.StartByte(), c.EndByte())
	}
	// qualified call (e.g., obj.method) — take last segment text conservatively
	txt := safeText(content, c.StartByte(), c.EndByte())
	if dot := strings.LastIndex(txt, "."); dot >= 0 {
		return txt[dot+1:]
	}
	return txt
}

// callArgs returns the identifier names of a call_expression's arguments
// (only simple identifier args are tracked for taint; expressions are skipped).
func callArgs(call *treesitter.Node, content []byte) []string {
	var args []string
	for i := uint(0); i < call.NamedChildCount(); i++ {
		c := call.NamedChild(i)
		if c == nil || c.Kind() != "argument_list" {
			continue
		}
		for j := uint(0); j < c.NamedChildCount(); j++ {
			a := c.NamedChild(j)
			if a != nil && a.Kind() == "identifier" {
				args = append(args, safeText(content, a.StartByte(), a.EndByte()))
			}
		}
	}
	return args
}

func uintStr(n uint) string {
	// avoid strconv import in this file; small helper
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
