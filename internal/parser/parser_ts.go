//go:build cgo

package parser

import (
	"fmt"
	"os"

	treesitter "github.com/tree-sitter/go-tree-sitter"
	c "github.com/tree-sitter/tree-sitter-c/bindings/go"
	cpp "github.com/tree-sitter/tree-sitter-cpp/bindings/go"
	goL "github.com/tree-sitter/tree-sitter-go/bindings/go"
	java "github.com/tree-sitter/tree-sitter-java/bindings/go"
	py "github.com/tree-sitter/tree-sitter-python/bindings/go"
)

func ParseFile(filePath string, lang string) (*ParseResult, error) {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("reading file: %w", err)
	}

	parser := treesitter.NewParser()
	defer parser.Close()

	switch lang {
	case "c":
		parser.SetLanguage(treesitter.NewLanguage(c.Language()))
	case "cpp":
		parser.SetLanguage(treesitter.NewLanguage(cpp.Language()))
	case "python":
		parser.SetLanguage(treesitter.NewLanguage(py.Language()))
	case "go":
		parser.SetLanguage(treesitter.NewLanguage(goL.Language()))
	case "java":
		parser.SetLanguage(treesitter.NewLanguage(java.Language()))
		case "javascript":
			// JavaScript uses regex parser (no tree-sitter grammar compiled in)
			return parseJSFile(filePath)
	default:
		return nil, fmt.Errorf("unsupported language: %s", lang)
	}

	tree := parser.Parse(content, nil)
	defer tree.Close()

	result := &ParseResult{File: filePath, Language: lang}
	root := tree.RootNode()
	walkTopLevel(root, content, filePath, lang, result)
	return result, nil
}

func walkTopLevel(node *treesitter.Node, content []byte, file, lang string, result *ParseResult) {
	for i := uint(0); i < node.ChildCount(); i++ {
		child := node.Child(i)
		if child == nil {
			continue
		}
		kind := child.Kind()

		switch lang {
		case "c", "cpp":
			switch kind {
			case "function_definition":
				if fn := extractIdent(child, content, file, "function_declarator"); fn.Name != "" {
					fn.StartLine = child.StartPosition().Row + 1
					fn.EndLine = child.EndPosition().Row + 1
					result.Functions = append(result.Functions, fn)
				}
			case "declaration":
				result.Variables = append(result.Variables, extractInitDecls(child, content, file)...)
			case "struct_specifier", "class_specifier", "union_specifier":
				if t := extractTypeName(child, content, file, kind); t.Name != "" {
					result.Types = append(result.Types, t)
				}
			case "type_definition":
				if t := extractTypeName(child, content, file, "typedef"); t.Name != "" {
					result.Types = append(result.Types, t)
				}
			case "enum_specifier":
				if t := extractTypeName(child, content, file, "enum"); t.Name != "" {
					result.Types = append(result.Types, t)
				}
			}

		case "python":
			switch kind {
			case "function_definition":
				if fn := extractNamedChild(child, content, file, "identifier"); fn.Name != "" {
					fn.StartLine = child.StartPosition().Row + 1
					fn.EndLine = child.EndPosition().Row + 1
					result.Functions = append(result.Functions, fn)
				}
			case "class_definition":
				if t := extractNamedChild(child, content, file, "identifier"); t.Name != "" {
					tis := TypeInfo{Name: t.Name, Kind: "class", File: file, StartLine: child.StartPosition().Row + 1}
					result.Types = append(result.Types, tis)
				}
				// also walk methods inside class
				walkTopLevel(child, content, file, lang, result)
			}

		case "go":
			switch kind {
			case "function_declaration":
				if fn := extractNamedChild(child, content, file, "identifier"); fn.Name != "" {
					fn.StartLine = child.StartPosition().Row + 1
					fn.EndLine = child.EndPosition().Row + 1
					result.Functions = append(result.Functions, fn)
				}
			case "method_declaration":
				fn := FunctionInfo{File: file, StartLine: child.StartPosition().Row + 1, EndLine: child.EndPosition().Row + 1}
			for j := uint(0); j < child.ChildCount(); j++ {
				gc := child.Child(j)
				if gc == nil || gc.Kind() != "identifier" {
					continue
				}
				fn.Name = safeText(content, gc.StartByte(), gc.EndByte())
			}
				if fn.Name != "" {
					result.Functions = append(result.Functions, fn)
				}
			case "type_declaration":
				if t := extractGoType(child, content, file); t.Name != "" {
					result.Types = append(result.Types, t)
				}
			case "var_declaration":
				result.Variables = append(result.Variables, extractInitDecls(child, content, file)...)
			}

		case "java":
			switch kind {
			case "class_declaration", "interface_declaration":
				kindName := "class"
				if kind == "interface_declaration" {
					kindName = "interface"
				}
				if t := extractNamedChild(child, content, file, "identifier"); t.Name != "" {
					result.Types = append(result.Types, TypeInfo{
						Name: t.Name, Kind: kindName, File: file, StartLine: child.StartPosition().Row + 1,
					})
				}
				// walk into class_body for methods
				for j := uint(0); j < child.ChildCount(); j++ {
					body := child.Child(j)
					if body == nil || body.Kind() != "class_body" {
						continue
					}
					for k := uint(0); k < body.ChildCount(); k++ {
						method := body.Child(k)
						if method == nil || method.Kind() != "method_declaration" {
							continue
						}
						fn := FunctionInfo{File: file, StartLine: method.StartPosition().Row + 1, EndLine: method.EndPosition().Row + 1}
						for l := uint(0); l < method.ChildCount(); l++ {
							mchild := method.Child(l)
							if mchild != nil && mchild.Kind() == "identifier" {
								fn.Name = safeText(content, mchild.StartByte(), mchild.EndByte())
							}
						}
						if fn.Name != "" {
							result.Functions = append(result.Functions, fn)
						}
					}
				}
			case "variable_declaration":
				result.Variables = append(result.Variables, extractInitDecls(child, content, file)...)
			}
		}
	}
}

