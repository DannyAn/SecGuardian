# FEATURE-002: OOP Metadata Enrichment — 实施计划

## 文件修改清单

| 文件 | 改动量 | 类型 |
|------|--------|------|
| `internal/parser/types.go` | ~6 行 | FunctionInfo + CallSite 新增字段 |
| `internal/parser/parser_ts.go` | ~50 行新增 | Java/C++/Go/Python handler 填入新字段 + ReceiverExpr 提取 |
| `internal/parser/parser_re.go` | 0 行 | omitempty 自动处理 |

## 实施顺序

```
TASK-001 (struct 扩展) → TASK-002~005 (各语言 handler 填字段，无依赖，可并行) → TASK-006 (测试)
```

## 任务列表

### TASK-001: 结构体扩展

**Files**: `types.go`

```go
type FunctionInfo struct {
    Name       string `json:"name"`
    File       string `json:"file"`
    StartLine  uint   `json:"start_line"`
    EndLine    uint   `json:"end_line"`
    ClassName  string `json:"class_name,omitempty"`
    Visibility string `json:"visibility,omitempty"`
    IsStatic   bool   `json:"is_static,omitempty"`
}

type CallSite struct {
    // ... 现有字段不变 ...
    ReceiverExpr   string `json:"receiver,omitempty"`
    ReceiverType   string `json:"receiver_type,omitempty"`
}
```

### TASK-002: Java handler — ClassName/Visibility/IsStatic

**Files**: `parser_ts.go` walkTopLevel Java `class_declaration` handler

改动点（当前 Java handler 已有 class_body → method_declaration 行走）：

1. 在进入 `class_body` 循环前，记录 `className`
2. 创建 `FunctionInfo` 时，设置 `ClassName = className`
3. 对每个 method_declaration，检查其子节点获取 Visibility
4. 对每个 method_declaration，检查其子节点是否有 `"static"` kind

Visibility 提取逻辑：
```go
func extractJavaVisibility(method *sitter.Node) string {
    for i := uint(0); i < method.ChildCount(); i++ {
        child := method.Child(i)
        if child == nil { continue }
        switch child.Kind() {
        case "public":    return "public"
        case "protected": return "protected"
        case "private":   return "private"
        }
    }
    return "package-private"
}
```

IsStatic 提取逻辑：
```go
func hasStaticModifier(method *sitter.Node) bool {
    for i := uint(0); i < method.ChildCount(); i++ {
        child := method.Child(i)
        if child != nil && child.Kind() == "static" {
            return true
        }
    }
    return false
}
```

### TASK-003: C++ handler — ClassName/Visibility/IsStatic

**Files**: `parser_ts.go` walkTopLevel C/C++ handler

C++ 的 access_specifier 是有状态的：
```go
currentVisibility := "private" // C++ class default
for j := uint(0); j < classBody.ChildCount(); j++ {
    child := classBody.Child(j)
    if child == nil { continue }
    switch child.Kind() {
    case "access_specifier":
        // 取 access_specifier 的子节点 name_identifier
        if as := child.Child(0); as != nil {
            currentVisibility = as.Kind() // "public"/"protected"/"private"
        }
    case "method_declaration":
        fn.Visibility = currentVisibility
        fn.IsStatic = hasStaticModifier(child)
    }
}
```

### TASK-004: Python/Golang handler — ClassName

**Files**: `parser_ts.go` walkTopLevel

Python：在 `class_definition` handler 中，对内部 `function_definition` 注册时设置 `ClassName = className`

Go：在 `method_declaration` handler 中，从 `parameter_list` 提取 receiver 类型作为 ClassName

### TASK-005: ReceiverExpr 提取

**Files**: `parser_ts.go` `parseCallExpr` function

新增 `extractReceiverExpr` 函数：
```go
func extractReceiverExpr(node *sitter.Node, content []byte) string {
    if node == nil { return "" }
    // 对于 field_access 节点，取其整个文本作为 receiver 表达式
    return string(content[node.StartByte():node.EndByte()])
}
```

在 `parseCallExpr` 的 `method_invocation` 分支中调用。

### TASK-006: 编译 + 回归测试

```bash
CGO_ENABLED=1 go build ./...
CGO_ENABLED=1 go test ./... 2>&1 | grep -E "(PASS|FAIL|---)"
```

验证 JSON 输出中的新字段：
- Java: `class_name`、`visibility`、`receiver` 出现
- C++: `class_name`、`visibility`、`receiver` 出现
- Python: `class_name`、`receiver` 出现
- Go: `class_name`、`receiver` 出现
- C: 只有 `receiver`（C 没有 class/visibility/static）
