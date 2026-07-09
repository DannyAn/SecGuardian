# FEATURE-002: OOP Metadata Enrichment

> **父 Epic**: EPIC-008 OOP-Aware Semantic Indexing
> **状态**: 📋 Spec 制定中
> **目标版本**: v0.18.0

## 问题陈述

当前 `FunctionInfo` 只包含 `Name`、`File`、`StartLine`、`EndLine`，完全丢失与 OOP 相关的语义信息：

```go
// types.go 当前
type FunctionInfo struct {
    Name      string `json:"name"`
    File      string `json:"file"`
    StartLine uint   `json:"start_line"`
    EndLine   uint   `json:"end_line"`
}
```

同样 `CallSite` 不记录调用者表达式的接收者：

```go
// types.go 当前
type CallSite struct {
    CallerFunction string   `json:"caller"`
    CalleeName     string   `json:"callee"`
    // ... 没有 ReceiverExpr, ReceiverType
}
```

这导致下游无法区分：
- `log.info("xxx")` 和 `myObj.info("xxx")` 都是 `info`，但前者是 SLF4J 日志
- `conn.executeQuery(sql)` 和 `dto.executeQuery(null)` 都是 `executeQuery`，但前者是 SQL 注入

## 需求

| 编号 | 需求 | 优先级 | 验证方法 |
|------|------|--------|----------|
| REQ-001 | `FunctionInfo` 增加 `ClassName` 字段，标记方法所属类 | P0 | Java/C++ 类方法扫描结果包含 class_name |
| REQ-002 | `FunctionInfo` 增加 `Visibility` 字段（public/protected/private/package-private/unknown） | P1 | 扫描结果包含 visibility |
| REQ-003 | `FunctionInfo` 增加 `IsStatic` 字段（是否为静态方法） | P1 | `Math.abs()`, `Runtime.getRuntime()` 标记为 static |
| REQ-004 | `CallSite` 增加 `ReceiverExpr` 字段，记录方法调用的接收者表达式 | P0 | `conn.executeQuery()` → `ReceiverExpr: "conn"` |
| REQ-005 | `CallSite` 增加 `ReceiverType` 字段（由 FEATURE-003 填充，本 Feature 先留空） | P0 | 占位，后续 Feature 填入 |
| REQ-006 | 所有语言 handler 各自按语言语法填入新字段 | P0 | 测试包含各语言样例 |
| REQ-007 | JSON 输出向后兼容（新字段加 omitempty，不存在时不出现） | P0 | 旧解析结果与新解析结果 diff 仅含新增字段 |
| REQ-008 | parsers_re.go 同步扩展（使用 omitempty 或零值） | P1 | CGO_ENABLED=0 测试 |

## 设计方案

### 2.1 结构体扩展

```go
type FunctionInfo struct {
    Name       string `json:"name"`
    File       string `json:"file"`
    StartLine  uint   `json:"start_line"`
    EndLine    uint   `json:"end_line"`
    ClassName  string `json:"class_name,omitempty"`  // NEW: 所属类名
    Visibility string `json:"visibility,omitempty"`   // NEW: public/protected/private
    IsStatic   bool   `json:"is_static,omitempty"`    // NEW: true when static
}

type CallSite struct {
    CallerFunction string   `json:"caller"`
    CalleeName     string   `json:"callee"`
    File           string   `json:"file"`
    Line           uint     `json:"line"`
    Arguments      []string `json:"arguments"`
    IsSafeVariant  bool     `json:"safe_variant"`
    Category       string   `json:"category"`
    ReceiverExpr   string   `json:"receiver,omitempty"`     // NEW: "log", "conn", "this", "" for free functions
    ReceiverType   string   `json:"receiver_type,omitempty"` // NEW: FEATURE-003 fills
}
```

`omitempty` 确保：
- C/C++ 没有 class 的顶级函数：`class_name` 字段不出现在 JSON
- 自由函数调用：`receiver` 字段不出现在 JSON
- 旧版工具链全兼容（解析旧 JSON 时 OOP 字段只是不存在）

### 2.2 Java — ClassName/Visibility/IsStatic 提取

在 `walkTopLevel` 的 `class_declaration` handler 中：

