---
detector: bad-cast
description: Detects unsafe or invalid type casts that could lead to memory corruption
severity: medium
cwe: CWE-704
cvss: 5.5
language: [c, cpp]
tags: [memory, type-safety, undefined-behavior]
precision: high
confidence: dynamic
target_functions: [code_context, data_flow_path, judgment_rationale, uintptr_t, variable_state]
match_patterns: [\(void\s*\*?\(\*\)\)                                 # C风格函数指针cast, reinterpret_cast<(?!.*char\*|.*void\*|.*uintptr_t|.*intptr_t)  # 非底层用途的 reinterpret_cast, static_cast<Derived\*>.*base_ptr                    # 向下转换, \([A-Za-z_]\w*\s*\*+\)\s*[&*]?\w+                   # C风格指针cast，非void*互转]
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

不兼容类型之间的强制转换导致未定义行为或类型混淆。C 风格 cast `(Type)val` 绕过编译器类型检查，`reinterpret_cast` 放弃类型安全。类型混淆可导致虚函数表劫持（vtable hijacking）。

**核心原则：C++ 代码使用 `static_cast`/`dynamic_cast`，禁止 `reinterpret_cast` 的非必要使用。C 代码使用显式 union 而非指针 cast。**

## 检测逻辑 (Detection Logic)

### Step 1: 搜索 C 风格转换 (C-Style Cast Detection)

```c
// BAD: 函数指针与对象指针互转
void (*fp)() = (void(*)())obj_ptr;
fp();                            // 未定义行为

// BAD: 指针与整数互转
int addr = (int)ptr;             // 可能截断（64 位系统）
void *p2 = (void*)addr;
```

### Step 2: 检查 reinterpret_cast (C++) (reinterpret_cast Detection)

```cpp
// BAD: 不相关的类型互转
struct A { int x; };
struct B { double y; };
A* a = new A;
B* b = reinterpret_cast<B*>(a);  // 严格别名违规
b->y = 3.14;                     // 未定义行为
```

### Step 3: 向上/向下转换安全 (Safe vs Unsafe Downcast)

```cpp
// BAD: 无虚函数的 static_cast 向下转换
class Base {};
class Derived : public Base { int x; };
Base* b = new Base;
Derived* d = static_cast<Derived*>(b); // 未定义行为
d->x = 42;

// GOOD: 有虚函数时使用 dynamic_cast
class VBase { virtual ~VBase() {} };
class VDerived : public VBase {};
VBase* vb = new VDerived;
VDerived* vd = dynamic_cast<VDerived*>(vb); // 安全：运行时检查
```

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：cast 表达式的完整代码行，包含源类型和目标类型的定义（struct/class 定义），标注转换操作符类型（C-style / static_cast / reinterpret_cast / dynamic_cast / const_cast）
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析源类型和目标类型的内存布局兼容性——大小对比、对齐要求、虚函数表是否存在；对于向下转换，确认基类是否有虚函数、运行时实际类型是否为派生类
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：被转换指针/引用的来源——从何处获取、经过哪些类型擦除（如存储为 void* 或基类指针），最终在何处通过 cast 恢复类型
      → findings.evidence.data_flow_path
- [ ] **call_stack**：cast 发生的位置 → 转换后对象的使用位置（函数调用、成员访问），确认使用方式是否与源类型兼容
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：运行时实际类型（通过 type_info/dynamic_cast 结果）、转换前后指针值是否保持不变、是否存在 strict aliasing 违规
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：UBSan (UndefinedBehaviorSanitizer) 输出、编译器 -Wold-style-cast / -Wstrict-aliasing 诊断
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **C++**：使用 `static_cast`（编译期类型检查）/ `dynamic_cast`（运行时检查）
2. **禁止**：`reinterpret_cast` 用于非底层编程场景
3. **C 代码**：使用显式 `union` 而非指针 cast 做类型双关（type punning）
4. **编译器警告**：启用 `-Wold-style-cast` (GCC) / `-Wdeprecated` 检测 C 风格 cast

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `dynamic_cast` 向下转换 | 运行时类型检查，失败返回 nullptr（指针）或抛出 std::bad_cast（引用） | 确认使用 dynamic_cast 且目标类型含虚函数 |
| void\* → T\* 的合法转换 | 常见模式如 malloc 包装函数返回 void* 后转为具体类型，语言标准允许 void* 与对象指针互转 | 确认源类型为 void*，目标类型与分配大小匹配 |
| `static_cast` 数值类型转换 | 算术类型之间的 static_cast 为标准定义行为（如 int→double、size_t→int），非指针转换 | 确认转换双方均为算术类型或枚举类型 |
| 位运算的 `reinterpret_cast<intptr_t>` | 标记指针（tagged pointer）等底层编程模式，将指针转为整数以存储额外信息 | 确认通过 reinterpret_cast 转为 uintptr_t/intptr_t 后仅做位运算，使用前转回原类型 |
| 相同大小的平凡类型互转 | 两种 POD 类型大小相同、对齐相同、无虚函数，static_cast 经由 void* 后行为可预测 | 确认 sizeof(Source) == sizeof(Target) 且两者均为 trivially copyable |
| dynamic_cast 失败后有空指针检查 | 运行时检查保护，类型不匹配时走错误处理分支 | 确认 dynamic_cast 返回值与 nullptr 比较后才使用 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# C 风格函数指针转换
\(void\s*\*?\(\*\)\)                                 # C风格函数指针cast
                                                     # → MUST: code_context (cast表达式+类型定义)
                                                     # → MUST: judgment_rationale (内存布局兼容性分析)

# reinterpret_cast 暴力转换
reinterpret_cast<(?!.*char\*|.*void\*|.*uintptr_t|.*intptr_t)  # 非底层用途的 reinterpret_cast
                                                     # → SHOULD: data_flow_path (类型擦除→恢复路径)

# 无虚函数的 static_cast 向下转换
static_cast<Derived\*>.*base_ptr                    # 向下转换
→ Base 类无 virtual 析构函数                         # 无虚函数 = 无RTTI → 不安全
                                                     # → MAY: variable_state (运行时实际类型)

# C风格指针类型转换（非void*）
\([A-Za-z_]\w*\s*\*+\)\s*[&*]?\w+                   # C风格指针cast，非void*互转

# === EXCLUDE (不报告) ===
→ dynamic_cast<                                     # 运行时类型检查
→ static_cast<int|static_cast<long|static_cast<float|static_cast<double  # 算术类型转换
→ static_cast<void\*|static_cast<char\*              # 合法类型擦除/字节访问
→ reinterpret_cast<uintptr_t|reinterpret_cast<intptr_t  # 标记指针模式
→ \(void\s*\*\)                                     # 合法的 void* 转换（如 malloc 包装）
→ \(char\s*\*\)|\(unsigned\s+char\s*\*\)            # 字节级访问（序列化/网络IO）
→ \(const\s+.*\)                                    # const 添加（非 cast 问题）
→ 转换后立即 dynamic_cast 验证                        # 有运行时检查的下转换
```
