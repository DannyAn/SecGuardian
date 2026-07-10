//go:build cgo

package parser

import (
	"fmt"
	"os"
	"strings"
	treesitter "github.com/tree-sitter/go-tree-sitter"
	c "github.com/tree-sitter/tree-sitter-c/bindings/go"
	cpp "github.com/tree-sitter/tree-sitter-cpp/bindings/go"
	goL "github.com/tree-sitter/tree-sitter-go/bindings/go"
	java "github.com/tree-sitter/tree-sitter-java/bindings/go"
	py "github.com/tree-sitter/tree-sitter-python/bindings/go"
)

func init() { ParserMode = "tree-sitter (CGO)" }

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

	// ── Signal Matrix post-processing (S2-S7) ──
	// Post-processing for signals that apply to all tree-sitter languages.
	result.StringLiterals = collectStringLiterals(root, content, filePath, lang)
	result.ValueConstants = extractValueConstants(content, filePath)
	result.ConfigPatterns = extractConfigPatterns(content, filePath)
	if lang == "java" || lang == "c" || lang == "cpp" || lang == "python" || lang == "go" {
		result.ControlFlow = collectControlFlow(root, content, filePath, lang)
	}
	// ── S8-S10: Pointer validation, struct init, variable write (C/C++) ──
	if lang == "c" || lang == "cpp" {
		result.PointerValidations = collectPointerValidations(root, content, filePath, result.Functions)
		result.StructInits = collectStructInits(root, content, filePath, result.Types)
		result.VariableWrites = collectVariableWrites(root, content, filePath, result.Functions)
	}
	// ── S3 Declarations (F6 fix): per-function variable declarations with
	// array size + category. Drives prescreener safe-variant filtering and the
	// memory.uninitialized rule. C/C++ for now; other languages follow-up.
	if lang == "c" || lang == "cpp" {
		result.Declarations = collectDeclarations(root, content, filePath, lang)
	}
	// ── CFG (EPIC-011 FEATURE-002): per-function control-flow graphs ──
	result.CFGs = extractCFGs(root, content, filePath, lang)
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
			case "preproc_include":
				// F6 fix: C/C++ #include was never captured (Imports stayed empty
				// on the cgo path). Extract path + category for S5.
				if imp := extractCInclude(child, content, file); imp.Path != "" {
					result.Imports = append(result.Imports, imp)
				}
			case "function_definition":
				if fn := extractIdent(child, content, file, "function_declarator"); fn.Name != "" {
					fn.StartLine = child.StartPosition().Row + 1
					fn.EndLine = child.EndPosition().Row + 1
					result.Functions = append(result.Functions, fn)
					if body := findBody(child); body != nil {
						result.CallSites = append(result.CallSites, extractCallSites(body, content, fn.Name, file, nil)...)
					}
				}
			case "declaration":
				result.Variables = append(result.Variables, extractInitDecls(child, content, file)...)
			case "struct_specifier", "class_specifier", "union_specifier":
				if t := extractTypeName(child, content, file, kind); t.Name != "" {
					result.Types = append(result.Types, t)
				}
				// Walk class_body for methods (C++ class_specifier only)
				if kind == "class_specifier" {
					className := ""
					if len(result.Types) > 0 {
						className = result.Types[len(result.Types)-1].Name
					}
					currentVisibility := "private"
					for j := uint(0); j < child.ChildCount(); j++ {
						body := child.Child(j)
						if body == nil || body.Kind() != "field_declaration_list" {
							continue
						}
						for k := uint(0); k < body.ChildCount(); k++ {
							member := body.Child(k)
							if member == nil {
								continue
							}
							switch member.Kind() {
							case "access_specifier":
								if as := member.Child(0); as != nil {
									currentVisibility = as.Kind()
								}
							case "function_definition":
								fn := FunctionInfo{File: file, ClassName: className, Visibility: currentVisibility}
								fn.StartLine = member.StartPosition().Row + 1
								fn.EndLine = member.EndPosition().Row + 1
								for l := uint(0); l < member.ChildCount(); l++ {
									if md := member.Child(l); md != nil && md.Kind() == "static" {
										fn.IsStatic = true
									}
								}
								// Extract method name: function_definition -> function_declarator -> identifier
								for l := uint(0); l < member.ChildCount(); l++ {
									md := member.Child(l)
									if md == nil {
										continue
									}
									if md.Kind() == "function_declarator" {
											for m := uint(0); m < md.ChildCount(); m++ {
											fd := md.Child(m)
											if fd == nil { continue }
											}
										for m := uint(0); m < md.ChildCount(); m++ {
											fd := md.Child(m)
											if fd != nil && (fd.Kind() == "identifier" || fd.Kind() == "field_identifier") {
												fn.Name = safeText(content, fd.StartByte(), fd.EndByte())
											}
										}
									}
								}
								if fn.Name != "" {
									result.Functions = append(result.Functions, fn)
									if mbody := findBody(member); mbody != nil {
										result.CallSites = append(result.CallSites, extractCallSites(mbody, content, fn.Name, file, nil)...)
									}
								}
							}
						}
					}
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
					if body := findBody(child); body != nil {
						result.CallSites = append(result.CallSites, extractCallSites(body, content, fn.Name, file, nil)...)
					}
				}
			case "class_definition":
				className := ""
				if t := extractNamedChild(child, content, file, "identifier"); t.Name != "" {
					className = t.Name
					tis := TypeInfo{Name: t.Name, Kind: "class", File: file, StartLine: child.StartPosition().Row + 1}
					result.Types = append(result.Types, tis)
				}
				// Walk class body for methods explicitly (with ClassName)
				if body := findBody(child); body != nil {
					for j := uint(0); j < body.ChildCount(); j++ {
						bchild := body.Child(j)
						if bchild == nil || bchild.Kind() != "function_definition" {
							continue
						}
						if fn := extractNamedChild(bchild, content, file, "identifier"); fn.Name != "" {
							fn.ClassName = className
							fn.StartLine = bchild.StartPosition().Row + 1
							fn.EndLine = bchild.EndPosition().Row + 1
							result.Functions = append(result.Functions, fn)
							if mbody := findBody(bchild); mbody != nil {
								result.CallSites = append(result.CallSites, extractCallSites(mbody, content, fn.Name, file, nil)...)
							}
						}
					}
				}
			case "import_statement", "import_from_statement":
				// Python import extraction (S5 signal)
				for j := uint(0); j < child.ChildCount(); j++ {
					gc := child.Child(j)
					if gc == nil || gc.Kind() != "dotted_name" {
						continue
					}
					importPath := safeText(content, gc.StartByte(), gc.EndByte())
					if importPath == "" {
						continue
					}
					// For import_from_statement ("from X import Y"), only record the source module (first dotted_name)
					imp := Import{File: file, Line: child.StartPosition().Row + 1, Path: importPath, Kind: "module"}
					lower := strings.ToLower(importPath)
					switch {
					case strings.Contains(lower, "sql"):
						imp.Category = "db"
					case strings.Contains(lower, "subprocess"):
						imp.Category = "exec"
					case strings.Contains(lower, "os") || strings.Contains(lower, "sys"):
						imp.Category = "exec"
					case strings.Contains(lower, "http") || strings.Contains(lower, "io") || strings.Contains(lower, "urllib") || strings.Contains(lower, "requests"):
						imp.Category = "net"
					case strings.Contains(lower, "crypto") || strings.Contains(lower, "secrets"):
						imp.Category = "crypto"
					case strings.Contains(lower, "xml") || strings.Contains(lower, "json") || strings.Contains(lower, "pickle") || strings.Contains(lower, "shelve"):
						imp.Category = "web"
					default:
						imp.Category = "generic"
					}
					result.Imports = append(result.Imports, imp)
					if child.Kind() == "import_from_statement" {
						break
					}
				}
			}

		case "go":
			switch kind {
			case "function_declaration":
				if fn := extractNamedChild(child, content, file, "identifier"); fn.Name != "" {
					fn.StartLine = child.StartPosition().Row + 1
					fn.EndLine = child.EndPosition().Row + 1
					result.Functions = append(result.Functions, fn)
					if body := findBody(child); body != nil {
						result.CallSites = append(result.CallSites, extractCallSites(body, content, fn.Name, file, nil)...)
					}
				}
			case "method_declaration":
				fn := FunctionInfo{File: file, StartLine: child.StartPosition().Row + 1, EndLine: child.EndPosition().Row + 1}
				receiverSeen := false
				// Extract method name (field_identifier) + receiver type as ClassName
				for j := uint(0); j < child.ChildCount(); j++ {
					gc := child.Child(j)
					if gc == nil {
						continue
					}
					if gc.Kind() == "field_identifier" || gc.Kind() == "identifier" {
						if fn.Name == "" {
							fn.Name = safeText(content, gc.StartByte(), gc.EndByte())
						}
					}
					if !receiverSeen && gc.Kind() == "parameter_list" {
						receiverSeen = true
						// First parameter_list = receiver; extract its type
						for pi := uint(0); pi < gc.ChildCount(); pi++ {
							pd := gc.Child(pi)
							if pd != nil && pd.Kind() == "parameter_declaration" {
								for p := uint(0); p < pd.ChildCount(); p++ {
									pc := pd.Child(p)
									if pc == nil {
										continue
									}
									if pc.Kind() == "type_identifier" && fn.ClassName == "" {
										fn.ClassName = safeText(content, pc.StartByte(), pc.EndByte())
									}
									if pc.Kind() == "pointer_type" && fn.ClassName == "" {
										for pt := uint(0); pt < pc.ChildCount(); pt++ {
											ptc := pc.Child(pt)
											if ptc != nil && ptc.Kind() == "type_identifier" {
												fn.ClassName = safeText(content, ptc.StartByte(), ptc.EndByte())
											}
										}
									}
								}
								break
							}
						}
					}
				}
				if fn.Name != "" {
					result.Functions = append(result.Functions, fn)
					if body := findBody(child); body != nil {
						result.CallSites = append(result.CallSites, extractCallSites(body, content, fn.Name, file, nil)...)
					}
				}
			case "type_declaration":
				if t := extractGoType(child, content, file); t.Name != "" {
					result.Types = append(result.Types, t)
				}
			case "var_declaration":
				result.Variables = append(result.Variables, extractInitDecls(child, content, file)...)
			case "import_declaration":
				// Go import extraction
				for j := uint(0); j < child.NamedChildCount(); j++ {
					gc := child.NamedChild(j)
					if gc == nil {
						continue
					}
					if gc.Kind() == "import_spec_list" {
						for k := uint(0); k < gc.NamedChildCount(); k++ {
							spec := gc.NamedChild(k)
							if spec == nil || spec.Kind() != "import_spec" {
								continue
							}
						extractGoImport(spec, content, file, result)
						}
					} else if gc.Kind() == "import_spec" {
						extractGoImport(gc, content, file, result)
					}
				}
			}

		case "java":
			switch kind {
			case "class_declaration", "interface_declaration":
				kindName := "class"
				if kind == "interface_declaration" {
					kindName = "interface"
				}
					className := ""
					if t := extractNamedChild(child, content, file, "identifier"); t.Name != "" {
						className = t.Name
						result.Types = append(result.Types, TypeInfo{
							Name: t.Name, Kind: kindName, File: file, StartLine: child.StartPosition().Row + 1,
						})
					}
					// FEATURE-003: Build FileScope for Java type inference
					scope := NewFileScope(file)
					if parent := child.Parent(); parent != nil {
						for pi := uint(0); pi < parent.ChildCount(); pi++ {
							pc := parent.Child(pi)
							if pc == nil || pc.Kind() != "import_declaration" {
								continue
							}
							for si := uint(0); si < pc.ChildCount(); si++ {
								sc := pc.Child(si)
								if sc == nil || sc.Kind() != "scoped_identifier" {
									continue
								}
								importPath := safeText(content, sc.StartByte(), sc.EndByte())
								// Scope: skip wildcard imports (java.sql.* → can't short-resolve)
								if !strings.HasSuffix(importPath, ".*") {
									if idx := strings.LastIndex(importPath, "."); idx >= 0 {
										shortName := importPath[idx+1:]
										scope.Imports[shortName] = importPath
									}
								}
								// Result: populate S5 Import signals
								imp := Import{File: file, Line: pc.StartPosition().Row + 1, Path: importPath, Kind: "module"}
								lower := strings.ToLower(importPath)
								switch {
								case strings.Contains(lower, "sql"):
									imp.Category = "db"
								case strings.Contains(lower, "io") || strings.Contains(lower, "nio"):
									imp.Category = "io"
								case strings.Contains(lower, "net") || strings.Contains(lower, "http"):
									imp.Category = "net"
								case strings.Contains(lower, "crypto") || strings.Contains(lower, "security"):
									imp.Category = "crypto"
								case strings.Contains(lower, "xml") || strings.Contains(lower, "parse"):
									imp.Category = "web"
								case strings.Contains(lower, "servlet") || strings.Contains(lower, "json") || strings.Contains(lower, "jwt"):
									imp.Category = "web"
								default:
									imp.Category = "generic"
								}
								result.Imports = append(result.Imports, imp)
							}
						}
					}
					// FEATURE-003: Inject Lombok-generated log fields
					injectLombokLogFields(child, content, scope)
					// walk into class_body for methods
					for j := uint(0); j < child.ChildCount(); j++ {
						body := child.Child(j)
						if body == nil || body.Kind() != "class_body" {
							continue
						}
						// FEATURE-003: Extract field declarations
						for k := uint(0); k < body.ChildCount(); k++ {
							member := body.Child(k)
							if member == nil || member.Kind() != "field_declaration" {
								continue
							}
							fieldType := ""
							for fi := uint(0); fi < member.ChildCount(); fi++ {
								fc := member.Child(fi)
								if fc == nil {
									continue
								}
								if fc.Kind() == "type_identifier" && fieldType == "" {
									fieldType = safeText(content, fc.StartByte(), fc.EndByte())
								}
								if fc.Kind() == "scoped_identifier" && fieldType == "" {
									scopedText := safeText(content, fc.StartByte(), fc.EndByte())
									if dotIdx := strings.LastIndex(scopedText, "."); dotIdx >= 0 {
									fieldType = scopedText[dotIdx+1:]
									}
								}
								if fc.Kind() == "variable_declarator" && fieldType != "" {
									for di := uint(0); di < fc.ChildCount(); di++ {
									dc := fc.Child(di)
									if dc != nil && dc.Kind() == "identifier" {
									scope.Fields[safeText(content, dc.StartByte(), dc.EndByte())] = fieldType
									}
									}
								}
							}
						}
						for k := uint(0); k < body.ChildCount(); k++ {
							method := body.Child(k)
							if method == nil || method.Kind() != "method_declaration" {
								continue
							}
							fn := FunctionInfo{File: file, ClassName: className, StartLine: method.StartPosition().Row + 1, EndLine: method.EndPosition().Row + 1}
							for l := uint(0); l < method.ChildCount(); l++ {
								mchild := method.Child(l)
								if mchild == nil {
									continue
								}
								if mchild.Kind() == "identifier" && fn.Name == "" {
									fn.Name = safeText(content, mchild.StartByte(), mchild.EndByte())
								}
								if mchild.Kind() == "public" {
									fn.Visibility = "public"
								} else if mchild.Kind() == "protected" {
									fn.Visibility = "protected"
								} else if mchild.Kind() == "private" {
									fn.Visibility = "private"
								}
								if mchild.Kind() == "static" {
									fn.IsStatic = true
								}
							}
							if fn.Name != "" {
								result.Functions = append(result.Functions, fn)
								if mbody := findBody(method); mbody != nil {
									// FEATURE-003: Build local variable + parameter map
									localVars := buildJavaLocalVars(mbody, content)
									methodScope := NewFileScope(file)
									methodScope.Imports = scope.Imports
									methodScope.Fields = scope.Fields
									// Extract method parameter types
									for l := uint(0); l < method.ChildCount(); l++ {
										mchild := method.Child(l)
										if mchild == nil || mchild.Kind() != "formal_parameters" {
											continue
										}
										for pi := uint(0); pi < mchild.ChildCount(); pi++ {
											fp := mchild.Child(pi)
											if fp == nil || fp.Kind() != "formal_parameter" {
												continue
											}
											paramType, paramName := "", ""
											for fi := uint(0); fi < fp.ChildCount(); fi++ {
												fc := fp.Child(fi)
												if fc == nil {
													continue
												}
												if fc.Kind() == "type_identifier" && paramType == "" {
													paramType = safeText(content, fc.StartByte(), fc.EndByte())
												}
												if fc.Kind() == "identifier" && paramName == "" {
													paramName = safeText(content, fc.StartByte(), fc.EndByte())
												}
											}
											if paramType != "" && paramName != "" {
												methodScope.Variables[paramName] = paramType
											}
										}
									}
									for vn, vt := range localVars {
									methodScope.Variables[vn] = vt
									}
									result.CallSites = append(result.CallSites, extractCallSites(mbody, content, fn.Name, file, methodScope)...)
								}
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

// ── Library function call site detection ──

type libFuncEntry struct {
	name     string
	isSafe   bool
	category string
}

var knownLibFuncs = map[string]libFuncEntry{
	// String operations
	"strcpy":    {"strcpy", false, "string"},
	"strcpy_s":  {"strcpy_s", true, "string"},
	"strcat":    {"strcat", false, "string"},
	"strcat_s":  {"strcat_s", true, "string"},
	"sprintf":   {"sprintf", false, "string"},
	"sprintf_s": {"sprintf_s", true, "string"},
	"snprintf":  {"snprintf", false, "string"},
	"gets":      {"gets", false, "string"},
	"gets_s":    {"gets_s", true, "string"},

	// Memory operations
	"memcpy":    {"memcpy", false, "memory"},
	"memcpy_s":  {"memcpy_s", true, "memory"},
	"memmove":   {"memmove", false, "memory"},
	"memmove_s": {"memmove_s", true, "memory"},
	"malloc":    {"malloc", false, "memory"},
	"calloc":    {"calloc", false, "memory"},
	"realloc":   {"realloc", false, "memory"},
	"free":      {"free", false, "memory"},

	// I/O operations
	"fopen":     {"fopen", false, "io"},
	"fclose":    {"fclose", false, "io"},
	"open":      {"open", false, "io"},
	"close":     {"close", false, "io"},
	"tmpfile":   {"tmpfile", false, "io"},
	"socket":    {"socket", false, "io"},

	// Execution
	"system":  {"system", false, "exec"},
	"popen":   {"popen", false, "exec"},
	"getenv":  {"getenv", false, "exec"},

	// Sync
	"pthread_mutex_lock":   {"pthread_mutex_lock", false, "sync"},
	"pthread_mutex_unlock": {"pthread_mutex_unlock", false, "sync"},

	// Crypto
	"RAND_bytes":            {"RAND_bytes", false, "crypto"},
	"DES_set_key_unchecked": {"DES_set_key_unchecked", false, "crypto"},

	// Multi-language: logging
	"info":  {"info", false, "logging"},
	"warn":  {"warn", false, "logging"},
	"error": {"error", false, "logging"},
	"debug": {"debug", false, "logging"},
	"trace": {"trace", false, "logging"},

	// Multi-language: deserialization
	"readObject":  {"readObject", false, "deserialization"},
	"parseObject": {"parseObject", false, "deserialization"},

	// Multi-language: SQL
	"executeQuery":      {"executeQuery", false, "sql"},
	"executeUpdate":     {"executeUpdate", false, "sql"},
	"createNativeQuery": {"createNativeQuery", false, "sql"},

	// Multi-language: command execution
	"exec": {"exec", false, "exec"},

	// Multi-language: HTTP client
	"openConnection": {"openConnection", false, "http"},
	"getForObject":   {"getForObject", false, "http"},
	"postForEntity":  {"postForEntity", false, "http"},

	// Multi-language: XML
	"newDocumentBuilder": {"newDocumentBuilder", false, "xml"},
	"newSAXParser":       {"newSAXParser", false, "xml"},

	// Multi-language: SQL
	"createStatement": {"createStatement", false, "sql"},
	"getConnection":   {"getConnection", false, "credential"},

	// Java-specific: XXE/XML
	"parse":  {"parse", false, "xml"},

	// Go-specific: SQL injection sink
	"Sprintf": {"Sprintf", false, "string"},

	// Go-specific: command execution
	"Command": {"Command", false, "exec"},

		// Go-specific: format string (can construct SQL queries, XSS)
		"Fprintf": {"Fprintf", false, "string"},

		// Go-specific: SQL injection
		"Query": {"Query", false, "sql"},
		"Exec":  {"Exec", false, "sql"},

		// Go-specific: SSRF (http.Get)
		"Get": {"Get", false, "http"},

		// Go-specific: file/network I/O
		"ReadAll": {"ReadAll", false, "io"},

		// Go-specific: XML unmarshal (XXE)
		"Unmarshal": {"Unmarshal", false, "xml"},

		// Go-specific: command execution
		"Output":   {"Output", false, "exec"},
		"CombinedOutput": {"CombinedOutput", false, "exec"},

		// Go-specific: weak crypto
		"Sum": {"Sum", false, "crypto"},

	// Multi-language: file I/O
	"getCanonicalPath": {"getCanonicalPath", false, "file_io"},

	// Multi-language: HTTP/SSRF
	"openStream": {"openStream", false, "http"},

	// Multi-language: file upload
"transferTo": {"transferTo", false, "file_io"},

		// Multi-language: process
		"Runtime": {"Runtime", false, "exec"},

		// Python-specific: SQL injection sink (DB-API cursor.execute)
		"execute": {"execute", false, "sql"},

		// Python-specific: command execution
		"check_output": {"check_output", false, "exec"},
		"Popen":        {"Popen", false, "exec"},
		"eval":         {"eval", false, "exec"},

		// Python-specific: deserialization (pickle.loads)
		"loads": {"loads", false, "deserialization"},

		// Python-specific: weak crypto
		"md5":       {"md5", false, "crypto"},
		"randint":   {"randint", false, "weak_random"},
		"token_hex": {"token_hex", true, "crypto"},

		// Python-specific: AST analysis
		"literal_eval": {"literal_eval", true, "safe_eval"},
	}

//  walks a function body node and extracts all call_expression
// nodes that reference known library functions.
func extractCallSites(body *treesitter.Node, content []byte, callerName, file string, scope *FileScope) []CallSite {
	var sites []CallSite
	collectCallExprs(body, content, callerName, file, &sites, scope)
	return sites
}

// collectCallExprs recursively walks the AST and collects call_expressions.
func collectCallExprs(node *treesitter.Node, content []byte, callerName, file string, sites *[]CallSite, scope *FileScope) {
	for i := uint(0); i < node.ChildCount(); i++ {
		child := node.Child(i)
		if child == nil {
			continue
		}
		if child.Kind() == "call_expression" || child.Kind() == "method_invocation" || child.Kind() == "call" {
			if cs := parseCallExpr(child, content, callerName, file, scope); cs != nil {
				*sites = append(*sites, *cs)
			}
			// Don't recurse into call_expression children — argument_list
			// may contain nested call_expressions but we only want the top-level call.
			continue
		}
		collectCallExprs(child, content, callerName, file, sites, scope)
	}
}

// parseCallExpr extracts a single call_expression tree-sitter node into a CallSite.
func parseCallExpr(node *treesitter.Node, content []byte, callerName, file string, scope *FileScope) *CallSite {
	ck := node.Kind()

	var callee string
	var argNode *treesitter.Node
	var receiverExpr string

	if ck == "method_invocation" {
		// Java method invocation: flat structure
		// obj.method() -> child(0)=identifier(receiver), child(1)=".", child(2)=identifier(method)
		// method()     -> child(0)=identifier(method)
		for i := uint(0); i < node.ChildCount(); i++ {
			gc := node.Child(i)
			if gc == nil {
				continue
			}
			if gc.Kind() == "argument_list" {
				argNode = gc
			}
		}
		if node.ChildCount() >= 4 && node.Child(1) != nil && node.Child(1).Kind() == "." {
			// obj.method() -- child(0)=receiver, child(2)=method
			if c0 := node.Child(0); c0 != nil && c0.Kind() == "identifier" {
				receiverExpr = safeText(content, c0.StartByte(), c0.EndByte())
			}
			if c2 := node.Child(2); c2 != nil && (c2.Kind() == "identifier" || c2.Kind() == "field_identifier") {
				callee = safeText(content, c2.StartByte(), c2.EndByte())
			}
		} else {
			// Simple method() call -- child(0)=method name
			for i := uint(0); i < node.ChildCount(); i++ {
				gc := node.Child(i)
				if gc == nil {
					continue
				}
				if (gc.Kind() == "identifier" || gc.Kind() == "field_identifier") && callee == "" {
					callee = safeText(content, gc.StartByte(), gc.EndByte())
				}
			}
		}
	} else {
		fnNode := node.Child(0)
		if fnNode == nil {
			return nil
		}
		callee = safeText(content, fnNode.StartByte(), fnNode.EndByte())
		if callee == "" {
			return nil
		}
		// Handle field_expression for C++/Go: obj->method() -> callee="method", receiverExpr="obj"
		if fnNode.Kind() == "field_expression" {
			for j := uint(0); j < fnNode.ChildCount(); j++ {
				fc := fnNode.Child(j)
				if fc == nil {
					continue
				}
				if fc.Kind() == "field_identifier" {
					callee = safeText(content, fc.StartByte(), fc.EndByte())
				} else if receiverExpr == "" {
					receiverExpr = safeText(content, fc.StartByte(), fc.EndByte())
				}
			}
		} else if fnNode.Kind() == "attribute" {
			// Python: logger.info() -> callee="info", receiver="logger"
			// Reset callee since full text (e.g. "logging.info") is not a func name
			callee = ""
			for j := uint(0); j < fnNode.ChildCount(); j++ {
				fc := fnNode.Child(j)
				if fc == nil || fc.Kind() != "identifier" {
					continue
				}
				if receiverExpr == "" {
					receiverExpr = safeText(content, fc.StartByte(), fc.EndByte())
				} else {
					callee = safeText(content, fc.StartByte(), fc.EndByte())
				}
			}
		} else if fnNode.Kind() == "selector_expression" {
			// Go: exec.Command() -> callee="Command", receiver="exec"
			callee = ""
			for j := uint(0); j < fnNode.ChildCount(); j++ {
				fc := fnNode.Child(j)
				if fc == nil || (fc.Kind() != "identifier" && fc.Kind() != "field_identifier") {
					continue
				}
				if receiverExpr == "" {
					receiverExpr = safeText(content, fc.StartByte(), fc.EndByte())
				} else {
					callee = safeText(content, fc.StartByte(), fc.EndByte())
				}
			}
		}
		argNode = node.Child(1)
	}

	entry, ok := knownLibFuncs[callee]
	if !ok {
		return nil
	}

	// Extract arguments from the argument_list child.
	// Use NamedChild to skip anonymous tokens (commas, parentheses).
	var args []string
	if argNode != nil && argNode.Kind() == "argument_list" {
		for j := uint(0); j < argNode.NamedChildCount(); j++ {
			sub := argNode.NamedChild(j)
			if sub == nil {
				continue
			}
			argText := safeText(content, sub.StartByte(), sub.EndByte())
			if len(argText) > 128 {
				argText = argText[:128] + "..."
			}
			args = append(args, argText)
		}
	}

	// Resolve ReceiverType via scope if available (FEATURE-003)
	if receiverExpr != "" && scope != nil {
		receiverType := resolveReceiverType(receiverExpr, scope)
		if receiverType != "" {
			return &CallSite{
				CallerFunction: callerName,
				CalleeName:     callee,
				File:           file,
				Line:           node.StartPosition().Row + 1,
				Arguments:      args,
				IsSafeVariant:  entry.isSafe,
				Category:       entry.category,
				ReceiverExpr:   receiverExpr,
				ReceiverType:   receiverType,
			}
		}
	}
	return &CallSite{
		CallerFunction: callerName,
		CalleeName:     callee,
		File:           file,
		Line:           node.StartPosition().Row + 1,
		Arguments:      args,
		IsSafeVariant:  entry.isSafe,
		Category:       entry.category,
		ReceiverExpr:   receiverExpr,
	}
}

// findBody locates the compound_statement body of a function_definition node.
func findBody(node *treesitter.Node) *treesitter.Node {
	for i := uint(0); i < node.ChildCount(); i++ {
		child := node.Child(i)
		if child == nil {
			continue
		}
		if child.Kind() == "compound_statement" || child.Kind() == "body" || child.Kind() == "block" {
			return child
		}
	}
	return nil
}


// ── FEATURE-003: Lombok log field injection ──────────────────

var lombokLogAnnotations = map[string]string{
	"Slf4j":      "org.slf4j.Logger",
	"Log4j2":     "org.apache.logging.log4j.Logger",
	"Log":        "java.util.logging.Logger",
	"javaLog":    "java.util.logging.Logger",
	"CommonsLog": "org.apache.commons.logging.Log",
	"Flogger":    "com.google.common.flogger.FluentLogger",
}


// extractGoImport extracts an import path from a Go import_spec node.
func extractGoImport(spec *treesitter.Node, content []byte, file string, result *ParseResult) {
	for k := uint(0); k < spec.NamedChildCount(); k++ {
		pathNode := spec.NamedChild(k)
		if pathNode == nil || pathNode.Kind() != "interpreted_string_literal" {
			continue
		}
		rawPath := safeText(content, pathNode.StartByte(), pathNode.EndByte())
		// Strip surrounding quotes
		if len(rawPath) >= 2 {
			rawPath = rawPath[1 : len(rawPath)-1]
		}
		if rawPath == "" {
			continue
		}
		imp := Import{File: file, Line: spec.StartPosition().Row + 1, Path: rawPath, Kind: "module"}
		lower := strings.ToLower(rawPath)
		switch {
		case strings.Contains(lower, "sql"):
			imp.Category = "db"
		case strings.Contains(lower, "exec"):
			imp.Category = "exec"
		case strings.Contains(lower, "http") || strings.Contains(lower, "io"):
			imp.Category = "net"
		case strings.Contains(lower, "crypto") || strings.Contains(lower, "md5") || strings.Contains(lower, "sha"):
			imp.Category = "crypto"
		case strings.Contains(lower, "xml") || strings.Contains(lower, "json"):
			imp.Category = "web"
		case strings.Contains(lower, "os"):
			imp.Category = "exec"
		default:
			if strings.Contains(lower, "encoding") || strings.Contains(lower, "path") {
				imp.Category = "net"
			} else {
				imp.Category = "generic"
			}
		}
		result.Imports = append(result.Imports, imp)
	}
}
func injectLombokLogFields(classDecl *treesitter.Node, content []byte, scope *FileScope) {
	for i := uint(0); i < classDecl.ChildCount(); i++ {
		c := classDecl.Child(i)
		if c == nil || c.Kind() != "modifiers" {
			continue
		}
		for j := uint(0); j < c.ChildCount(); j++ {
			ann := c.Child(j)
			if ann == nil || ann.Kind() != "marker_annotation" {
				continue
			}
			for k := uint(0); k < ann.ChildCount(); k++ {
				id := ann.Child(k)
				if id == nil || id.Kind() != "identifier" {
					continue
				}
				annName := safeText(content, id.StartByte(), id.EndByte())
				if loggerType, ok := lombokLogAnnotations[annName]; ok {
					scope.Fields["log"] = loggerType
					return
				}
			}
		}
	}
}

// ── Signal extraction helpers ──────────────────────────────────

// collectStringLiterals walks the AST and collects string literal nodes.
// Handles different node kinds per language:
//   C/C++/Java: "string_literal"
//   Python:     "string" (contains "string_content" children)
//   Go:         "interpreted_string_literal" or "raw_string_literal"
func collectStringLiterals(root *treesitter.Node, content []byte, file, lang string) []StringLiteral {
	var literals []StringLiteral
	var walk func(*treesitter.Node)
	walk = func(n *treesitter.Node) {
		for i := uint(0); i < n.ChildCount(); i++ {
			c := n.Child(i)
			if c == nil {
				continue
			}
			kind := c.Kind()
			isString := kind == "string_literal" || kind == "interpreted_string_literal" ||
				kind == "raw_string_literal" || kind == "string"
			if isString {
				val := safeText(content, c.StartByte(), c.EndByte())
				// Skip empty strings, single chars, and whitespace-only
				cleaned := strings.Trim(val, "\"'`")
				if len(cleaned) < 4 {
					continue
				}
				literals = append(literals, StringLiteral{
					File:    file,
					Line:    c.StartPosition().Row + 1,
					Value:   truncate(cleaned, 256),
					Length:  len(cleaned),
					Context: "global",
					Kinds:   inferStringKind(cleaned),
				})
				continue
			}
			if c.ChildCount() > 0 {
				walk(c)
			}
		}
	}
	walk(root)
	return literals
}

// collectControlFlow walks the AST for if_statement nodes (Java/C/C++).
func collectControlFlow(root *treesitter.Node, content []byte, file, lang string) []ControlFlowSignal {
	var signals []ControlFlowSignal
	var walk func(*treesitter.Node)
	walk = func(n *treesitter.Node) {
		for i := uint(0); i < n.ChildCount(); i++ {
			c := n.Child(i)
			if c == nil {
				continue
			}
			if c.Kind() == "if_statement" {
				// Extract condition from first child
				cond := ""
				for j := uint(0); j < c.ChildCount(); j++ {
					gc := c.Child(j)
					if gc == nil {
						continue
					}
					if gc.Kind() == "parenthesized_expression" || gc.Kind() == "condition" {
						cond = strings.TrimSpace(safeText(content, gc.StartByte(), gc.EndByte()))
						if len(cond) > 128 {
							cond = cond[:128] + "..."
						}
						break
					}
				}
				// Check if it looks like an error check or guard
				kind := "if_guard"
				cat := "generic"
				condLower := strings.ToLower(cond)
				if strings.Contains(condLower, "null") || strings.Contains(condLower, "nil") {
					kind = "error_check"
					cat = "error"
				} else if strings.Contains(condLower, "error") || strings.Contains(condLower, "err") {
					kind = "error_check"
					cat = "error"
				} else if strings.Contains(condLower, "auth") || strings.Contains(condLower, "login") || strings.Contains(condLower, "role") {
					cat = "auth"
				}
				signals = append(signals, ControlFlowSignal{
					File:      file,
					Line:      c.StartPosition().Row + 1,
					Kind:      kind,
					Condition: cond,
					Category:  cat,
				})
				continue
			}
			if c.ChildCount() > 0 {
				walk(c)
			}
		}
	}
	walk(root)
	return signals
}

func safeText(content []byte, start, end uint) string {
	if int(start) >= len(content) || int(end) > len(content) || start > end {
		return ""
	}
	return string(content[start:end])
}

// ── FEATURE-003: Java local type inference ────────────────────

// buildJavaLocalVars extracts local variable declarations from a method body.
func buildJavaLocalVars(body *treesitter.Node, content []byte) map[string]string {
	vars := make(map[string]string)
	var walk func(*treesitter.Node)
	walk = func(n *treesitter.Node) {
		for i := uint(0); i < n.ChildCount(); i++ {
			c := n.Child(i)
			if c == nil {
				continue
			}
			if c.Kind() == "local_variable_declaration" {
				varType := ""
				for j := uint(0); j < c.ChildCount(); j++ {
					cc := c.Child(j)
					if cc == nil {
						continue
					}
					if (cc.Kind() == "type_identifier" || cc.Kind() == "scoped_type_identifier") && varType == "" {
						t := safeText(content, cc.StartByte(), cc.EndByte())
						if dotIdx := strings.LastIndex(t, "."); dotIdx >= 0 {
							varType = t[dotIdx+1:]
						} else {
							varType = t
						}
					}
					if cc.Kind() == "variable_declarator" && varType != "" {
						for k := uint(0); k < cc.ChildCount(); k++ {
							dc := cc.Child(k)
							if dc != nil && dc.Kind() == "identifier" {
								vars[safeText(content, dc.StartByte(), dc.EndByte())] = varType
							}
						}
					}
				}
			}
			// Handle try-with-resources variables
			if c.Kind() == "resource_specification" {
				for ri := uint(0); ri < c.ChildCount(); ri++ {
					res := c.Child(ri)
					if res == nil || res.Kind() != "resource" {
						continue
					}
					varType := ""
					varName := ""
					for rii := uint(0); rii < res.ChildCount(); rii++ {
						rc := res.Child(rii)
						if rc == nil {
							continue
						}
						if (rc.Kind() == "type_identifier" || rc.Kind() == "scoped_type_identifier") && varType == "" {
							t := safeText(content, rc.StartByte(), rc.EndByte())
							if dotIdx := strings.LastIndex(t, "."); dotIdx >= 0 {
								varType = t[dotIdx+1:]
							} else {
								varType = t
							}
						}
						if rc.Kind() == "variable_declarator" && varType != "" {
							for k := uint(0); k < rc.ChildCount(); k++ {
								dc := rc.Child(k)
								if dc != nil && dc.Kind() == "identifier" {
									varName = safeText(content, dc.StartByte(), dc.EndByte())
								}
							}
						}
					}
					if varType != "" && varName != "" {
						vars[varName] = varType
					}
				}
			}
			if c.ChildCount() > 0 {
				walk(c)
			}
		}
	}
	walk(body)
	return vars
}

// extractFirstIdentifier returns the first identifier in a dotted expression.
func extractFirstIdentifier(expr string) string {
	if idx := strings.IndexAny(expr, "."); idx >= 0 {
		return expr[:idx]
	}
	return expr
}

// resolveToFQN resolves a short type name to a fully qualified name using imports.
func resolveToFQN(typeName string, imports map[string]string) string {
	if fqn, ok := imports[typeName]; ok {
		return fqn
	}
	return typeName
}

// resolveReceiverType resolves a receiver expression to a fully qualified type name.
func resolveReceiverType(expr string, scope *FileScope) string {
	ident := extractFirstIdentifier(expr)

	// 1) Local variables first (shadow fields)
	if t, ok := scope.Variables[ident]; ok {
		return resolveToFQN(t, scope.Imports)
	}
	// 2) Fields second
	if t, ok := scope.Fields[ident]; ok {
		return resolveToFQN(t, scope.Imports)
	}
	// 3) this.xxx -> field
	if ident == "this" {
		parts := strings.SplitN(expr, ".", 2)
		if len(parts) == 2 {
			if t, ok := scope.Fields[parts[1]]; ok {
				return resolveToFQN(t, scope.Imports)
			}
		}
	}
	return ""
}

// ── S8: PointerValidation collector (TreeSitter C/C++) ──

func collectPointerValidations(root *treesitter.Node, content []byte, file string, functions []FunctionInfo) []PointerValidation {
	var results []PointerValidation
	if len(functions) == 0 {
		return results
	}
	lines := strings.Split(string(content), "\n")

	walkForPointerDerefs(root, content, func(fnStart, fnEnd uint, fnName string) {
		nullChecks := make(map[string]uint)
		derefs := make(map[string]uint)

		for i := fnStart; i < fnEnd && int(i) < len(lines); i++ {
			line := lines[i]
			lineNo := i + 1
			if strings.Contains(line, "->") {
				parts := strings.SplitN(line, "->", 2)
				before := parts[0]
				fields := strings.Fields(before)
				if len(fields) > 0 {
					varName := strings.Trim(fields[len(fields)-1], " \t(),.;:")
					if varName != "" && varName != "if" && varName != "while" && varName != "return" {
						derefs[varName] = lineNo
					}
				}
			}
			if strings.Contains(line, "if") && (strings.Contains(line, "NULL") || strings.Contains(line, "!(")) {
				for v := range derefs {
					if strings.Contains(line, "!"+v) || strings.Contains(line, v+" == NULL") || strings.Contains(line, v+" != NULL") {
						nullChecks[v] = lineNo
					}
				}
			}
		}
		for v, derefLine := range derefs {
			checkLine, hasCheck := nullChecks[v]
			results = append(results, PointerValidation{
				File:           file,
				Line:           derefLine,
				Function:       fnName,
				Variable:       v,
				IsPointerParam: true,
				HasNullCheck:   hasCheck,
				IsDereferenced: true,
				NullCheckLine:  checkLine,
				DerefLine:      derefLine,
				Category:       "param_check",
			})
		}
	})
	return results
}

func walkForPointerDerefs(node *treesitter.Node, content []byte, visitor func(fnStart, fnEnd uint, fnName string)) {
	for i := uint(0); i < node.ChildCount(); i++ {
		child := node.Child(i)
		if child == nil {
			continue
		}
		if child.Kind() == "function_definition" {
			fnName := extractFunctionName(child, content)
			if fnName != "" {
				body := child.ChildByFieldName("body")
				if body != nil {
					visitor(body.StartPosition().Row+1, body.EndPosition().Row+1, fnName)
				}
			}
		}
		walkForPointerDerefs(child, content, visitor)
	}
}

func extractFunctionName(fnNode *treesitter.Node, content []byte) string {
	decl := fnNode.ChildByFieldName("declarator")
	if decl == nil {
		return ""
	}
	for i := uint(0); i < decl.ChildCount(); i++ {
		c := decl.Child(i)
		if c != nil && (c.Kind() == "identifier" || c.Kind() == "field_identifier") {
			return string(content[c.StartByte():c.EndByte()])
		}
		if c != nil && c.Kind() == "function_declarator" {
			for j := uint(0); j < c.ChildCount(); j++ {
				cc := c.Child(j)
				if cc != nil && (cc.Kind() == "identifier" || cc.Kind() == "field_identifier") {
					return string(content[cc.StartByte():cc.EndByte()])
				}
			}
		}
	}
	return ""
}

// ── S9: StructInit collector (TreeSitter C/C++) ──

func collectStructInits(root *treesitter.Node, content []byte, file string, types []TypeInfo) []StructInit {
	var results []StructInit
	lines := strings.Split(string(content), "\n")
	structFields := collectStructFields(root, content)

	for lineIdx, line := range lines {
		trimmed := strings.TrimSpace(line)
		lineNo := uint(lineIdx + 1)
		for st, fields := range structFields {
			if strings.Contains(trimmed, "malloc") && strings.Contains(trimmed, st) {
				results = append(results, StructInit{
					File:                file,
					Line:                lineNo,
					StructType:          st,
					TotalFields:         len(fields),
					UninitializedFields: fields,
					IsHeapAlloc:         true,
					Category:            "partial_init",
				})
			}
			if strings.Contains(trimmed, st) && strings.HasSuffix(strings.TrimRight(trimmed, " "), ";") &&
				!strings.Contains(trimmed, "=") && !strings.Contains(trimmed, "(") &&
				!strings.Contains(trimmed, "typedef") {
				parts := strings.Fields(trimmed)
				for pi, p := range parts {
					if p == st && pi+1 < len(parts) {
						varName := strings.TrimSuffix(parts[pi+1], ";")
						varName = strings.TrimRight(varName, "[]*")
						if varName != "" && varName != "*" {
							results = append(results, StructInit{
								File:                file,
								Line:                lineNo,
								StructType:          st,
								Variable:            varName,
								TotalFields:         len(fields),
								UninitializedFields: fields,
								IsStackAlloc:        true,
								Category:            "no_init",
							})
						}
					}
				}
			}
		}
	}
	return results
}

func collectStructFields(node *treesitter.Node, content []byte) map[string][]string {
	result := make(map[string][]string)
	var walk func(n *treesitter.Node)
	walk = func(n *treesitter.Node) {
		if n.Kind() == "struct_specifier" || n.Kind() == "class_specifier" || n.Kind() == "type_definition" {
			var name string
			for i := uint(0); i < n.ChildCount(); i++ {
				c := n.Child(i)
				if c != nil && c.Kind() == "type_identifier" {
					name = string(content[c.StartByte():c.EndByte()])
					break
				}
				// type_definition wraps struct_specifier — look deeper
				if c != nil && c.Kind() == "struct_specifier" {
					for j := uint(0); j < c.ChildCount(); j++ {
						cc := c.Child(j)
						if cc != nil && cc.Kind() == "type_identifier" {
							name = string(content[cc.StartByte():cc.EndByte()])
							break
						}
					}
				}
			}
			if name != "" {
				// For type_definition, body might be on the inner struct_specifier
				body := n.ChildByFieldName("body")
				if body == nil && n.Kind() == "type_definition" {
					for i := uint(0); i < n.ChildCount(); i++ {
						c := n.Child(i)
						if c != nil && c.Kind() == "struct_specifier" {
							body = c.ChildByFieldName("body")
							break
						}
					}
				}
				if body != nil {
					for i := uint(0); i < body.ChildCount(); i++ {
						fd := body.Child(i)
						if fd != nil && fd.Kind() == "field_declaration" {
							for j := uint(0); j < fd.ChildCount(); j++ {
								decl := fd.Child(j)
								if decl != nil {
									dk := decl.Kind()
									if dk == "field_identifier" || dk == "identifier" {
										result[name] = append(result[name], string(content[decl.StartByte():decl.EndByte()]))
									}
								}
							}
						}
					}
				}
			}
		}
		for i := uint(0); i < n.ChildCount(); i++ {
			c := n.Child(i)
			if c != nil {
				walk(c)
			}
		}
	}
	walk(node)
	return result
}

// ── S10: VariableWrite collector (TreeSitter C/C++) ──

func collectVariableWrites(root *treesitter.Node, content []byte, file string, functions []FunctionInfo) []VariableWrite {
	var results []VariableWrite
	lines := strings.Split(string(content), "\n")
	cTypes := map[string]bool{
		"int": true, "char": true, "float": true, "double": true, "long": true,
		"short": true, "unsigned": true, "size_t": true, "ssize_t": true,
		"void": true, "bool": true, "uint8_t": true, "uint16_t": true,
		"uint32_t": true, "uint64_t": true, "int8_t": true, "int16_t": true,
		"int32_t": true, "int64_t": true, "FILE": true,
	}

	for _, fn := range functions {
		if fn.StartLine == 0 || fn.EndLine == 0 {
			continue
		}
		startIdx := int(fn.StartLine) - 1
		endIdx := minInt(int(fn.EndLine), len(lines))

		type varState struct {
			declLine       uint
			typeName       string
			firstReadLine  uint
			firstWriteLine uint
			hasInitializer bool
		}
		tracked := make(map[string]*varState)

		for i := startIdx; i < endIdx; i++ {
			line := lines[i]
			trimmed := strings.TrimSpace(line)
			if strings.HasPrefix(trimmed, "#") || strings.HasPrefix(trimmed, "//") || trimmed == "" {
				continue
			}
			if strings.Contains(trimmed, "(") && strings.Contains(trimmed, ")") && !strings.Contains(trimmed, "=") {
				continue
			}
			for ct := range cTypes {
				if strings.HasPrefix(trimmed, ct+" ") || strings.HasPrefix(trimmed, ct+"\t") {
					fields := strings.Fields(trimmed)
					for fi := 1; fi < len(fields); fi++ {
						v := strings.Trim(fields[fi], ";,*[]()")
						if v != "" && v != "const" && v != "volatile" && len(v) > 1 {
							hasInit := strings.Contains(trimmed, "=")
							tracked[v] = &varState{
								declLine:       uint(i + 1),
								typeName:       ct,
								hasInitializer: hasInit,
							}
							if hasInit {
								tracked[v].firstWriteLine = uint(i + 1)
							}
						}
					}
				}
			}
		}

		for i := startIdx; i < endIdx; i++ {
			line := lines[i]
			lineNo := uint(i + 1)
			for varName, vs := range tracked {
				if !strings.Contains(line, varName) || lineNo <= vs.declLine {
					continue
				}
				isWrite := strings.Contains(line, varName+" =") || strings.Contains(line, varName+"=") ||
					strings.Contains(line, "->"+varName) || strings.Contains(line, varName+"->") ||
					strings.Contains(line, "*"+varName+" =") || strings.Contains(line, "&"+varName)
				if isWrite && vs.firstWriteLine == 0 {
					vs.firstWriteLine = lineNo
				}
				if !isWrite && vs.firstReadLine == 0 &&
					!strings.Contains(line, "char "+varName) && !strings.Contains(line, "int "+varName) {
					vs.firstReadLine = lineNo
				}
			}
		}

		for varName, vs := range tracked {
			cat := "declared_only"
			if vs.firstReadLine > 0 && vs.firstWriteLine == 0 {
				cat = "read_before_write"
			} else if vs.firstWriteLine > 0 {
				cat = "written"
			}
			results = append(results, VariableWrite{
				File:           file,
				Line:           vs.declLine,
				Function:       fn.Name,
				Variable:       varName,
				TypeName:       vs.typeName,
				DeclLine:       vs.declLine,
				FirstReadLine:  vs.firstReadLine,
				FirstWriteLine: vs.firstWriteLine,
				IsInitialized:  vs.hasInitializer,
				Category:       cat,
			})
		}
	}
	return results
}

func minInt(a, b int) int {
	if a < b {
		return a
	}
	return b
}
