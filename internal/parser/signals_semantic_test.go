//go:build cgo

package parser

import "testing"

func TestS11_AssignmentInCondition(t *testing.T) {
	src := `int f(){ int x;
  if (x = 5) return 1;     // bug: assignment as condition
  if ((x = g()) != 0) return 2;  // intentional, wrapped — must NOT flag
  while (x = h()) {}        // bug
  return 0;
}`
	root, content := parseC(t, src)
	fn := findFirstDescendant(root, "function_definition")
	cfg := BuildCFG(fn, content, "f", "test.c") // ensure CFG still builds
	_ = cfg
	// collectSuspiciousExpressions walks the whole file; use root.
	decls := collectDeclarations(root, content, "test.c", "c")
	sigs := collectSuspiciousExpressions(root, content, "test.c", "c", decls)
	count := 0
	for _, s := range sigs {
		if s.Kind == "assignment_in_condition" {
			count++
		}
	}
	// Expect 2: `if (x=5)` and `while (x=h())`. The wrapped `(x=g())!=0` must NOT flag.
	if count != 2 {
		t.Errorf("assignment_in_condition: expected 2, got %d: %+v", count, filterKind(sigs, "assignment_in_condition"))
	}
}

func TestS11_OperatorPrecedence(t *testing.T) {
	src := `int f(){ int a,b,c;
  int x = a & b == c;   // suspicious: & outer, == inner
  int y = a + b * c;    // normal arithmetic — must NOT flag
  int z = a << b + c;   // suspicious: << outer, + inner
  return 0;
}`
	root, content := parseC(t, src)
	decls := collectDeclarations(root, content, "test.c", "c")
	sigs := collectSuspiciousExpressions(root, content, "test.c", "c", decls)
	count := 0
	for _, s := range sigs {
		if s.Kind == "operator_precedence" {
			count++
		}
	}
	if count != 2 {
		t.Errorf("operator_precedence: expected 2, got %d: %+v", count, filterKind(sigs, "operator_precedence"))
	}
}

func TestS11_SignedUnsignedCompare(t *testing.T) {
	src := `int f(){ int s; unsigned u;
  if (s < u) return 1;   // signed vs unsigned — flag
  if (s < 0) return 2;   // signed vs literal — must NOT flag (literal unknown)
  return 0;
}`
	root, content := parseC(t, src)
	decls := collectDeclarations(root, content, "test.c", "c")
	sigs := collectSuspiciousExpressions(root, content, "test.c", "c", decls)
	count := 0
	for _, s := range sigs {
		if s.Kind == "signed_unsigned_compare" {
			count++
		}
	}
	if count != 1 {
		t.Errorf("signed_unsigned_compare: expected 1, got %d: %+v", count, filterKind(sigs, "signed_unsigned_compare"))
	}
}

func TestS11_SuspiciousBoolean(t *testing.T) {
	src := `int f(){ int a,b,c;
  if (!a = b) return 1;   // negation of assignment — flag
  if (a && b = c) return 2; // assignment in boolean — flag
  if (a && b) return 3;     // normal — must NOT flag
  return 0;
}`
	root, content := parseC(t, src)
	decls := collectDeclarations(root, content, "test.c", "c")
	sigs := collectSuspiciousExpressions(root, content, "test.c", "c", decls)
	count := 0
	for _, s := range sigs {
		if s.Kind == "suspicious_boolean" {
			count++
		}
	}
	if count != 2 {
		t.Errorf("suspicious_boolean: expected 2, got %d: %+v", count, filterKind(sigs, "suspicious_boolean"))
	}
}

func filterKind(sigs []SuspiciousExpression, kind string) []SuspiciousExpression {
	var out []SuspiciousExpression
	for _, s := range sigs {
		if s.Kind == kind {
			out = append(out, s)
		}
	}
	return out
}
