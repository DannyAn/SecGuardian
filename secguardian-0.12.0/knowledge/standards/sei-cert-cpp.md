---
category: standards
standard: SEI CERT C++
version: "2017"
rules_count: 90+
mapped_detectors: 22
---

# SEI CERT C++ 编码标准 → SecGuardian Detector 映射

> 来源: [SEI CERT C++ Coding Standard](https://wiki.sei.cmu.edu/confluence/pages/viewpage.action?pageId=88046682)

## 规则映射

### 01. 声明和初始化 (DCL)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| DCL50-CPP | 不要定义 C 风格的可变参数函数 | format-string | ⚠️ 相关 |
| DCL53-CPP | 不要使用 `reinterpret_cast` | bad-cast | ✅ 完全 |
| DCL55-CPP | 避免在构造/析构中调用虚函数 | — | ❌ 未覆盖 |
| DCL57-CPP | 不要为异常抛出 new | — | ❌ 未覆盖 |
| DCL58-CPP | 不要修改标准命名空间 | — | ❌ 未覆盖 |
| DCL59-CPP | 不要在头文件的全局命名空间中 using | — | ❌ 未覆盖 |
| DCL60-CPP | 遵守 Single Definition Rule | — | ❌ 未覆盖 |

### 02. 表达式 (EXP)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| EXP50-CPP | 不要依赖求值顺序的副作用 | race-condition | ⚠️ 部分 |
| EXP51-CPP | 不要通过悬空引用访问对象 | use-after-free | ✅ 完全 |
| EXP53-CPP | 不要读取未初始化的内存 | uninitialized-memory | ✅ 完全 |
| EXP54-CPP | 不要访问已离开作用域的对象 | use-after-free | ⚠️ 部分 |
| EXP55-CPP | 不要通过无效指针访问对象 | null-dereference | ✅ 完全 |
| EXP56-CPP | 不要调用抛出与异常规范不符异常的函数 | — | ❌ 未覆盖 |
| EXP57-CPP | 不要从析构函数抛出异常 | — | ❌ 未覆盖 |
| EXP60-CPP | 不要在 `dynamic_cast` 后使用可能为空的指针 | null-dereference | ⚠️ 部分 |
| EXP61-CPP | lambda 对象在其捕获的引用销毁后不应使用 | use-after-free | ⚠️ 部分 |
| EXP62-CPP | 不要访问非活跃 union 成员 | — | ❌ 未覆盖 |

### 03. 整数 (INT)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| INT50-CPP | 不要转为超出范围的枚举值 | integer-overflow | ⚠️ 部分 |

### 05. 容器 (CTR)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| CTR50-CPP | 保证容器索引在有效范围内 | buffer-overflow | ✅ 完全 |
| CTR51-CPP | 使用有效的迭代器范围 | buffer-overflow | ⚠️ 部分 |
| CTR52-CPP | 不要在无效迭代器上操作 | use-after-free | ✅ 完全 |
| CTR53-CPP | 不要使用无效的指针或引用 | null-dereference | ✅ 完全 |
| CTR55-CPP | 不要使用已失效的 `std::string::c_str()` | use-after-free | ✅ 完全 |
| CTR56-CPP | 不要将容器传递给期望指针的函数时忽略容量 | buffer-overflow | ✅ 完全 |

### 06. 字符和字符串 (STR)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| STR50-CPP | 保证字符串存储有足够空间 | buffer-overflow | ✅ 完全 |
| STR51-CPP | 不要试图创建空终止字符串 | buffer-overflow | ⚠️ 部分 |
| STR52-CPP | 使用有效的格式字符串 | format-string | ✅ 完全 |
| STR53-CPP | 范围检查字符和字符串操作 | buffer-overflow | ✅ 完全 |

### 08. 内存管理 (MEM)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| MEM50-CPP | 不要访问已释放的内存 | use-after-free | ✅ 完全 |
| MEM51-CPP | 正确释放分配的内存 | mismatched-free, double-free | ✅ 完全 |
| MEM52-CPP | 检测和处理内存分配失败 | null-dereference | ⚠️ 部分 |
| MEM53-CPP | 为 `new`/`new[]` 配对 `delete`/`delete[]` | mismatched-free | ✅ 完全 |
| MEM54-CPP | 使用 `std::unique_ptr`/`std::shared_ptr` 而不是裸指针 | — | ⚠️ 风格 |
| MEM55-CPP | 不要用 `std::move` 后再使用被移动对象 | use-after-free | ⚠️ 部分 |
| MEM56-CPP | 不要通过指向 `free()` 释放的内存使用指针 | use-after-free | ✅ 完全 |
| MEM57-CPP | 使用 `new`/`delete` 和非内存资源 | memory-leak | ✅ 完全 |

### 09. 输入输出 (FIO)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| FIO50-CPP | 不要在 `fopen` 和 `fclose` 之间混用文件流 | — | ❌ 未覆盖 |
| FIO51-CPP | 在使用后关闭文件 | memory-leak | ✅ 完全 |

### 10. 异常 (ERR)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| ERR50-CPP | 不要突然终止程序 | exception-swallow | ⚠️ 部分 |
| ERR51-CPP | 在异常安全代码中正确处理 RAII | memory-leak | ⚠️ 部分 |
| ERR52-CPP | 不要使用异常规范 | — | ❌ 未覆盖 |
| ERR53-CPP | 不要跨模块边界抛出异常 | — | ❌ 未覆盖 |
| ERR55-CPP | 尊重 abort()/terminate() 规范 | — | ❌ 未覆盖 |
| ERR56-CPP | 保证在所有异常情况下资源被释放 | memory-leak | ⚠️ 部分 |
| ERR57-CPP | 不要泄露异常信息 | error-stack-trace-leak | ✅ 完全 |
| ERR58-CPP | 处理 `new` 抛出的 `std::bad_alloc` | — | ❌ 未覆盖 |
| ERR59-CPP | 不要抛出异常类型的指针 | — | ❌ 未覆盖 |
| ERR60-CPP | 异常应该按引用捕获 | — | ❌ 未覆盖 |
| ERR61-CPP | 在 noexcept 函数中捕获异常 | — | ❌ 未覆盖 |
| ERR62-CPP | 检测并处理 IO 错误 | — | ❌ 未覆盖 |

### 14. 并发 (CON)

| CERT Rule | 标题 | SecGuardian Detector | 覆盖状态 |
|-----------|------|---------------------|---------|
| CON50-CPP | 不要对非原子操作的 double-checked locking | race-condition | ✅ 完全 |
| CON51-CPP | 不要在析构函数中使用 mutex | — | ❌ 未覆盖 |
| CON52-CPP | 使用 `notify_all()` 唤醒所有等待线程 | deadlock | ⚠️ 部分 |
| CON53-CPP | 避免在异步信号处理中使用非同步函数 | thread-unsafe-signal | ✅ 完全 |
| CON54-CPP | 使用 `condition_variable` 时要配合 mutex | data-race | ⚠️ 部分 |
| CON55-CPP | 在持有锁时不调用未知代码 | deadlock | ⚠️ 部分 |

### 覆盖统计

| 类别 | 规则数 | 已映射 | 覆盖率 |
|------|--------|--------|--------|
| DCL | 7 | 2 | 29% |
| EXP | 11 | 6 | 55% |
| CTR | 6 | 5 | 83% |
| STR | 4 | 4 | 100% |
| MEM | 8 | 7 | 88% |
| ERR | 12 | 2 | 17% |
| CON | 6 | 4 | 67% |

**总计: 22/54 核心规则已映射 (41%)**
