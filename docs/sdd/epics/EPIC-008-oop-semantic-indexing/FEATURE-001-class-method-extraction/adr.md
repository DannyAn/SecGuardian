# ADR Records — FEATURE-001: Fix Class Method Extraction Gaps

---

## ADR-001: 统一调用 `findBody`+`extractCallSites` 而非各自编写 body walking 逻辑

**日期**: 2026-07-08
**状态**: ✅ Accepted

### Decision

所有语言 handler 在提取函数/方法名后，都调用现有的 `findBody(node)` + `extractCallSites(body, ...)` 模式，不编写各自的 AST 行走逻辑。

### Reason

- 4 个语言 handler（C++ class methods, Python function_definition, Go function/method_declaration）需要相同的逻辑："找 body → 行走 body → 提取调用点"
- `findBody` 已支持全部 3 种 body kind（compound_statement / body / block），`collectCallExprs` + `parseCallExpr` 已支持 call_expression + method_invocation
- 新增 4 个地方的逻辑完全一致，不会产生语言特化逻辑泄漏

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 为 C++/Python/Go 各自编写专用的 body walking 函数 | 代码复制，且各自实现容易产生差异 bug |
| 将 `findBody`+`extractCallSites` 提升到 `extractIdent` 内部 | `extractIdent` 不负责 function_declarator 以外的 case |

### Consequences

- 4 处 handler 改造后，新增代码总量约 10 行
- 未来新增语言时，只需要 2 步：注册函数名 + 调用 `findBody`+`extractCallSites`

---

## ADR-002: C++ class_body 行走复用 Java 模式

**日期**: 2026-07-08
**状态**: ✅ Accepted

### Decision

C++ `class_specifier` 的行走逻辑直接复用 Java `class_declaration` → `class_body` → `method_declaration` 的同模式，不引入新的抽象层。

### Reason

- Java 的行走逻辑已经过生产验证（正确提取了所有 Java 类方法的调用点）
- C++ 的 tree-sitter AST 结构与 Java 几乎一致：`class_specifier` → `class_body` → `method_declaration`
- 差异仅在方法名提取路径：C++ 的 method_declaration 可能包含 `function_declarator` 子节点

### Consequences

- `walkCppClassBody` 函数约 25 行，与 Java handler 结构对称
- 后续如果 `class_body` 行走逻辑需要增强（如嵌套类、匿名类），Java 和 C++ 同步修改

---

## ADR-003: parser_re.go 调用点提取不受限 all languages

**日期**: 2026-07-08
**状态**: ✅ Accepted

### Decision

移除 `parser_re.go` 第 224 行的 `if lang == "c" || lang == "cpp"` 限制，使 regex fallback 对所有语言进行调用点提取。

### Reason

- `callSitePatterns` 已包含 Java/Python/Go 通用的 logging/deserialization/SQL/exec 条目
- regex 路径是 `!CGO` 降级路径，完整性比精度重要——宁可误报也不能漏报
- 语言过滤在 command 层（`--lang` 参数）已经做了一次，parser 层面不需要再过滤

### Consequences

- `CGO_ENABLED=0` 场景下，Java/Go/Python 项目也能获得调用点信号
- regex 提取不区分 class 作用域，所有调用点都 flat 输出到顶层
