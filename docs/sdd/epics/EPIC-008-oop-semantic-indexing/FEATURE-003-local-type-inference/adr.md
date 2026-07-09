# ADR Records — FEATURE-003: Single-File Local Type Inference

---

## ADR-008: 单文件作用域只追踪局部类型——不做跨文件类型解析

**日期**: 2026-07-08
**状态**: ✅ Accepted

### Decision

FEATURE-003 的类型推断严格限制在单个文件内部。scope 由以下来源构建：
1. 当前文件的 import 声明
2. 当前 class 的 field 声明（class body 内的 field_declaration）
3. 当前方法体内部的局部变量声明（local_variable_declaration）

不做跨文件 class 引用解析、不做继承链追踪、不做全局 scope 合并。

### Reason

- **收益/成本比**：单文件 scope 能覆盖 80%+ 的 case（`conn.executeQuery`、`log.info`、`JSON.parseObject` 都在单文件作用域内）。跨文件继承链追踪的实现成本可能是单文件的 10 倍
- **架构边界**：Parser 的职责是解析单个文件。跨文件分析在 Indexer 层
- **渐进式改进**：如果后续需要跨文件推断，可以在 Indexer 层建立全局符号表，然后注入到 Parser 的 scope 中

### Consequences

- 跨文件的 `SomeService.serviceMethod()` 解析不了 receiver type（除非 `SomeService` 是 import 的）
- `MyBatis Plus baseMapper` 无法解析（继承自 `ServiceImpl<M,T>`），这之前被确认为不可能
- 但 `getConnection()` 返回 `Connection`（通过 knownMethodReturnTypes）覆盖了最常见的 JDBC 场景

---

## ADR-009: 类型解析按优先级：局部变量 → field → 无法解析

**日期**: 2026-07-08
**状态**: ✅ Accepted

### Decision

ReceiverType 解析严格按优先级链进行：
1. 局部变量（`vars` map）— 方法体内最新声明的变量
2. Field（`fields` map）— class 级别的字段
3. 都找不到 → `ReceiverType = ""`（不出现在 JSON）

### Reason

- 局部变量优先于 field 是正确的：方法内同名局部变量会 shadow field
- `this.xxx` 指向 field，可以通过 receiver 表达式前缀 `"this."` 识别
- 无法解析时留空是安全的——下游检测器按"无类型信息"处理

### Consequences

- 误写/影子变量的 case 不会错误关联类型
- 所有无法推断类型的 case 退化为当前行为（无 ReceiverType）

---

## ADR-010: 方法返回类型映射使用硬编码列表而非反射/全局分析

**日期**: 2026-07-08
**状态**: ✅ Accepted

### Decision

对于 `var` 推断和方法链式调用的中间类型，使用一个小的硬编码 `knownMethodReturnTypes` 映射（约 15 条），而非通过反射或全量 classpath 扫描。

### Reason

- 我们的安全扫描只关注约 50 个 knownLibFuncs，这些函数的常见工厂方法类型是可以穷举的
- `getConnection()` → `java.sql.Connection` 不会因为版本更新而变化
- 后续需要补充时，只需在映射里加条目，不需要重编译整个分析引擎

### Consequences

- 硬编码映射需要手动维护（版本升级时检查是否过时）
- 覆盖率取决于映射的完整度
- 与 `knownLibFuncs` 同级别维护，互补关系

---

## ADR-011: C++/Go/Python 暂不做类型推断

**日期**: 2026-07-08
**状态**: ✅ Accepted

### Decision

FEATURE-003 的类型推断只对 Java 实现。C++/Go/Python 的局部类型推断推迟到后续 Epic。

### Reason

- 已验证的生产问题全部来自 Java 项目。C++/Go/Python 在真实扫描中尚未发现"missed receiver type"导致的漏报
- C++ 需要处理 `using`、`namespace`、`typedef`、`template`，解析复杂度显著高于 Java
- Go 的短变量声明（`:=`）和 interface 系统使得类型推断需要全程序分析
- Python 是动态类型，不存在编译时类型信息

### Consequences

- C++/Go/Python 的 `ReceiverType` 字段始终为零值（不出现在 JSON）
- 后续 Epic 可以用单独的 ADR 来决定各语言的分阶段实施策略
