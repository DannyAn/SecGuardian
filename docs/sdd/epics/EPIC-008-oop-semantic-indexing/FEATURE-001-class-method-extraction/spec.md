# FEATURE-001: Fix Class Method Extraction Gaps

> **父 Epic**: EPIC-008 OOP-Aware Semantic Indexing
> **状态**: 📋 Spec 制定中
> **目标版本**: v0.18.0

## 问题陈述

当前 `internal/parser/parser_ts.go` 的 `walkTopLevel` 函数对 4 种 OOP 语言的类方法提取存在系统性缺陷。如下图所示，只有 Java 正确提取了类方法的调用点。

```go
// walkTopLevel 各语言 handler 的 call site 提取状态（简要对比）
// Java:   class_declaration → class_body → method_declaration → findBody → extractCallSites  ✅
// C++:    class_specifier → 只提取 type name，不进入 class_body                                ❌
// Python: function_definition → 只提取 name，不调用 findBody+extractCallSites                    ❌
// Go:     method_declaration → 只提取 name，不调用 findBody+extractCallSites                    ❌
// Go:     function_declaration → 只提取 name，不调用 findBody+extractCallSites                  ❌
```

### 1.1 C++ `class_specifier` 未行走

当前代码（`parser_ts.go:77-80`）：
```go
case "struct_specifier", "class_specifier", "union_specifier":
    if t := extractTypeName(child, content, file, kind); t.Name != "" {
        result.Types = append(result.Types, t)
    }
```
只提取类型名，不做 `class_specifier` → `class_body` → `method_declaration` 行走。

### 1.2 Python 函数不提取调用点

当前代码（`parser_ts.go:93-98`）：
```go
case "function_definition":
    if fn := extractNamedChild(child, content, file, "identifier"); fn.Name != "" {
        fn.StartLine = child.StartPosition().Row + 1
        fn.EndLine = child.EndPosition().Row + 1
        result.Functions = append(result.Functions, fn)
    }
```
只注册函数名，从未调用 `findBody`/`extractCallSites`。

### 1.3 Go 函数/方法不提取调用点

当前代码（`parser_ts.go:110-127`）：
```go
case "function_declaration":
    // 只提取 name
case "method_declaration":
    // 只提取 name
```
都不调用 `findBody`/`extractCallSites`。

### 1.4 parser_re.go 未覆盖 Java/Go/Python

当前代码（`parser_re.go:224`）：
```go
if lang == "c" || lang == "cpp" {
    // 调用点提取
}
```
regex fallback 只对 C/C++ 做调用点提取。

## 需求

| 编号 | 需求 | 优先级 | 验证方法 |
|------|------|--------|----------|
| REQ-001 | C++ `class_specifier` 内的 inline 方法被正确提取并注册到 Functions | P0 | 临时 .cpp 测试文件，`go test -run TestParseFile_TS_CPPMethodExtraction` |
| REQ-002 | C++ 类方法的 body 中的调用点被正确提取 | P0 | 验证 method 体内的 `strcpy`/`malloc` 等出现在 CallSites |
| REQ-003 | Python `function_definition`（包括类方法）的调用点被提取 | P0 | 临时 .py 测试文件 |
| REQ-004 | Go `function_declaration` 的调用点被提取 | P0 | 临时 .go 测试文件 |
| REQ-005 | Go `method_declaration` 的调用点被提取 | P0 | 临时 .go 测试文件 |
| REQ-006 | `parser_re.go` regex fallback 支持 Java/Go/Python 调用点提取 | P1 | CGO_ENABLED=0 go test |
| REQ-007 | 现有测试零回归（已知 5 个信号测试失败不变） | P0 | `go test ./...` |

## 设计方案

### C++ 类方法提取

新增 `walkCppClassBody` 函数，模式与 Java 的 class_body walking 完全一致：

```go
// 在 walkTopLevel 的 C/C++ handler 中增加：
case "class_specifier":
    // 现有 type name 提取保持不变
    if t := extractTypeName(child, content, file, kind); t.Name != "" {
        result.Types = append(result.Types, t)
    }
    // 新增：行走 class_body
    for j := uint(0); j < child.ChildCount(); j++ {
        body := child.Child(j)
        if body == nil || body.Kind() != "class_body" { continue }
        for k := uint(0); k < body.ChildCount(); k++ {
            method := body.Child(k)
            if method == nil || method.Kind() != "method_declaration" { continue }
            fn := FunctionInfo{File: file, ...}
            // 从 function_declarator → identifier 取方法名
            if body := findBody(method); body != nil {
                result.CallSites = append(result.CallSites, 
                    extractCallSites(body, content, fn.Name, file)...)
            }
        }
    }
```

### Python 调用点提取修复

在 `function_definition` handler 中追加：
```go
case "function_definition":
    if fn := extractNamedChild(child, content, file, "identifier"); fn.Name != "" {
        fn.StartLine = child.StartPosition().Row + 1
        fn.EndLine = child.EndPosition().Row + 1
        result.Functions = append(result.Functions, fn)
        // 新增：提取调用点
        if body := findBody(child); body != nil {
            result.CallSites = append(result.CallSites, 
                extractCallSites(body, content, fn.Name, file)...)
        }
    }
```

Python 的 `findBody` 已支持 `"block"` kind（此前在第 530 行加入）。

### Go 调用点提取修复

在 `function_declaration` 和 `method_declaration` handler 中分别追加 `findBody`+`extractCallSites`。Go 的 body kind 为 `"block"`，已在支持范围。

### parser_re.go 扩展

修改语言过滤条件，增加 Java/Go/Python 的调用点提取。使用与 C/C++ 相同的 `callSitePatterns` 列表。

## 相关文档

- [ADR-001: 统一调用 `findBody`+`extractCallSites` 而非各自编写 body walking 逻辑](./adr.md#ADR-001)
- [ADR-002: C++ class_body 行走复用 Java 模式](./adr.md#ADR-002)

## 风险与约束

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| Python 类方法的 body `block` 节点位置可能随语法版本变化 | 中等 | 使用 `findBody` 统一入口，后续只需扩展 `findBody` 的 kind 列表 |
| C++ 类方法中的 `access_specifier`（public:/private:）增加行走复杂度 | 低 | `access_specifier` 是匿名节点，只遍历 named children |
