//go:build !cgo

package parser

import (
	"fmt"
	"os"
	"regexp"
	"strings"
)

// Language-specific regex patterns for function detection
var funcPatterns = map[string]*regexp.Regexp{
	"c":   regexp.MustCompile(`(?m)^\s*(?:static\s+|inline\s+|extern\s+)*(?:void|int|char|float|double|long|short|unsigned|size_t|ssize_t|uint\w*|int\w*|bool|struct\s+\w+|\w+\s*\*)\s+(\w+)\s*\([^)]*\)\s*\{`),
	"cpp": regexp.MustCompile(`(?m)^\s*(?:static\s+|inline\s+|extern\s+|virtual\s+|const\s+)*(?:void|int|char|float|double|long|short|unsigned|size_t|ssize_t|uint\w*|int\w*|bool|auto|string|wstring|\w+::\w+|\w+<[^>]*>|\w+\s*\*|\w+\s*&)\s+(\w+)\s*\([^)]*\)\s*(?:const\s*)?\{`),
	"go": regexp.MustCompile(`(?m)^func\s+(?:\(\w+\s+\*?\w+\)\s+)?(\w+)\s*\(`),
	"java": regexp.MustCompile(`(?m)^\s*(?:public|private|protected|static|final|synchronized|abstract|native)\s+(?:[<>\[\]\w.,\s]+\s+)?(\w+)\s*\([^)]*\)\s*(?:throws\s+[^{\n]+)?\s*\{`),
	"python": regexp.MustCompile(`(?m)^\s*def\s+(\w+)\s*\(`),
	"javascript": regexp.MustCompile(`(?m)(?:function\s+(\w+)\s*\(|(\w+)\s*=\s*(?:async\s+)?function\s*\(|(\w+)\s*=\s*\([^)]*\)\s*=>|(\w+)\s*\([^)]*\)\s*\{)`),
}

// Type/struct/class detection patterns
var typePatterns = map[string]*regexp.Regexp{
	"c":   regexp.MustCompile(`(?m)^\s*(?:typedef\s+)?struct\s+(\w+)\s*\{`),
	"cpp": regexp.MustCompile(`(?m)^\s*(?:class|struct|enum\s+class|enum)\s+(\w+)`),
	"go": regexp.MustCompile(`(?m)^type\s+(\w+)\s+(?:struct|interface)\s*\{`),
	"java": regexp.MustCompile(`(?m)^\s*(?:public\s+)?(?:class|interface|enum)\s+(\w+)`),
	"python": regexp.MustCompile(`(?m)^class\s+(\w+)\s*[(:]`),
	"javascript": regexp.MustCompile(`(?m)^\s*class\s+(\w+)`),
}

