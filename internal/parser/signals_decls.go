//go:build cgo

package parser

import (
	"strconv"
	"strings"

	treesitter "github.com/tree-sitter/go-tree-sitter"
)

// ── S3 Declarations + S5 Imports (F6 fix, EPIC-011 FEATURE-002 TG-F) ──
//
// Previously result.Declarations was never populated (prescreener dead code,
// SafeCount always 0) and C/C++ #include was never captured (Imports empty on
// the cgo path). These extractors fix F6 and feed the prescreener.

// extractCInclude parses a C/C++ preproc_include node into an Import.
func extractCInclude(node *treesitter.Node, content []byte, file string) Import {
	imp := Import{File: file, Line: node.StartPosition().Row + 1}
	for i := uint(0); i < node.NamedChildCount(); i++ {
		c := node.NamedChild(i)
		if c == nil {
			continue
		}
		k := c.Kind()
		if k == "system_lib_string" || k == "string_literal" {
			raw := safeText(content, c.StartByte(), c.EndByte())
			raw = strings.TrimSpace(raw)
			if len(raw) >= 2 && (raw[0] == '<' || raw[0] == '"') {
				raw = raw[1 : len(raw)-1]
			}
			imp.Path = raw
			if k == "system_lib_string" {
				imp.Kind = "system"
			} else {
				imp.Kind = "user"
			}
			break
		}
	}
	if imp.Path == "" {
		return imp
	}
	imp.Category = categorizeCInclude(imp.Path)
	return imp
}

func categorizeCInclude(path string) string {
	l := strings.ToLower(path)
	switch {
	case strings.Contains(l, "openssl") || strings.Contains(l, "crypto") ||
		strings.Contains(l, "md5") || strings.Contains(l, "sha") ||
		strings.Contains(l, "rand") || strings.Contains(l, "evp") ||
		strings.Contains(l, "aes") || strings.Contains(l, "des") ||
		strings.Contains(l, "bcrypt") || strings.Contains(l, "tls") || strings.Contains(l, "ssl"):
		return "crypto"
	case strings.Contains(l, "socket") || strings.Contains(l, "netdb") ||
		strings.Contains(l, "netinet") || strings.Contains(l, "arpa") || strings.Contains(l, "net"):
		return "net"
	case strings.Contains(l, "pthread"):
		return "sys"
	case strings.Contains(l, "stdio") || strings.Contains(l, "stdlib") ||
		strings.Contains(l, "string") || strings.Contains(l, "stdint") ||
		strings.Contains(l, "stddef") || strings.Contains(l, "time") || strings.Contains(l, "errno"):
		return "sys"
	}
	return "generic"
}

// collectDeclarations walks the CST collecting variable declarations (S3),
// tracking the enclosing function so each Declaration carries its Function.
func collectDeclarations(root *treesitter.Node, content []byte, file, lang string) []Declaration {
	if root == nil {
		return nil
	}
	var out []Declaration
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
		if k == "declaration" {
			out = append(out, extractDeclaration(n, content, file, curFunc)...)
		}
		for i := uint(0); i < n.NamedChildCount(); i++ {
			walk(n.NamedChild(i), curFunc)
		}
	}
	walk(root, "")
	return out
}

// extractDeclaration parses a C/C++ declaration node into one or more
// Declarations (a declaration may declare multiple variables: `int a, b;`).
func extractDeclaration(node *treesitter.Node, content []byte, file, curFunc string) []Declaration {
	var typeName string
	isConst := false
	var declarators []*treesitter.Node

	for i := uint(0); i < node.NamedChildCount(); i++ {
		c := node.NamedChild(i)
		if c == nil {
			continue
		}
		k := c.Kind()
		if k == "type_qualifier" {
			if safeText(content, c.StartByte(), c.EndByte()) == "const" {
				isConst = true
			}
			continue
		}
		if isCTypeKind(k) {
			// Use the type node's full text (e.g. "unsigned char" for
			// sized_type_specifier, whose named child is just "char").
			if typeName == "" {
				typeName = strings.TrimSpace(safeText(content, c.StartByte(), c.EndByte()))
			}
			continue
		}
		// Remaining named children are declarators / init_declarators.
		declarators = append(declarators, c)
	}

	var out []Declaration
	for _, d := range declarators {
		decl := parseCDeclarator(d, content, file, curFunc, typeName, isConst)
		if decl.Name != "" {
			out = append(out, decl)
		}
	}
	return out
}

