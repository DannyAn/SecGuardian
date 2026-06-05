---
detector: bad-cast
severity: medium
cwe: CWE-704
language: [c, cpp]
tags: [memory, type-safety, undefined-behavior]
---

# 不安全的类型转换 (Bad Cast)

## 威胁定义

不兼容类型之间的强制转换导致未定义行为或类型混淆。C 风格 cast `(Type)val` 绕过编译器类型检查，`reinterpret_cast` 放弃类型安全。类型混淆可导致虚函数表劫持（vtable hijacking）。

**核心原则：C++ 代码使用 `static_cast`/`dynamic_cast`，禁止 `reinterpret_cast` 的非必要使用。C 代码使用显式 union 而非指针 cast。**

## 检测逻辑

### Step 1: 搜索 C 风格转换

```c
// BAD: 函数指针与对象指针互转
void (*fp)() = (void(*)())obj_ptr;
fp();                            // 未定义行为

// BAD: 指针与整数互转
int addr = (int)ptr;             // 可能截断（64 位系统）
void *p2 = (void*)addr;
```

### Step 2: 检查 reinterpret_cast (C++)

```cpp
// BAD: 不相关的类型互转
struct A { int x; };
struct B { double y; };
A* a = new A;
B* b = reinterpret_cast<B*>(a);  // 严格别名违规
b->y = 3.14;                     // 未定义行为
```

### Step 3: 向上/向下转换安全 (C++)

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

## 修复指引

1. **C++**：使用 `static_cast`（编译期类型检查）/ `dynamic_cast`（运行时检查）
2. **禁止**：`reinterpret_cast` 用于非底层编程场景
3. **C 代码**：使用显式 `union` 而非指针 cast 做类型双关（type punning）
4. **编译器警告**：启用 `-Wold-style-cast` (GCC) / `-Wdeprecated` 检测 C 风格 cast

## 误报排除

| 场景 | 原因 |
|------|------|
| `dynamic_cast` 向下转换 | 运行时类型检查 |
| void\* → T\* 的合法转换 | 常见模式（如 malloc 包装） |
| `static_cast` 数值类型转换 | 标准定义的行为 |
| 位运算的 `reinterpret_cast<intptr_t>` | 合法用途（如标记指针） |

## 检测模式汇总

```
# C 风格函数指针转换
\(void\s*\*?\(\*\)\)

# reinterpret_cast 暴力转换
reinterpret_cast<(?!.*char\*|.*void\*|.*uintptr_t|.*intptr_t)

# 无虚函数的 static_cast 向下转换
static_cast<Derived\*>.*base_ptr  # 且 base 类无 virtual 析构
```