```go
case "class_declaration":
    className := extractIdentifierName(classDecl)
    for each child of class_body:
        if child.Kind() == "method_declaration":
            fn := FunctionInfo{File: file, ClassName: className}
            // Visibility: 检查第一个 token
            modifier := method.Child(0)
            switch modifier.Kind() {
            case "public":    fn.Visibility = "public"
            case "protected": fn.Visibility = "protected"
            case "private":   fn.Visibility = "private"
            default:          fn.Visibility = "package-private" // 没有显式修饰符
            }
            // IsStatic: 遍历所有子节点检查 "static"
            for each child of method:
                if child.Kind() == "static":  fn.IsStatic = true
                if child.Kind() == "block":   // constructor, no name
                    break
```

### 2.3 C++ — ClassName/Visibility/IsStatic 提取

与 Java 模式一致。C++ 特有差异：

```go
// Visibility 通过 access_specifier 推断
// public:/protected:/private: 之前的区域属于上一个 access_specifier
// 默认为 private（C++ class 默认访问控制）
for each child of class_body:
    if child.Kind() == "access_specifier":
        currentVisibility = child.Child(0).Kind() // "public", "protected", "private"
    if child.Kind() == "method_declaration":
        fn.Visibility = currentVisibility
```

C++ `static` 关键字在 method 上检查与 Java 相同。

### 2.4 Python — ClassName 提取

Python `function_definition` 如果嵌套在 `class_definition` → `block` 下，从外层 class 获取 `ClassName`。

```go
// walkTopLevel: Python handler
case "class_definition":
    className := extractIdentifierName(classDef)
    for each child of block:
        if child.Kind() == "function_definition":
            fn.ClassName = className
```

Python 没有 `public`/`protected`/`private` 关键字（惯例用 `_` 前缀），Visibility 从略。

### 2.5 Go — ClassName 提取

Go `method_declaration` 的 receiver 类型就是 ClassName：

```go
case "method_declaration":
    // receiver 节点: (parameter_declaration) → type_identifier
    for each child of method:
        if child.Kind() == "parameter_list":
            params := child // receiver is first param
            fn.ClassName = extractTypeName(params.Child(0))
```

Go 没有 `static` 修饰符。没有 `public`/`private` 关键字（用首字母大小写区分），直接从略。

### 2.6 ReceiverExpr 提取

在 `parseCallExpr` 的 `method_invocation` 分支中：

```go
case "method_invocation":
    // 遍历子节点找 field_access（reciver 在左侧）
    for i := uint(0); i < ck.ChildCount(); i++ {
        child := ck.Child(i)
        if child == nil { continue }
        switch child.Kind() {
        case "field_access":
            // obj.method() → 递归提取接收者表达式
            // field_access 的 object 子节点可能是 identifier/field_access/method_invocation
            cs.ReceiverExpr = extractReceiverExpr(child)
        case "identifier":
            // method() — 可能隐式 this 调用
            // 检查是否有 "scope_resolution" 子节点（如 Class.staticMethod()）
            cs.ReceiverExpr = ""  // 自由调用
        }
    }
```

`extractReceiverExpr` 函数递归提取接收者表达式文本：

```go
func extractReceiverExpr(node *sitter.Node, content []byte) string {
    switch node.Kind() {
    case "identifier":
        return string(content[node.StartByte():node.EndByte()])
    case "field_access":
        return string(content[node.StartByte():node.EndByte()])
    case "method_invocation":
        return string(content[node.StartByte():node.EndByte()])
    default:
        return string(content[node.StartByte():node.EndByte()])
    }
}
```

### 2.7 parser_re.go 同步

regex 版本不精确提取 Visibility/IsStatic/ClassName 元数据，使用零值/omitempty 使字段不出现在 JSON 中。ReceiverExpr 也不精确提取（regex 路径看不到 AST 结构）。

## 相关文档

- [ADR-004: omitempty 策略确保向后兼容](./adr.md#ADR-004)
- [ADR-005: ReceiverExpr 提取规则——field_access 优先](./adr.md#ADR-005)

## 风险与约束

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| C++ visibility 跨 access_specifier 边界有状态 | 低 | 只在 class_body 范围内追踪 currentVisibility |
| Python duck typing 无类信息 | 低 | ClassName 从外层 class_definition 取，没有则不填 |
| Go 方法可能同时有 pointer 和 value receiver 两种 | 低 | 统一用 type_identifier 提取类名 |