func parseCDeclarator(d *treesitter.Node, content []byte, file, curFunc, typeName string, isConst bool) Declaration {
	decl := Declaration{
		File:      file,
		Line:      d.StartPosition().Row + 1,
		TypeName:  typeName,
		IsConst:   isConst,
		Function:  curFunc,
		ArraySize: 0,
	}
	if d == nil {
		return decl
	}
	switch d.Kind() {
	case "identifier", "field_identifier", "type_identifier":
		decl.Name = safeText(content, d.StartByte(), d.EndByte())
	case "array_declarator":
		for i := uint(0); i < d.NamedChildCount(); i++ {
			c := d.NamedChild(i)
			if c == nil {
				continue
			}
			ck := c.Kind()
			if ck == "identifier" || ck == "field_identifier" {
				decl.Name = safeText(content, c.StartByte(), c.EndByte())
			} else if ck == "number_literal" {
				if n, err := strconv.Atoi(safeText(content, c.StartByte(), c.EndByte())); err == nil {
					decl.ArraySize = n
				}
			}
		}
	case "pointer_declarator":
		decl.IsPointer = true
		for i := uint(0); i < d.NamedChildCount(); i++ {
			c := d.NamedChild(i)
			if c == nil {
				continue
			}
			ck := c.Kind()
			if ck == "identifier" || ck == "field_identifier" {
				decl.Name = safeText(content, c.StartByte(), c.EndByte())
			} else if ck == "array_declarator" {
				// pointer to array: `int (*p)[n]`
				for j := uint(0); j < c.NamedChildCount(); j++ {
					cc := c.NamedChild(j)
					if cc == nil {
						continue
					}
					if cc.Kind() == "identifier" || cc.Kind() == "field_identifier" {
						decl.Name = safeText(content, cc.StartByte(), cc.EndByte())
					} else if cc.Kind() == "number_literal" {
						if n, err := strconv.Atoi(safeText(content, cc.StartByte(), cc.EndByte())); err == nil {
							decl.ArraySize = n
						}
					}
				}
			}
		}
	case "init_declarator":
		// `int x = 5;` — first declarator-like child is the real declarator.
		for i := uint(0); i < d.NamedChildCount(); i++ {
			c := d.NamedChild(i)
			if c == nil {
				continue
			}
			ck := c.Kind()
			if ck == "identifier" || ck == "field_identifier" || ck == "array_declarator" || ck == "pointer_declarator" {
				sub := parseCDeclarator(c, content, file, curFunc, typeName, isConst)
				sub.File = file
				sub.TypeName = typeName
				sub.IsConst = isConst
				sub.Function = curFunc
				return sub
			}
		}
	}
	decl.Category = categorizeDeclaration(decl)
	return decl
}

// categorizeDeclaration classifies a declaration for downstream rules.
// Categories: buffer / key / credential / counter.
func categorizeDeclaration(d Declaration) string {
	name := strings.ToLower(d.Name)
	switch {
	case strings.Contains(name, "token") || strings.Contains(name, "auth") ||
		strings.Contains(name, "secret") || strings.Contains(name, "pass") ||
		strings.Contains(name, "cred") || strings.Contains(name, "session"):
		return "credential"
	case strings.Contains(name, "key"):
		return "key"
	case strings.Contains(name, "counter") || strings.Contains(name, "count") ||
		strings.Contains(name, "idx") || strings.Contains(name, "index") ||
		strings.Contains(name, "len") || strings.Contains(name, "size"):
		return "counter"
	}
	// Default: arrays/buffers are "buffer"; scalars without a better fit too.
	return "buffer"
}

func isCTypeKind(k string) bool {
	switch k {
	case "primitive_type", "sized_type_specifier", "struct_specifier",
		"union_specifier", "enum_specifier", "type_identifier",
		"class_specifier", "scoped_type_identifier":
		return true
	}
	return false
}
