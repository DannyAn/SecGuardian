# ADR Records — FEATURE-002: OOP Metadata Enrichment

---

## ADR-004: omitempty 策略确保向后兼容

**日期**: 2026-07-08
**状态**: ✅ Accepted

### Decision

所有新增的 OOP 字段在 JSON 序列化时使用 `omitempty`（或对 `bool` 类型用 `,omitempty` 结合零值即 false 的语义）。

### Reason

- 旧版工具链（其他仓库使用的 JSON 解析器）不应被破坏
- regex 路径（`parser_re.go`）不产生 OOP 元数据，omitempty 确保输出干净
- 下游检测器可以检查 `class_name` 或 `receiver` 字段是否存在于 JSON 中，不存在则按默认值处理

### Consequences

- parser_re.go 完全不用修改 struct 引用（零值自动 omitempty）
- JSON 输出大小在非 OOP 语言上不增加
- 新旧 JSON 的 diff 仅包含新增字段（如果存在数据），没有格式变更

---

## ADR-005: ReceiverExpr 提取规则——field_access 优先

**日期**: 2026-07-08
**状态**: ✅ Accepted

### Decision

`parseCallExpr` 对 `method_invocation` 节点，从 `field_access` 子节点提取接收者表达式。如果没有 `field_access`，则为自由函数调用（ReceiverExpr = ""）。

### Reason

- Java/C++/Go/Python 的 `method_invocation` AST 子节点布局不同，但 `field_access` 始终代表接收者
- `identifier` 子节点可能是方法名也可能是接收者（如 Python `self.method()` 中 `self` 是 identifier），通过检查是否存在 `field_access` 可区分
- 不尝试解析 `field_access` 内部的链式调用结构（如 `Runtime.getRuntime().exec()`），直接取整个表达式字符串

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 给所有子节点分类为 receiver/method/args | 需要知道每个语言的 AST 布局，维护成本高 |
| Python 特殊处理 `self.method()` | `self` 对安全扫描没有语义价值（不指向特定类型）|

### Consequences

- 链式调用如 `a.b().c()` 中，`c()` 的 ReceiverExpr 是整个 `a.b()` 表达式
- 自由函数如 `exec("cmd")` 的 ReceiverExpr = ""
- `Class.staticMethod()` 可能无法区分——取决于 tree-sitter 是否生成 field_access

---

## ADR-006: Visibility 仅在有明确关键字的语言中提取

**日期**: 2026-07-08
**状态**: ✅ Accepted

### Decision

只在 Java 和 C++ 中提取 Visiblity。Python（`_` 前缀惯例）和 Go（首字母大小写）略过此字段。

### Reason

- Python 和 Go 的可见性不是通过 AST 节点表达的，需要通过语义分析（命名惯例/首字母大小写）
- 安全扫描不需要 visibility 来判定危险调用（private method 也可能执行 sql）
- visibility 是辅助元数据，P1 优先级，不值得为边际价值增加复杂性

### Consequences

- Java: visibility 精准提取（public/protected/private/package-private）
- C++: visibility 通过 access_specifier 追踪
- Python: visibility 始终为零值（不出现在 JSON）
- Go: visibility 始终为零值（不出现在 JSON）

---

## ADR-007: IsStatic 通过扫描子节点中的 static 关键字判断

**日期**: 2026-07-08
**状态**: ✅ Accepted

### Decision

不额外引入语言特定的修饰符解析器。对 `method_declaration`/`function_declaration` 的子节点，遍历检查是否有 kind 为 `"static"` 的节点。

### Reason

- Java 和 C++ 的 Tree-sitter 语法中，`static` 修饰符都是 `method_declaration` 的子节点（kind 为 `"static"`）
- 不需要理解修饰符在子节点中的精确位置，只需做存在性检查
- 没有 static 的语言（Python/Go）天然结果是 false

### Consequences

- Java 静态方法（如 `Runtime.getRuntime()`）的类方法标记 `IsStatic: true`
- Java 普通方法标记 `IsStatic: false`（omitempty 不出现在 JSON）
- C++ 静态成员函数标记 `IsStatic: true`
