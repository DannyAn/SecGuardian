# FEATURE-001: Fix Class Method Extraction Gaps — 实施计划

## 架构

本 Feature 不修改现有数据结构，只修改 parser_ts.go 和 parser_re.go 的函数体逻辑。所有修复都遵循 ADR-001 的"统一 `findBody`+`extractCallSites`"模式。

## 文件修改清单

| 文件 | 改动量 | 类型 |
|------|--------|------|
| `internal/parser/parser_ts.go` | ~30 行新增 | C++ class_body walking + Python/Go call site 提取 |
| `internal/parser/parser_re.go` | ~6 行修改 | 移除语言过滤限制 |
| `internal/parser/parser_ts_test.go` | ~80 行新增 | 4 个测试函数 |

## 任务列表

### TASK-001: C++ class_body walking

**Files**: `parser_ts.go` walkTopLevel C/C++ handler

**改动**:
```go
// 在 case "c", "cpp": 的 switch 中增加
case "class_specifier":
    // 保留现有的 type name 提取
    if t := extractTypeName(child, content, file, kind); t.Name != "" {
        result.Types = append(result.Types, t)
    }
    // 新增：walk class_body → method_declaration
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
            fn := FunctionInfo{File: file}
            fn.StartLine = method.StartPosition().Row + 1
            fn.EndLine = method.EndPosition().Row + 1
            // 提取方法名：从 function_declarator → identifier
            for l := uint(0); l < method.ChildCount(); l++ {
                md := method.Child(l)
                if md == nil { continue }
                if md.Kind() == "identifier" {
                    fn.Name = safeText(content, md.StartByte(), md.EndByte())
                }
                if md.Kind() == "function_declarator" {
                    for m := uint(0); m < md.ChildCount(); m++ {
                        fd := md.Child(m)
                        if fd != nil && fd.Kind() == "identifier" {
                            fn.Name = safeText(content, fd.StartByte(), fd.EndByte())
                        }
                    }
                }
            }
            if fn.Name != "" {
                result.Functions = append(result.Functions, fn)
                if mbody := findBody(method); mbody != nil {
                    result.CallSites = append(result.CallSites,
                        extractCallSites(mbody, content, fn.Name, file)...)
                }
            }
        }
    }
```

**验证**:
```bash
cd /Users/kongan/workbench/github/SecGuardian/internal
CGO_ENABLED=1 go test ./parser/... -run TestParseFile_TS_CPPMethodExtraction -v
```

### TASK-002: Python call site 提取

**Files**: `parser_ts.go` walkTopLevel Python handler

**改动**: 在 Python `function_definition` case 中追加 `findBody`+`extractCallSites`:
```go
case "function_definition":
    if fn := extractNamedChild(child, content, file, "identifier"); fn.Name != "" {
        fn.StartLine = child.StartPosition().Row + 1
        fn.EndLine = child.EndPosition().Row + 1
        result.Functions = append(result.Functions, fn)
        // +++ 追加 +++
        if body := findBody(child); body != nil {
            result.CallSites = append(result.CallSites,
                extractCallSites(body, content, fn.Name, file)...)
        }
    }
```

### TASK-003: Go call site 提取

**Files**: `parser_ts.go` walkTopLevel Go handler

**改动**: 在 Go `function_declaration` 和 `method_declaration` case 中各追加 `findBody`+`extractCallSites`。模式与 TASK-002 一致。

### TASK-004: parser_re.go 过滤条件扩展

**Files**: `parser_re.go` line 224

**改动**:
```go
// Before:
if lang == "c" || lang == "cpp" {
// After:
if lang == "c" || lang == "cpp" || lang == "java" || lang == "go" || lang == "python" {
```

### TASK-005: 单元测试

**Files**: `parser_ts_test.go`

测试场景：
1. `TestParseFile_TS_CPPMethodExtraction` — 临时 .cpp 含 class 和方法
2. `TestParseFile_TS_PythonMethodCallSites` — 临时 .py 含 class 和方法
3. `TestParseFile_TS_GoMethodCallSites` — 临时 .go 含 method
4. `TestParseFile_TS_GoFunctionCallSites` — 临时 .go 含 function

## 实施顺序

```
TASK-001 ─┐
TASK-002 ─┼──→ TASK-005（测试同时验证全部 4 个修改）
TASK-003 ─┤
TASK-004 ─┘
```

TASK-001~004 无依赖，可并行修改。TASK-005 在所有修改后进行。

## 验证检查清单

- [ ] `go test ./parser/... -run TestParseFile_TS_CPPMethodExtraction` PASS
- [ ] `go test ./parser/... -run TestParseFile_TS_PythonMethodCallSites` PASS
- [ ] `go test ./parser/... -run TestParseFile_TS_GoMethodCallSites` PASS
- [ ] `go test ./parser/... -run TestParseFile_TS_GoFunctionCallSites` PASS
- [ ] `go test ./...` 结果与之前一致（5 个已知失败）
- [ ] `bash ../scripts/dev-verify.sh --quick` PASS
