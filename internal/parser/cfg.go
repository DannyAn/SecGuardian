//go:build cgo

package parser

import (
	treesitter "github.com/tree-sitter/go-tree-sitter"
)

// ── CFG construction (cgo-only) ──────────────────────────────
//
// BuildCFG constructs a per-function CFG from a tree-sitter CST node. The graph
// types and reachability/dominance queries live in cfg_types.go (build-tag-
// agnostic); only construction needs the CST, so it is cgo-only alongside
// parser_ts.go. The non-cgo (regex) path leaves CFGs empty.
//
// See EPIC-011 / FEATURE-002.

type cfgBuilder struct {
	g        *FunctionCFG
	current  int // current block index
	exit     int // exit block index
	loopExit []int
	loopHead []int
}

// BuildCFG constructs a per-function CFG from a function_definition /
// function_declaration / method_declaration CST node.
func BuildCFG(funcNode *treesitter.Node, content []byte, funcName, file string) *FunctionCFG {
	if funcNode == nil {
		return nil
	}
	g := &FunctionCFG{Function: funcName, File: file, Entry: 0, Exit: 1}
	b := &cfgBuilder{g: g}
	b.current = b.newBB() // entry block (ID 0)
	b.exit = b.newBB()    // exit block (ID 1, reserved)

	body := findBody(funcNode)
	if body == nil {
		// No body (e.g. declaration/prototype): entry falls through to exit.
		b.addEdge(b.current, b.exit, EdgeFallthrough)
		return g
	}
	b.visitBlock(body)

	// Connect any unterminated reachable block to exit via fallthrough, so the
	// exit block is a proper unique sink for dominance/reachability.
	reach := g.reachableFromEntry()
	for i := range g.Blocks {
		if i == b.exit {
			continue
		}
		if len(g.Blocks[i].Succ) == 0 && reach[i] {
			g.Blocks[i].Succ = append(g.Blocks[i].Succ, Edge{To: b.exit, Type: EdgeFallthrough})
		}
	}
	return g
}

func (b *cfgBuilder) newBB() int {
	id := len(b.g.Blocks)
	b.g.Blocks = append(b.g.Blocks, BasicBlock{ID: id})
	return id
}

// visitBlock iterates the named children of a compound/block node as statements.
func (b *cfgBuilder) visitBlock(block *treesitter.Node) {
	if block == nil {
		return
	}
	for i := uint(0); i < block.NamedChildCount(); i++ {
		child := block.NamedChild(i)
		if child == nil {
			continue
		}
		b.visitStmt(child)
	}
}

func isBlockKind(kind string) bool {
	switch kind {
	case "compound_statement", "block", "statement_block", "block_node":
		return true
	}
	return false
}

func (b *cfgBuilder) visitStmt(node *treesitter.Node) {
	if node == nil {
		return
	}
	kind := node.Kind()

	switch {
	case kind == "if_statement" || kind == "if_expression":
		b.visitIf(node)
	case kind == "for_statement" || kind == "for_in_statement" || kind == "foreach_statement":
		b.visitLoop(node, kind)
	case kind == "while_statement":
		b.visitWhile(node)
	case kind == "do_statement" || kind == "do_while_statement":
		b.g.Incomplete = true
		b.visitDo(node)
	case kind == "switch_statement" || kind == "match_expression":
		b.g.Incomplete = true
		b.visitSwitch(node)
	case kind == "try_statement":
		b.g.Incomplete = true
		b.visitTry(node)
	case kind == "return_statement":
		b.appendLine(node)
		b.addEdge(b.current, b.exit, EdgeReturn)
		b.current = b.newUnreachable()
	case kind == "break_statement":
		if len(b.loopExit) > 0 {
			b.addEdge(b.current, b.loopExit[len(b.loopExit)-1], EdgeBreak)
		} else {
			b.g.Incomplete = true
		}
		b.current = b.newUnreachable()
	case kind == "continue_statement":
		if len(b.loopHead) > 0 {
			b.addEdge(b.current, b.loopHead[len(b.loopHead)-1], EdgeContinue)
		} else {
			b.g.Incomplete = true
		}
		b.current = b.newUnreachable()
	case kind == "throw_statement" || kind == "raise_statement":
		b.appendLine(node)
		b.addEdge(b.current, b.exit, EdgeThrow)
		b.current = b.newUnreachable()
	case isBlockKind(kind):
		b.visitBlock(node)
	default:
		// Plain statement: record its line in the current block.
		b.appendLine(node)
	}
}

