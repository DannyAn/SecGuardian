# FEATURE-003: Single-File Local Type Inference

> **父 Epic**: EPIC-008 OOP-Aware Semantic Indexing
> **状态**: 📋 Spec 制定中
> **目标版本**: v0.18.0

## 问题陈述

当前 Parser 提取了 `log.info()`、`conn.executeQuery()`、`JSON.parseObject()` 等调用，但不知道 `log`、`conn`、`JSON` 的类型。下游检测器只能看到：

```json
{"callee": "executeQuery", "receiver": "conn", "category": "sql"}
```

无法区分：
- `conn.executeQuery(sql)` — `conn` 类型为 `java.sql.Connection` → SQL 注入 ✅
- `dto.executeQuery(someParam)` — `dto` 类型是本地 DTO 的查询方法 → 假阳性 ❌
- `safeWrapper.executeQuery(sql)` — `safeWrapper` 有参数化校验 → 需要降级 ❌

## 需求

| 编号 | 需求 | 优先级 | 验证方法 |
|------|------|--------|----------|
| REQ-001 | 解析 Java 文件的 `import` 语句，建立短名→FQN 的映射 | P0 | 生产项目 scan 的 import 映射中应包含 `Connection`→`java.sql.Connection` |
| REQ-002 | 解析 Java class body 中的 field 声明，建立 field 名→类型的映射 | P0 | `Connection conn;` → `fields["conn"] = "java.sql.Connection"` |
| REQ-003 | 解析方法内部局部变量的 type annotation，建立 var 名→类型的映射 | P0 | `Connection c = ds.getConn()` → `vars["c"] = "java.sql.Connection"` |
| REQ-004 | 在 `parseCallExpr` 中对 `method_invocation` 做接收者类型解析 | P0 | `conn.executeQuery()` → `ReceiverType: "java.sql.Connection"` |
| REQ-005 | `var` 关键字推断（Java 10+），从右侧初始化表达式推断类型 | P1 | `var conn = dataSource.getConnection()` → 从右侧 expression 推断 |
| REQ-006 | 链式调用中的类型传递（`factory.getConnection().executeQuery()`） | P1 | 链式调用的中间类型推断 |
| REQ-007 | 只做单文件分析，不做跨文件类型解析 | P0 | 设计约束，明确写明 |
| REQ-008 | 向后兼容：类型不能解析时 ReceiverType 为零值不出现在 JSON | P0 | omitempty |

## 设计方案

### 3.1 FileScope 数据结构

```go
type FileScope struct {
    File      string
    Imports   map[string]string  // shortName → fully qualified name
    Variables map[string]string  // varName → resolved type (local vars)
    Fields    map[string]string  // fieldName → resolved type (class fields)
}

func NewFileScope(file string) *FileScope {
    return &FileScope{
        File:      file,
        Imports:   make(map[string]string),
        Variables: make(map[string]string),
        Fields:    make(map[string]string),
    }
}
```

### 3.2 Import 映射构建

在 `walkTopLevel` 的 Java handler 中，遍历所有顶级节点，对 `import_declaration` 建立映射：

```go
// import_declaration → "import java.sql.Connection;"
//   ├── name_identifier: "java"
//   ├── scoped_identifier: "java.sql"
//   └── scoped_identifier: "java.sql.Connection"
//
// 简化策略：取最后一段标识符和完整限定名

func buildImportMap(classNode *sitter.Node, content []byte) map[string]string {
    imports := make(map[string]string)
    for i := uint(0); i < classNode.ChildCount(); i++ {
        child := classNode.Child(i)
        if child == nil || child.Kind() != "import_declaration" {
            continue
        }
        // 取 import 语句的文本
        importPath := safeText(content, child.StartByte(), child.EndByte())
        // "import java.sql.Connection;" → "java.sql.Connection"
        path := strings.TrimPrefix(strings.TrimSuffix(importPath, ";"), "import ")
        parts := strings.Split(path, ".")
        if len(parts) >= 1 {
            shortName := parts[len(parts)-1]
            imports[shortName] = path
        }
    }
    return imports
}
```

### 3.3 Field 声明提取

在 `class_body` 行走过程中，识别 `field_declaration`，提取类型：

```go
// field_declaration:
//   ├── type_identifier: "Connection" (or "String", "int", etc.)
//   ├── variable_declarator:
//   │   ├── identifier: "conn"
//   │   └── ...
//
// 注意：每个 field_declaration 可能包含多个 variable_declarator
// "String a, b;" → fields["a"] = "String", fields["b"] = "String"

func collectFields(body *sitter.Node, content []byte, imports map[string]string) map[string]string {
    fields := make(map[string]string)
    for i := uint(0); i < body.ChildCount(); i++ {
        child := body.Child(i)
        if child == nil || child.Kind() != "field_declaration" {
            continue
        }
        varType := extractFieldType(child, content, imports)
        for j := uint(0); j < child.ChildCount(); j++ {
            decl := child.Child(j)
            if decl == nil || decl.Kind() != "variable_declarator" {
                continue
            }
            name := extractIdentifier(decl)
            if name != "" {
                fields[name] = varType
            }
        }
    }
    return fields
}
```

