package parser

// ── CFG types & queries (build-tag-agnostic) ─────────────────
//
// The Control Flow Graph *types* and *graph queries* (reachability, dominance)
// are pure Go and have no tree-sitter dependency. They live here so that both
// the cgo (tree-sitter) and non-cgo (regex fallback) builds can reference
// FunctionCFG — e.g. from AnalysisContext. Only the *construction* (BuildCFG in
// cfg.go, cgo-only) requires the tree-sitter CST; the non-cgo path simply
// leaves CFGs empty.
//
// See EPIC-011 / FEATURE-002.

// EdgeType describes how control transfers between basic blocks.
type EdgeType string

const (
	EdgeTrue        EdgeType = "true"        // condition held
	EdgeFalse       EdgeType = "false"       // condition failed
	EdgeFallthrough EdgeType = "fallthrough" // sequential fall-through
	EdgeReturn      EdgeType = "return"      // function exit
	EdgeBreak       EdgeType = "break"       // loop/switch exit
	EdgeContinue    EdgeType = "continue"    // loop header
	EdgeThrow       EdgeType = "throw"       // exceptional exit
	EdgeBack        EdgeType = "back"        // loop back-edge to header
)

// Edge is a control-flow transfer between basic blocks.
type Edge struct {
	To   int      `json:"to"`
	Type EdgeType `json:"type"`
}

// BasicBlock is a maximal sequence of non-branching statements.
type BasicBlock struct {
	ID    int    `json:"id"`
	Stmts []uint `json:"stmts"` // source line numbers (1-based) of statements in this block
	Succ  []Edge `json:"succ"`  // successor edges
}

// FunctionCFG is the control-flow graph of a single function.
type FunctionCFG struct {
	Function   string       `json:"function"`
	File       string       `json:"file"`
	Entry      int          `json:"entry"`  // entry block ID (always 0)
	Exit       int          `json:"exit"`   // exit block ID (all terminators flow here)
	Blocks     []BasicBlock `json:"blocks"`
	Incomplete bool         `json:"incomplete,omitempty"` // an unhandled control structure was seen
}

// IsReachable reports whether `to` is reachable from `from` following succ edges.
func (g *FunctionCFG) IsReachable(from, to int) bool {
	if g == nil || from < 0 || from >= len(g.Blocks) || to < 0 || to >= len(g.Blocks) {
		return false
	}
	if from == to {
		return true
	}
	visited := make(map[int]bool)
	stack := []int{from}
	for len(stack) > 0 {
		n := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		if n == to {
			return true
		}
		if visited[n] {
			continue
		}
		visited[n] = true
		for _, e := range g.Blocks[n].Succ {
			if !visited[e.To] {
				stack = append(stack, e.To)
			}
		}
	}
	return false
}

// Dominates reports whether `dom` dominates `node` (every path from entry to
// `node` passes through `dom`). Computed via iterative dataflow (per-function
// scale is small; O(n^2) is acceptable).
func (g *FunctionCFG) Dominates(dom, node int) bool {
	if g == nil || dom < 0 || node < 0 || dom >= len(g.Blocks) || node >= len(g.Blocks) {
		return false
	}
	if dom == node {
		return true
	}
	preds := make([][]int, len(g.Blocks))
	for i, b := range g.Blocks {
		for _, e := range b.Succ {
			if e.To >= 0 && e.To < len(g.Blocks) {
				preds[e.To] = append(preds[e.To], i)
			}
		}
	}
	reach := g.reachableFromEntry()
	if !reach[node] || !reach[dom] {
		return false
	}
	doms := make([]map[int]bool, len(g.Blocks))
	for n := range g.Blocks {
		if reach[n] {
			if n == g.Entry {
				doms[n] = map[int]bool{n: true}
			} else {
				doms[n] = nil // sentinel = universal (all reachable)
			}
		}
	}
	changed := true
	for changed {
		changed = false
		for n := range g.Blocks {
			if !reach[n] || n == g.Entry {
				continue
			}
			var inter map[int]bool
			for _, p := range preds[n] {
				if !reach[p] {
					continue
				}
				if inter == nil {
					inter = copySet(doms[p])
				} else {
					inter = intersect(inter, doms[p])
				}
			}
			if inter == nil {
				inter = map[int]bool{}
			}
			inter[n] = true
			if !equalSet(inter, doms[n]) {
				doms[n] = inter
				changed = true
			}
		}
	}
	return doms[node] != nil && doms[node][dom]
}

func (g *FunctionCFG) reachableFromEntry() map[int]bool {
	reach := make(map[int]bool)
	if g == nil || len(g.Blocks) == 0 {
		return reach
	}
	stack := []int{g.Entry}
	for len(stack) > 0 {
		n := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		if reach[n] {
			continue
		}
		reach[n] = true
		for _, e := range g.Blocks[n].Succ {
			if e.To >= 0 && e.To < len(g.Blocks) && !reach[e.To] {
				stack = append(stack, e.To)
			}
		}
	}
	return reach
}

func copySet(s map[int]bool) map[int]bool {
	out := make(map[int]bool, len(s))
	for k := range s {
		out[k] = true
	}
	return out
}

func intersect(a, b map[int]bool) map[int]bool {
	out := make(map[int]bool)
	for k := range a {
		if b[k] {
			out[k] = true
		}
	}
	return out
}

func equalSet(a, b map[int]bool) bool {
	if len(a) != len(b) {
		return false
	}
	for k := range a {
		if !b[k] {
			return false
		}
	}
	return true
}