func (b *cfgBuilder) newUnreachable() int {
	return b.newBB()
}

func (b *cfgBuilder) appendLine(node *treesitter.Node) {
	line := uint(node.StartPosition().Row + 1)
	blk := &b.g.Blocks[b.current]
	blk.Stmts = append(blk.Stmts, line)
}

func (b *cfgBuilder) addEdge(from, to int, t EdgeType) {
	if from < 0 || from >= len(b.g.Blocks) {
		return
	}
	if to < 0 || to >= len(b.g.Blocks) {
		return
	}
	b.g.Blocks[from].Succ = append(b.g.Blocks[from].Succ, Edge{To: to, Type: t})
}

// visitIf handles if/[else if]/else. tree-sitter C: named children =
// [parenthesized_expression, consequence, else_clause?]. Go: [expression, block, (if_statement|block)?].
func (b *cfgBuilder) visitIf(ifNode *treesitter.Node) {
	condBlk := b.current
	thenBlk := b.newBB()
	elseBlk := b.newBB()
	mergeBlk := b.newBB()

	b.addEdge(condBlk, thenBlk, EdgeTrue)
	b.addEdge(condBlk, elseBlk, EdgeFalse)

	var consequence, alternative *treesitter.Node
	for i := uint(0); i < ifNode.NamedChildCount(); i++ {
		c := ifNode.NamedChild(i)
		if c == nil {
			continue
		}
		k := c.Kind()
		if k == "else_clause" {
			alternative = firstStmtChild(c)
		} else if isBlockKind(k) || isStmtKind(k) {
			if consequence == nil {
				consequence = c
			} else if alternative == nil {
				alternative = c
			}
		}
	}

	b.current = thenBlk
	b.visitBranch(consequence)
	b.addEdge(b.current, mergeBlk, EdgeFallthrough)

	b.current = elseBlk
	b.visitBranch(alternative)
	b.addEdge(b.current, mergeBlk, EdgeFallthrough)

	b.current = mergeBlk
}

func (b *cfgBuilder) visitBranch(node *treesitter.Node) {
	if node == nil {
		return
	}
	if isBlockKind(node.Kind()) {
		b.visitBlock(node)
	} else {
		b.visitStmt(node)
	}
}

func (b *cfgBuilder) visitLoop(forNode *treesitter.Node, _ string) {
	headBlk := b.newBB()
	bodyBlk := b.newBB()
	exitBlk := b.newBB()

	b.addEdge(b.current, headBlk, EdgeFallthrough)
	b.addEdge(headBlk, bodyBlk, EdgeTrue)
	b.addEdge(headBlk, exitBlk, EdgeFalse)

	b.loopHead = append(b.loopHead, headBlk)
	b.loopExit = append(b.loopExit, exitBlk)

	b.current = bodyBlk
	body := findBody(forNode)
	if body != nil {
		b.visitBlock(body)
	} else {
		for i := uint(0); i < forNode.NamedChildCount(); i++ {
			c := forNode.NamedChild(i)
			if c != nil && isBlockKind(c.Kind()) {
				b.visitBlock(c)
				break
			}
		}
	}
	b.addEdge(b.current, headBlk, EdgeBack) // back-edge

	b.loopHead = b.loopHead[:len(b.loopHead)-1]
	b.loopExit = b.loopExit[:len(b.loopExit)-1]

	b.current = exitBlk
}

func (b *cfgBuilder) visitWhile(whileNode *treesitter.Node) {
	b.visitLoop(whileNode, "while")
}

func (b *cfgBuilder) visitDo(doNode *treesitter.Node) {
	bodyBlk := b.newBB()
	headBlk := b.newBB()
	exitBlk := b.newBB()

	b.addEdge(b.current, bodyBlk, EdgeFallthrough)
	b.loopHead = append(b.loopHead, headBlk)
	b.loopExit = append(b.loopExit, exitBlk)

	b.current = bodyBlk
	body := findBody(doNode)
	if body != nil {
		b.visitBlock(body)
	}
	b.addEdge(bodyBlk, headBlk, EdgeFallthrough)
	b.addEdge(headBlk, bodyBlk, EdgeTrue)
	b.addEdge(headBlk, exitBlk, EdgeFalse)

	b.loopHead = b.loopHead[:len(b.loopHead)-1]
	b.loopExit = b.loopExit[:len(b.loopExit)-1]
	b.current = exitBlk
}

