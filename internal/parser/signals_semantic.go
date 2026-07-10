//go:build cgo

package parser

import (
	"strings"

	treesitter "github.com/tree-sitter/go-tree-sitter"
)

// ── S11 SuspiciousExpression (EPIC-011) ──────────────────────
//
// Engine-detected deterministic AST patterns that are classic semantic bug
// sources. The engine emits these so the LLM cannot miss them (engine recall
// floor); rules + LLM then judge intent. Covers the 4 missing semantic classes
// (assignment_in_condition / operator_precedence / signed_unsigned_compare /
// suspicious_boolean) identified in the 2026-07-10 root-tech review.

// collectSuspiciousExpressions walks the CST for C/C++, tracking the enclosing
// function, and emits one signal per suspicious pattern.
func collectSuspiciousExpressions(root *treesitter.Node, content []byte, file, lang string, decls []Declaration) []SuspiciousExpression {
	if root == nil || (lang != "c" && lang != "cpp") {
		return nil
	}
	typeLookup := buildDeclTypeLookup(decls)
	var out []SuspiciousExpression
	var walk func(n *treesitter.Node, curFunc string)
	walk = func(n *treesitter.Node, curFunc string) {
		if n == nil {
			return
		}
		k := n.Kind()
		if k == "function_definition" {
			name := functionNameForNode(n, content)
			for i := uint(0); i < n.NamedChildCount(); i++ {
				walk(n.NamedChild(i), name)
			}
			return
		}
		// assignment_in_condition: if/while condition's top-level expr is an assignment.
		if k == "if_statement" || k == "while_statement" {
			if cond := conditionInnerExpr(n); cond != nil && cond.Kind() == "assignment_expression" {
				out = append(out, mkSusp(n, content, file, curFunc, "assignment_in_condition",
					"assignment used as condition top-level (likely meant ==): "+exprText(cond, content)))
			}
		}
		if k == "binary_expression" {
			out = append(out, checkPrecedence(n, content, file, curFunc)...)
			out = append(out, checkSignedUnsigned(n, content, file, curFunc, typeLookup)...)
			out = append(out, checkBooleanAssignment(n, content, file, curFunc)...)
		}
		if k == "unary_expression" {
			out = append(out, checkNegatedAssignment(n, content, file, curFunc)...)
		}
		for i := uint(0); i < n.NamedChildCount(); i++ {
			walk(n.NamedChild(i), curFunc)
		}
	}
	walk(root, "")
	return out
}

// conditionInnerExpr returns the inner expression of an if/while condition's
// parenthesized_expression (the thing actually being tested).
func conditionInnerExpr(stmt *treesitter.Node) *treesitter.Node {
	for i := uint(0); i < stmt.NamedChildCount(); i++ {
		c := stmt.NamedChild(i)
		if c != nil && c.Kind() == "parenthesized_expression" && c.NamedChildCount() > 0 {
			return c.NamedChild(0)
		}
	}
	return nil
}

func exprText(n *treesitter.Node, content []byte) string {
	if n == nil {
		return ""
	}
	return strings.TrimSpace(safeText(content, n.StartByte(), n.EndByte()))
}

func mkSusp(n *treesitter.Node, content []byte, file, curFunc, kind, detail string) SuspiciousExpression {
	return SuspiciousExpression{
		File: file, Line: n.StartPosition().Row + 1, Function: curFunc,
		Kind: kind, Detail: detail, Snippet: exprText(n, content),
	}
}

// C operator precedence rank (higher binds tighter).
func precRank(op string) int {
	switch op {
	case "*", "/", "%":
		return 5
	case "+", "-":
		return 4
	case "<<", ">>":
		return 3
	case "<", "<=", ">", ">=":
		return 2
	case "==", "!=":
		return 1
	case "&":
		return 0
	case "^":
		return -1
	case "|":
		return -2
	case "&&":
		return -3
	case "||":
		return -4
	}
	return 99 // unknown / non-binary
}

// binaryOps returns (left, op, right) for a binary_expression node.
func binaryParts(n *treesitter.Node, content []byte) (*treesitter.Node, string, *treesitter.Node) {
	if n == nil || n.Kind() != "binary_expression" || n.NamedChildCount() < 2 {
		return nil, "", nil
	}
	left := n.NamedChild(0)
	right := n.NamedChild(1)
	if left == nil || right == nil {
		return nil, "", nil
	}
	op := strings.TrimSpace(string(content[left.EndByte():right.StartByte()]))
	return left, op, right
}

// checkPrecedence flags lower-precedence outer operators wrapping higher-
// precedence inner operators WITHOUT parens, for the classic FP-prone pairs:
//   bitwise (&,^,|) outer with comparison (==,!=,<,>,<=,>=) inner
//   shift (<<,>>) outer with arithmetic (+,-) inner
// Normal arithmetic like `a + b * c` is NOT flagged (not surprising).
func checkPrecedence(n *treesitter.Node, content []byte, file, curFunc string) []SuspiciousExpression {
	_, op, right := binaryParts(n, content)
	left := n.NamedChild(0)
	if op == "" {
		return nil
	}
	var out []SuspiciousExpression
	for _, child := range []*treesitter.Node{left, right} {
		if child == nil || child.Kind() != "binary_expression" {
			continue // not parenthesized, not a nested binary → skip
		}
		_, innerOp, _ := binaryParts(child, content)
		if innerOp == "" {
			continue
		}
		if isPrecedenceSuspicious(op, innerOp) {
			out = append(out, mkSusp(n, content, file, curFunc, "operator_precedence",
				"'"+op+"' (outer) binds looser than '"+innerOp+"' (inner); likely needs parens: "+exprText(n, content)))
		}
	}
	return out
}

