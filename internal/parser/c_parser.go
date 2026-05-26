package parser

import (
	"fmt"
	"os"

	treesitter "github.com/tree-sitter/go-tree-sitter"
	c "github.com/tree-sitter/tree-sitter-c/bindings/go"
	cpp "github.com/tree-sitter/tree-sitter-cpp/bindings/go"
)

type ParseResult struct {
	File      string         `json:"file"`
	Language  string         `json:"language"`
	Functions []FunctionInfo `json:"functions"`
	Variables []VariableInfo `json:"variables"`
	Types     []TypeInfo     `json:"types"`
}

type FunctionInfo struct {
	Name      string `json:"name"`
	File      string `json:"file"`
	StartLine uint   `json:"start_line"`
	EndLine   uint   `json:"end_line"`
}

type VariableInfo struct {
	Name     string `json:"name"`
	TypeName string `json:"type_name"`
	File     string `json:"file"`
	Line     uint   `json:"line"`
}

type TypeInfo struct {
	Name      string `json:"name"`
	Kind      string `json:"kind"`
	File      string `json:"file"`
	StartLine uint   `json:"start_line"`
}

func ParseFile(filePath string, language string) (*ParseResult, error) {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("reading file: %w", err)
	}

	var parser *treesitter.Parser

	switch language {
	case "c":
		parser = treesitter.NewParser()
		defer parser.Close()
		if err := parser.SetLanguage(treesitter.NewLanguage(c.Language())); err != nil {
			return nil, fmt.Errorf("setting language: %w", err)
		}
	case "cpp", "c++":
		parser = treesitter.NewParser()
		defer parser.Close()
		if err := parser.SetLanguage(treesitter.NewLanguage(cpp.Language())); err != nil {
			return nil, fmt.Errorf("setting language: %w", err)
		}
	default:
		return nil, fmt.Errorf("unsupported language: %s", language)
	}

	tree := parser.Parse(content, nil)
	defer tree.Close()

	result := &ParseResult{
		File:     filePath,
		Language: language,
	}

	// Walk top-level nodes only for function definitions
	root := tree.RootNode()
	for i := uint(0); i < root.ChildCount(); i++ {
		child := root.Child(i)
		kind := child.Kind()
		switch kind {
		case "function_definition":
			fn := extractFunction(child, content, filePath)
			if fn.Name != "" {
				result.Functions = append(result.Functions, fn)
			}
		case "declaration":
			result.Variables = append(result.Variables, extractDeclarations(child, content, filePath)...)
		case "type_definition", "struct_specifier", "enum_specifier":
			ti := extractType(child, kind, filePath)
			if ti.Name != "" {
				result.Types = append(result.Types, ti)
			}
		}
	}

	return result, nil
}

func extractFunction(node *treesitter.Node, content []byte, filePath string) FunctionInfo {
	fn := FunctionInfo{File: filePath}
	for i := uint(0); i < node.ChildCount(); i++ {
		child := node.Child(i)
		if child.Kind() == "function_declarator" {
			for j := uint(0); j < child.ChildCount(); j++ {
				decl := child.Child(j)
				if decl.Kind() == "identifier" || decl.Kind() == "field_identifier" {
					if int(decl.EndByte()) <= len(content) {
						fn.Name = string(content[decl.StartByte():decl.EndByte()])
					}
					break
				}
			}
		}
		if child.Kind() == "identifier" && fn.Name == "" {
			fn.Name = string(content[child.StartByte():child.EndByte()])
		}
	}
	fn.StartLine = node.StartPosition().Row + 1
	fn.EndLine = node.EndPosition().Row + 1
	return fn
}

func extractDeclarations(node *treesitter.Node, content []byte, filePath string) []VariableInfo {
	var vars []VariableInfo
	for i := uint(0); i < node.ChildCount(); i++ {
		child := node.Child(i)
		if child.Kind() == "init_declarator" {
			v := VariableInfo{File: filePath, Line: child.StartPosition().Row + 1}
			for j := uint(0); j < child.ChildCount(); j++ {
				sub := child.Child(j)
				if sub.Kind() == "identifier" && v.Name == "" {
					v.Name = string(content[sub.StartByte():sub.EndByte()])
				}
			}
			if v.Name != "" {
				vars = append(vars, v)
			}
		}
	}
	return vars
}

func extractType(node *treesitter.Node, kind, filePath string) TypeInfo {
	ti := TypeInfo{File: filePath, Kind: kind, StartLine: node.StartPosition().Row + 1}
	for i := uint(0); i < node.ChildCount(); i++ {
		child := node.Child(i)
		if child.Kind() == "type_identifier" || child.Kind() == "identifier" {
			// Use a large enough buffer for UTF-8 text
			buf := make([]byte, 1024)
			ti.Name = child.Utf8Text(buf)
		}
	}
	return ti
}