func (b *cfgBuilder) visitSwitch(sw *treesitter.Node) {
	for i := uint(0); i < sw.NamedChildCount(); i++ {
		c := sw.NamedChild(i)
		if c == nil {
			continue
		}
		if isBlockKind(c.Kind()) || c.Kind() == "case_statement" || c.Kind() == "switch_case" {
			b.visitBlock(c)
		}
	}
}

func (b *cfgBuilder) visitTry(tryNode *treesitter.Node) {
	for i := uint(0); i < tryNode.NamedChildCount(); i++ {
		c := tryNode.NamedChild(i)
		if c == nil {
			continue
		}
		if isBlockKind(c.Kind()) {
			b.visitBlock(c)
		}
	}
}

// firstStmtChild returns the first named child that is a statement or block.
func firstStmtChild(node *treesitter.Node) *treesitter.Node {
	for i := uint(0); i < node.NamedChildCount(); i++ {
		c := node.NamedChild(i)
		if c == nil {
			continue
		}
		if isBlockKind(c.Kind()) || isStmtKind(c.Kind()) {
			return c
		}
	}
	return nil
}

func isStmtKind(kind string) bool {
	switch kind {
	case "if_statement", "if_expression", "for_statement", "for_in_statement",
		"foreach_statement", "while_statement", "do_statement", "do_while_statement",
		"switch_statement", "match_expression", "try_statement",
		"return_statement", "break_statement", "continue_statement",
		"throw_statement", "raise_statement",
		"expression_statement", "expression_statement_node",
		"local_variable_declaration", "declaration", "variable_declaration",
		"short_var_declaration", "var_declaration", "assign_statement",
		"simple_statement", "statement", "init_statement":
		return true
	}
	return false
}

// extractCFGs walks the CST root collecting function nodes for the given
// language and builds a CFG per function. Called from ParseFile (cgo path).
func extractCFGs(root *treesitter.Node, content []byte, file, lang string) []FunctionCFG {
	if root == nil {
		return nil
	}
	fnKinds := funcKindsForLang(lang)
	if len(fnKinds) == 0 {
		return nil
	}
	var out []FunctionCFG
	var walk func(n *treesitter.Node)
	walk = func(n *treesitter.Node) {
		if n == nil {
			return
		}
		if fnKinds[n.Kind()] {
			name := functionNameForNode(n, content)
			if cfg := BuildCFG(n, content, name, file); cfg != nil && len(cfg.Blocks) > 0 {
				out = append(out, *cfg)
			}
		}
		for i := uint(0); i < n.NamedChildCount(); i++ {
			walk(n.NamedChild(i))
		}
	}
	walk(root)
	return out
}

func funcKindsForLang(lang string) map[string]bool {
	switch lang {
	case "c", "cpp":
		return map[string]bool{"function_definition": true}
	case "go":
		return map[string]bool{"function_declaration": true, "method_declaration": true}
	case "java":
		return map[string]bool{"method_declaration": true, "constructor_declaration": true}
	case "python":
		return map[string]bool{"function_definition": true}
	}
	return nil
}

// functionNameForNode best-effort extracts a function name from a CST function
// node across the 5 grammars (used only to label the CFG; falls back to "").
func functionNameForNode(n *treesitter.Node, content []byte) string {
	if n == nil {
		return ""
	}
	// C/C++ function_definition: name lives in function_declarator > identifier
	if n.Kind() == "function_definition" {
		for i := uint(0); i < n.NamedChildCount(); i++ {
			c := n.NamedChild(i)
			if c != nil && c.Kind() == "function_declarator" {
				for j := uint(0); j < c.NamedChildCount(); j++ {
					gc := c.NamedChild(j)
					if gc != nil && (gc.Kind() == "identifier" || gc.Kind() == "field_identifier") {
						return safeText(content, gc.StartByte(), gc.EndByte())
					}
				}
			}
		}
	}
	// Go/Java method/function & Python function_definition: first identifier/field_identifier child.
	for i := uint(0); i < n.NamedChildCount(); i++ {
		c := n.NamedChild(i)
		if c == nil {
			continue
		}
		k := c.Kind()
		if k == "identifier" || k == "field_identifier" {
			return safeText(content, c.StartByte(), c.EndByte())
		}
	}
	return ""
}