类型解析规则：
1. **直接类型匹配**：`type_identifier` 直接取文本
2. **全限定名解析**：从 imports 映射中查找匹配（`Connection` → `java.sql.Connection`）
3. **泛型擦除**：`List<String>` → 只保留 `List`
4. **数组类型**：`byte[]` → `byte[]`
5. **不能解析时**：保留原始类型名文本

### 3.4 局部变量追踪

在 `parseCallExpr` 或专门的局部声明 handler 中，追踪方法体内的局部变量：

```go
// variable_declarator:
//   ├── identifier: "cmd"
//   └── ...
//
// 在方法 body 行走时同步构建 var 映射：
// "String cmd = req.getParameter("cmd");" → vars["cmd"] = "java.lang.String"

func extractLocalVarDeclarations(body *sitter.Node, content []byte, imports map[string]string) map[string]string {
    vars := make(map[string]string)
    walkLocalVars(body, content, imports, vars)
    return vars
}

func walkLocalVars(node *sitter.Node, content []byte, imports map[string]string, vars map[string]string) {
    if node == nil { return }
    
    if node.Kind() == "local_variable_declaration" {
        varType := extractFieldType(node, content, imports)
        // 遍历 sibling 提取变量名
        for i := uint(0); i < node.ChildCount(); i++ {
            child := node.Child(i)
            if child == nil { continue }
            if child.Kind() == "variable_declarator" {
                name := extractIdentifierFromDeclarator(child)
                if name != "" {
                    vars[name] = varType
                }
            }
        }
    }
    
    // 继续递归
    for i := uint(0); i < node.ChildCount(); i++ {
        walkLocalVars(node.Child(i), content, imports, vars)
    }
}
```

### 3.5 ReceiverType 解析

在 `parseCallExpr` 的 `method_invocation` 分支中，使用 scope 信息：

```go
func resolveReceiverType(receiverExpr string, scope *FileScope) string {
    if scope == nil {
        return ""
    }
    
    // 1. 处理链式调用：取第一个标识符
    firstIdent := extractFirstIdentifier(receiverExpr)
    
    // 2. 检查局部变量
    if t, ok := scope.Variables[firstIdent]; ok {
        return resolveImport(t, scope.Imports)
    }
    
    // 3. 检查 field
    if t, ok := scope.Fields[firstIdent]; ok {
        return resolveImport(t, scope.Imports)
    }
    
    // 4. 无法解析
    return ""
}
```

### 3.6 `var` 关键字（Java 10+）推断

对 `var` 声明的变量，从右侧初始化表达式推断类型：

```go
// "var conn = dataSource.getConnection();"
// local_variable_declaration:
//   ├── "var"
//   ├── variable_declarator:
//   │   ├── identifier: "conn"
//   │   └── method_invocation → getConnection()
//
// 从右侧 method_invocation 的已知返回类型推断
```

对于 `var` 推断，我们需要一个**少量高置信度的方法返回类型映射**：

```go
var knownMethodReturnTypes = map[string]string{
    "getConnection":          "java.sql.Connection",
    "getSession":             "org.hibernate.Session",
    "createEntityManager":    "javax.persistence.EntityManager",
    "getRequest":             "javax.servlet.http.HttpServletRequest",
    "getResponse":            "javax.servlet.http.HttpServletResponse",
    "getParameter":           "java.lang.String",
    "getHeader":              "java.lang.String",
    "getCookies":             "javax.servlet.http.Cookie[]",
    "getQueryString":         "java.lang.String",
    "getInputStream":         "java.io.InputStream",
    "getReader":              "java.io.BufferedReader",
    "newDocumentBuilder":     "javax.xml.parsers.DocumentBuilder",
    "newSAXParser":           "javax.xml.parsers.SAXParser",
}
```

### 3.7 完整数据流

```
walkTopLevel Java handler:
  1. 找到 class_declaration
  2. 构建 importMap ← import_declaration 节点
  3. 提取 fields ← field_declaration 节点
  4. scope = FileScope{Imports: importMap, Fields: fields}

进入 method body:
  5. findBody → extractCallSites(body, ...)
      → collectCallExprs → parseCallExpr(node, scope)
      
parseCallExpr:
  6. 对 method_invocation，提取 receiverExpr
  7. 用 receiverExpr 查询 scope.Variables/scope.Fields
  8. 查到 → 用 importMap 解析 FQN
  9. 设置 CallSite.ReceiverType
  10. 将局部变量声明加入 scope.Variables 供后续调用点使用
```

## 不做的范围

| 不做 | 原因 |
|------|------|
| 跨文件继承树追踪 | 需要全局类层次分析，超 parse 职责 |
| 跨文件 class 引用 | 当前只追踪单文件 imports + fields + 局部变量 |
| 泛型类型参数解析 | `List<String>` → 只保留 `List` |
| 方法重载解析 | `method(L)` vs `method(E)` 区分对安全扫描无意义 |
| C++ namespace 解析 | C++ 的 using/namespace 比 Java import 复杂太多 |
| Go interface 实现推断 | 需要全程序分析，目前 Go 的跨文件分析在 indexer 层 |
