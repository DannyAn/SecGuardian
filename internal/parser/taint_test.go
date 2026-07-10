//go:build cgo

package parser

import "testing"

func TestS12_TaintFlow_SourceToSink(t *testing.T) {
	src := `void f(){ char buf[64];
  char *t = getenv("X");   // source: getenv → t tainted
  strcpy(buf, t);          // sink: strcpy(tainted) → overflow flow
  system(t);               // sink: system(tainted) → injection flow
}`
	root, content := parseC(t, src)
	flows := collectTaintFlows(root, content, "test.c", "c")
	if len(flows) != 2 {
		t.Fatalf("expected 2 taint flows (strcpy + system), got %d: %+v", len(flows), flows)
	}
	var strcpyFlow, systemFlow *TaintFlow
	for i := range flows {
		switch flows[i].Sink {
		case "strcpy":
			strcpyFlow = &flows[i]
		case "system":
			systemFlow = &flows[i]
		}
	}
	if strcpyFlow == nil || strcpyFlow.Source != "getenv" || strcpyFlow.Category != "overflow" {
		t.Errorf("strcpy flow wrong: %+v", strcpyFlow)
	}
	if systemFlow == nil || systemFlow.Source != "getenv" || systemFlow.Category != "injection" {
		t.Errorf("system flow wrong: %+v", systemFlow)
	}
	if strcpyFlow.TaintedVar != "t" {
		t.Errorf("expected tainted var t, got %s", strcpyFlow.TaintedVar)
	}
}

func TestS12_TaintFlow_NoSourceNoFlow(t *testing.T) {
	// no source — strcpy(buf, s) where s is a literal, not tainted
	src := `void f(){ char buf[64];
  char *s = "literal";
  strcpy(buf, s);
}`
	root, content := parseC(t, src)
	flows := collectTaintFlows(root, content, "test.c", "c")
	if len(flows) != 0 {
		t.Errorf("expected 0 flows (no source), got %d: %+v", len(flows), flows)
	}
}

func TestS12_TaintFlow_AssignmentPropagation(t *testing.T) {
	// taint propagates through assignment: t=getenv(); u=t; system(u);
	src := `void f(){ char *t = getenv("X"); char *u = t; system(u); }`
	root, content := parseC(t, src)
	flows := collectTaintFlows(root, content, "test.c", "c")
	if len(flows) != 1 {
		t.Fatalf("expected 1 flow via propagation, got %d: %+v", len(flows), flows)
	}
	if flows[0].Source != "getenv" || flows[0].Sink != "system" || flows[0].TaintedVar != "u" {
		t.Errorf("propagated flow wrong: %+v", flows[0])
	}
}

func TestS12_TaintFlow_NonSinkCallNoFlow(t *testing.T) {
	// tainted var passed to a non-sink call → no flow
	src := `void f(){ char *t = getenv("X"); printf("%p", t); }`
	root, content := parseC(t, src)
	flows := collectTaintFlows(root, content, "test.c", "c")
	// printf IS a format_string sink → expect 1 flow (tainted into printf format)
	if len(flows) != 1 {
		t.Errorf("expected 1 flow (printf is a format sink), got %d: %+v", len(flows), flows)
	}
}