// extractIdent extracts a named function from a specific child kind (e.g., "function_declarator").
func extractIdent(node *treesitter.Node, content []byte, file, declaratorKind string) FunctionInfo {
	fn := FunctionInfo{File: file}
	for i := uint(0); i < node.ChildCount(); i++ {
		child := node.Child(i)
		if child == nil {
			continue
		}
		if child.Kind() == declaratorKind {
			for j := uint(0); j < child.ChildCount(); j++ {
				decl := child.Child(j)
				if decl == nil {
					continue
				}
				if decl.Kind() == "identifier" || decl.Kind() == "field_identifier" {
					fn.Name = safeText(content, decl.StartByte(), decl.EndByte())
				}
			}
		}
		if child.Kind() == "identifier" && fn.Name == "" {
			fn.Name = safeText(content, child.StartByte(), child.EndByte())
		}
	}
	fn.StartLine = node.StartPosition().Row + 1
	fn.EndLine = node.EndPosition().Row + 1
	return fn
}

// extractNamedChild finds the first child with a matching kind and returns its text as Name.
func extractNamedChild(node *treesitter.Node, content []byte, file, targetKind string) FunctionInfo {
	fn := FunctionInfo{File: file}
	for i := uint(0); i < node.ChildCount(); i++ {
		child := node.Child(i)
		if child != nil && child.Kind() == targetKind {
			fn.Name = safeText(content, child.StartByte(), child.EndByte())
			break
		}
	}
	return fn
}

// extractInitDeclarators extracts variable names from declaration nodes.
func extractInitDecls(node *treesitter.Node, content []byte, file string) []VariableInfo {
	var vars []VariableInfo
	for i := uint(0); i < node.ChildCount(); i++ {
		child := node.Child(i)
		if child == nil {
			continue
		}
		if child.Kind() == "init_declarator" {
			v := VariableInfo{File: file, Line: child.StartPosition().Row + 1}
			for j := uint(0); j < child.ChildCount(); j++ {
				sub := child.Child(j)
				if sub == nil {
					continue
				}
				if sub.Kind() == "identifier" && v.Name == "" {
					v.Name = safeText(content, sub.StartByte(), sub.EndByte())
				}
			}
			if v.Name == "" {
				continue
			}
			for j := uint(0); j < child.ChildCount(); j++ {
				ad := child.Child(j)
				if ad == nil || ad.Kind() != "array_declarator" {
					continue
				}
				for k := uint(0); k < ad.ChildCount(); k++ {
					ak := ad.Child(k)
					if ak != nil && ak.Kind() == "identifier" && v.Name == "" {
						v.Name = safeText(content, ak.StartByte(), ak.EndByte())
					}
				}
			}
			if v.Name != "" {
				vars = append(vars, v)
			}
		}
		if child.Kind() == "variable_declarator" {
			v := VariableInfo{File: file, Line: child.StartPosition().Row + 1}
			for j := uint(0); j < child.ChildCount(); j++ {
				sub := child.Child(j)
				if sub == nil {
					continue
				}
				if sub.Kind() == "identifier" && v.Name == "" {
					v.Name = safeText(content, sub.StartByte(), sub.EndByte())
				}
			}
			if v.Name != "" {
				vars = append(vars, v)
			}
		}
	}
	return vars
}

// extractGoType extracts type info from Go type_declaration nodes.
func extractGoType(node *treesitter.Node, content []byte, file string) TypeInfo {
	for i := uint(0); i < node.ChildCount(); i++ {
		child := node.Child(i)
		if child == nil || child.Kind() != "type_spec" {
			continue
		}
		ti := TypeInfo{File: file, StartLine: child.StartPosition().Row + 1}
		for j := uint(0); j < child.ChildCount(); j++ {
			gc := child.Child(j)
			if gc == nil || gc.Kind() != "type_identifier" {
				continue
			}
			ti.Name = safeText(content, gc.StartByte(), gc.EndByte())
			for k := uint(0); k < child.ChildCount(); k++ {
				switch ck := child.Child(k); {
				case ck != nil && ck.Kind() == "struct_type":
					ti.Kind = "struct"
				case ck != nil && ck.Kind() == "interface_type":
					ti.Kind = "interface"
				}
			}
			break
		}
		if ti.Name != "" && ti.Kind == "" {
			ti.Kind = "type"
		}
		return ti
	}
	return TypeInfo{}
}

// extractTypeName extracts type name from struct/class/enum nodes.
func extractTypeName(node *treesitter.Node, content []byte, file, kind string) TypeInfo {
	ti := TypeInfo{File: file, Kind: kind, StartLine: node.StartPosition().Row + 1}
	for i := uint(0); i < node.ChildCount(); i++ {
		child := node.Child(i)
		if child == nil {
			continue
		}
		if child.Kind() == "type_identifier" || child.Kind() == "identifier" {
			ti.Name = safeText(content, child.StartByte(), child.EndByte())
			break
		}
	}
	return ti
}

func safeText(content []byte, start, end uint) string {
	if int(start) >= len(content) || int(end) > len(content) || start > end {
		return ""
	}
	return string(content[start:end])
}