func isPrecedenceSuspicious(outer, inner string) bool {
	bitwise := map[string]bool{"&": true, "^": true, "|": true}
	shift := map[string]bool{"<<": true, ">>": true}
	arith := map[string]bool{"+": true, "-": true}
	comparison := map[string]bool{"==": true, "!=": true, "<": true, ">": true, "<=": true, ">=": true}
	if bitwise[outer] && comparison[inner] {
		return true
	}
	if shift[outer] && arith[inner] {
		return true
	}
	return false
}

// checkSignedUnsigned flags comparison of a signed operand with an unsigned
// operand (common case: both are simple identifiers whose types are known from
// S3 Declarations). Complex-expression type inference is a future root-tech gap.
func checkSignedUnsigned(n *treesitter.Node, content []byte, file, curFunc string, lookup declTypeLookup) []SuspiciousExpression {
	left, op, right := binaryParts(n, content)
	if left == nil {
		return nil
	}
	if !isComparisonOp(op) {
		return nil
	}
	ls := signedness(left, content, curFunc, lookup)
	rs := signedness(right, content, curFunc, lookup)
	if ls == "signed" && rs == "unsigned" {
		return []SuspiciousExpression{mkSusp(n, content, file, curFunc, "signed_unsigned_compare",
			"signed "+operandName(left, content)+" compared with unsigned "+operandName(right, content)+": negative signed promoted to huge unsigned")}
	}
	if ls == "unsigned" && rs == "signed" {
		return []SuspiciousExpression{mkSusp(n, content, file, curFunc, "signed_unsigned_compare",
			"unsigned "+operandName(right, content)+" compared with signed "+operandName(left, content)+": negative signed promoted to huge unsigned")}
	}
	return nil
}

func isComparisonOp(op string) bool {
	switch op {
	case "<", "<=", ">", ">=", "==", "!=":
		return true
	}
	return false
}

func operandName(n *treesitter.Node, content []byte) string {
	if n == nil {
		return ""
	}
	if n.Kind() == "identifier" {
		return safeText(content, n.StartByte(), n.EndByte())
	}
	return exprText(n, content)
}

// signedness returns "signed" | "unsigned" | "" (unknown) for an operand.
func signedness(n *treesitter.Node, content []byte, curFunc string, lookup declTypeLookup) string {
	if n == nil || n.Kind() != "identifier" {
		return "" // only simple identifiers (common case); expressions need type inference
	}
	name := safeText(content, n.StartByte(), n.EndByte())
	typ := lookup(name, curFunc)
	return classifySignedness(typ)
}

func classifySignedness(typeName string) string {
	if typeName == "" {
		return ""
	}
	t := strings.ToLower(typeName)
	if strings.Contains(t, "unsigned") || strings.Contains(t, "size_t") || strings.Contains(t, "uint") {
		return "unsigned"
	}
	if strings.Contains(t, "int") || strings.Contains(t, "char") || strings.Contains(t, "short") || strings.Contains(t, "long") {
		return "signed"
	}
	return ""
}

// checkBooleanAssignment flags `a && b = c` / `a || b = c` (assignment as an
// operand of a boolean operator).
func checkBooleanAssignment(n *treesitter.Node, content []byte, file, curFunc string) []SuspiciousExpression {
	left, op, right := binaryParts(n, content)
	if left == nil {
		return nil
	}
	if op != "&&" && op != "||" {
		return nil
	}
	var out []SuspiciousExpression
	for _, child := range []*treesitter.Node{left, right} {
		if child != nil && child.Kind() == "assignment_expression" {
			out = append(out, mkSusp(n, content, file, curFunc, "suspicious_boolean",
				"assignment used as operand of '"+op+"' (likely missing ==): "+exprText(n, content)))
			break
		}
	}
	return out
}

// checkNegatedAssignment flags `!x = s` / `~x = s` (negation wrapping an
// assignment, or assignment whose target is a unary expression).
func checkNegatedAssignment(n *treesitter.Node, content []byte, file, curFunc string) []SuspiciousExpression {
	if n == nil || n.NamedChildCount() == 0 {
		return nil
	}
	// operator text is before the operand
	op := strings.TrimSpace(string(content[n.StartByte():n.NamedChild(0).StartByte()]))
	if op != "!" && op != "~" {
		return nil
	}
	operand := n.NamedChild(0)
	if operand != nil && operand.Kind() == "assignment_expression" {
		return []SuspiciousExpression{mkSusp(n, content, file, curFunc, "suspicious_boolean",
			"'"+op+"' applied to assignment (likely precedence bug): "+exprText(n, content))}
	}
	return nil
}

// ── declaration type lookup ──────────────────────────────────

type declTypeLookup func(name, curFunc string) string

func buildDeclTypeLookup(decls []Declaration) declTypeLookup {
	// Prefer function-local decls; fall back to file-global (Function == "").
	return func(name, curFunc string) string {
		var globalType string
		for _, d := range decls {
			if d.Name != name {
				continue
			}
			if d.Function == curFunc && d.TypeName != "" {
				return d.TypeName
			}
			if d.Function == "" && globalType == "" {
				globalType = d.TypeName
			}
		}
		return globalType
	}
}
