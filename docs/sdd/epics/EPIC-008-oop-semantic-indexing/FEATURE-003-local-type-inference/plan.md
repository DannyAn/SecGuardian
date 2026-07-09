# FEATURE-003: Single-File Local Type Inference — 实施计划

## 文件修改清单

| 文件 | 改动量 | 类型 |
|------|--------|------|
| `internal/parser/types.go` | ~30 行新增 | FileScope 结构体 + knownMethodReturnTypes 映射 |
| `internal/parser/parser_ts.go` | ~120 行新增 | import 映射、field 提取、局部变量追踪、ReceiverType 解析 |
| `internal/parser/parser_ts_test.go` | ~60 行新增 | 类型推断测试 |

## 数据结构

```go
// types.go (new)
type FileScope struct {
    File      string
    Imports   map[string]string
    Variables map[string]string
    Fields    map[string]string
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

## 实施顺序

``` 
TASK-001 (FileScope struct + importMap) → TASK-002 (field extraction) → TASK-003 (局部变量追踪 + ReceiverType)
```

## 任务列表

### TASK-001: FileScope + importMap 构建

**Files**: `types.go` + `parser_ts.go`

1. `types.go` 新增 `FileScope` struct 和方法
2. `parser_ts.go` Java handler 增加 import 解析：

在 `walkTopLevel` 的 Java handler 中：
```go
case "class_declaration":
    scope := NewFileScope(file)
    // Build import map from the compilation unit (class_declaration 的 parent)
    // 实际上 import_declaration 在 class_declaration 的同级，需要从 parent 获取
    if classDecl.Parent() != nil {
        scope.Imports = buildImportMap(classDecl.Parent(), content)
    }
```

注意：Java AST 中，`import_declaration` 是 `program` 的直接子节点（与 `class_declaration` 平级），所以需要从 `class_declaration.Parent()` 开始构建。

### TASK-002: Field 声明提取

**Files**: `parser_ts.go` Java handler

在 `class_body` 行走循环中增加 `field_declaration` 处理：

```go
// 在 class_body walking 循环中
case "field_declaration":
    fieldType := extractFieldType(child, content, scope.Imports)
    for _, decl := range variableDeclarators(child) {
        scope.Fields[decl.Name] = fieldType
    }
```

`extractFieldType` 处理：
- `type_identifier` → 简单类型名
- `array_type` → 递归取元素类型
- `generic_type` → 擦除泛型，只取基类型
- 通过 imports 解析 FQN

### TASK-003: ReceiverType 解析

**Files**: `parser_ts.go` `parseCallExpr` function

1. 在 `collectCallExprs` / `parseCallExpr` 链中传递 `scope` 参数
2. 在 `parseCallExpr` 的 `method_invocation` 分支，处理完 ReceiverExpr 后，立即用 scope 解析 ReceiverType
3. 在方法 body 行走过程中，同步构建局部变量 map

关键改动点：

```go
// parseCallExpr 签名需要扩展
func parseCallExpr(callNode *sitter.Node, content []byte, caller string, file string, scope *FileScope) CallSite {
    // ... 现有逻辑 ...
    // 在设置 ReceiverExpr 处增加：
    if cs.ReceiverExpr != "" && scope != nil {
        cs.ReceiverType = resolveReceiverType(cs.ReceiverExpr, scope)
    }
    return cs
}

// 定义 receiver 类型解析函数
func resolveReceiverType(expr string, scope *FileScope) string {
    ident := extractFirstIdentifier(expr)
    
    // 1) 局部变量优先
    if t, ok := scope.Variables[ident]; ok {
        return resolveToFQN(t, scope.Imports)
    }
    // 2) field 第二
    if t, ok := scope.Fields[ident]; ok {
        return resolveToFQN(t, scope.Imports)
    }
    // 3) this.xxx → field
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
```

### TASK-004: 编译 + 测试 + 生产项目验证

```bash
# 编译
CGO_ENABLED=1 go build -o /tmp/secguardian-ep8 .

# 单元测试
CGO_ENABLED=1 go test ./... -run TestParseFile_TS_TypeInference -v

# 生产项目验证
/tmp/secguardian-ep8 --path /Users/kongan/workbench/gitee/pkmhipster/main/src --output /tmp/pkhipster-ep8.json

# 检查 ReceiverType
python3 -c "
import json
with open('/tmp/pkhipster-ep8.json') as f:
    ctx = json.load(f)
for cs in ctx.get('call_sites', []):
    if cs.get('receiver_type'):
        print(f'{cs[\"caller\"]:30s} | {cs[\"receiver\"]:20s} → {cs[\"receiver_type\"]}')
"
```