func ParseFile(filePath string, lang string) (*ParseResult, error) {
	content, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("reading file: %w", err)
	}

	result := &ParseResult{File: filePath, Language: lang}

	// JS/TS file size and line length protection (mirrors parser_ts.go)
	if lang == "javascript" || lang == "typescript" {
		if len(content) > 512*1024 {
			return result, nil // skip files > 512KB
		}
		lines := strings.Split(string(content), "
")
		for _, line := range lines {
			if len(line) > 2000 {
				return result, nil // skip files with lines > 2000 chars
			}
		}
	}

	// Extract functions
	if pat, ok := funcPatterns[lang]; ok {
		matches := pat.FindAllStringSubmatch(string(content), -1)
		for _, m := range matches {
			name := ""
			for _, g := range m[1:] {
				if g != "" {
					name = g
					break
				}
			}
			if name == "" || isKeyword(name, lang) {
				continue
			}
			// Find approximate line number
			pos := strings.Index(string(content), m[0])
			lineNo := uint(1)
			if pos >= 0 {
				lineNo = uint(strings.Count(string(content)[:pos], "\n") + 1)
			}
			endLine := lineNo + uint(strings.Count(m[0], "\n"))
			result.Functions = append(result.Functions, FunctionInfo{
				Name:      name,
				File:      filePath,
				StartLine: lineNo,
				EndLine:   endLine,
			})
		}
	}

	// Extract types/classes/structs
	if pat, ok := typePatterns[lang]; ok {
		matches := pat.FindAllStringSubmatch(string(content), -1)
		for _, m := range matches {
			name := m[1]
			if name == "" || isKeyword(name, lang) {
				continue
			}
			pos := strings.Index(string(content), m[0])
			lineNo := uint(1)
			if pos >= 0 {
				lineNo = uint(strings.Count(string(content)[:pos], "\n") + 1)
			}
			kind := "type"
			switch lang {
			case "c", "cpp":
				if strings.Contains(m[0], "struct") {
					kind = "struct"
				} else if strings.Contains(m[0], "class") {
					kind = "class"
				} else if strings.Contains(m[0], "enum") {
					kind = "enum"
				}
			case "go":
				if strings.Contains(strings.ToLower(m[0]), "interface") {
					kind = "interface"
				} else {
					kind = "struct"
				}
			case "java":
				if strings.Contains(m[0], "interface") {
					kind = "interface"
				} else if strings.Contains(m[0], "enum") {
					kind = "enum"
				} else {
					kind = "class"
				}
			case "python":
				kind = "class"
			case "javascript":
				kind = "class"
			}
			result.Types = append(result.Types, TypeInfo{
				Name:      name,
				Kind:      kind,
				File:      filePath,
				StartLine: lineNo,
			})
		}
	}

	// Simple variable extraction for C/C++ declarations
	if lang == "c" || lang == "cpp" {
		varDeclPat := regexp.MustCompile(`(?m)^\s*(?:static\s+|extern\s+|const\s+)*(?:int|char|float|double|long|short|unsigned|bool|size_t|void)\s+(\w+)\s*[=;]`)
		matches := varDeclPat.FindAllStringSubmatch(string(content), -1)
		for _, m := range matches {
			name := m[1]
			if name == "" || isKeyword(name, lang) {
				continue
			}
			pos := strings.Index(string(content), m[0])
			lineNo := uint(1)
			if pos >= 0 {
				lineNo = uint(strings.Count(string(content)[:pos], "\n") + 1)
			}
			result.Variables = append(result.Variables, VariableInfo{
				Name: name,
				File: filePath,
				Line: lineNo,
			})
		}
	}


	// Variable extraction for Go
	if lang == "go" {
		varDeclPat := regexp.MustCompile(`(?m)^\s*(?:var\s+)?(\w+)\s*(?:=|:=)`)
		matches := varDeclPat.FindAllStringSubmatch(string(content), -1)
		for _, m := range matches {
			name := m[1]
			if name == "" || isKeyword(name, lang) {
				continue
			}
			pos := strings.Index(string(content), m[0])
			lineNo := uint(1)
			if pos >= 0 {
				lineNo = uint(strings.Count(string(content)[:pos], "\n") + 1)
			}
			result.Variables = append(result.Variables, VariableInfo{
				Name: name,
				File: filePath,
				Line: lineNo,
			})
		}
	}

	// Variable extraction for Java (type-prefixed declaration)
	if lang == "java" {
		varDeclPat := regexp.MustCompile(`(?m)^\s*(?:\w+\s+)*(?:int|long|double|float|boolean|char|byte|short|String|var|Object)\s+(\w+)\s*(?:=|;)`)
		matches := varDeclPat.FindAllStringSubmatch(string(content), -1)
		for _, m := range matches {
			name := m[1]
			if name == "" || isKeyword(name, lang) {
				continue
			}
			pos := strings.Index(string(content), m[0])
			lineNo := uint(1)
			if pos >= 0 {
				lineNo = uint(strings.Count(string(content)[:pos], "\n") + 1)
			}
			result.Variables = append(result.Variables, VariableInfo{
				Name: name,
				File: filePath,
				Line: lineNo,
			})
		}
	}

	// Variable extraction for Python (line-start assignment)
	if lang == "python" {
		varDeclPat := regexp.MustCompile(`(?m)^\s*(\w+)\s*=\s*[^=\n]`)
		matches := varDeclPat.FindAllStringSubmatch(string(content), -1)
		for _, m := range matches {
			name := m[1]
			if name == "" || isKeyword(name, lang) {
				continue
			}
			pos := strings.Index(string(content), m[0])
			lineNo := uint(1)
			if pos >= 0 {
				lineNo = uint(strings.Count(string(content)[:pos], "\n") + 1)
			}
			result.Variables = append(result.Variables, VariableInfo{
				Name: name,
				File: filePath,
				Line: lineNo,
			})
		}
	}


	return result, nil
}

// isKeyword checks if a name is a language keyword that shouldn't be treated as an identifier.
func isKeyword(name, lang string) bool {
	keywords := map[string]bool{
		"if": true, "else": true, "for": true, "while": true, "do": true,
		"switch": true, "case": true, "default": true, "break": true, "continue": true,
		"return": true, "goto": true, "sizeof": true, "typedef": true, "volatile": true,
		"const": true, "static": true, "extern": true, "register": true, "auto": true,
		"unsigned": true, "signed": true, "void": true, "new": true, "delete": true,
		"try": true, "catch": true, "throw": true, "throws": true, "finally": true,
		"public": true, "private": true, "protected": true, "class": true, "struct": true,
		"enum": true, "interface": true, "extends": true, "implements": true,
		"package": true, "import": true, "var": true, "func": true, "type": true,
		"def": true, "pass": true, "yield": true, "async": true, "await": true,
	}
	return keywords[name]
}
