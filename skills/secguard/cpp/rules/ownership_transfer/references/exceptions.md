> **定位**: 定义哪些看似所有权转移的场景实际是安全的管理模式 | **加载时机**: Phase 2c Counter Evidence | **消费方**: Judge (Step 7)

# 所有权转移例外规则

## 安全模式（不报告）

1. **realloc 是唯一使用者**: `p = realloc(p, new_size);` — 标准惯用模式，安全
2. **释放后立即 NULL**: `free(p); p = NULL;` → 后续使用安全（无解引用）
3. **移动后不访问**: `auto b = std::move(a);` 且后续代码不访问 `a` → 安全
4. **引用计数管理**: 对象由引用计数控制，释放由计数决定 → 不视为所有权转移问题
5. **RAII 包装**: 指针由 `std::unique_ptr` / `std::shared_ptr` 管理 → 不报告

## C++ 所有权语义（不报告）

以下 C++ 现代所有权模式是类型安全的所有权转移，**不报告**：

### 1. std::move 转移所有权

```cpp
// 安全：std::move 明确表达所有权转移意图
std::unique_ptr<Resource> create_resource() {
    auto res = std::make_unique<Resource>();
    res->initialize();
    return res;  // 隐式 move，所有权转移给调用者
}

void consume(std::unique_ptr<Resource> res) {
    res->finalize();
}  // 自动释放：unique_ptr 析构

// 安全：std::move 后源对象明确不再使用
auto a = std::make_unique<Resource>();
auto b = std::move(a);
// a 为 nullptr，后续使用 a.get() 返回 nullptr（安全）
```

### 2. 引用计数共享所有权

```cpp
// 安全：shared_ptr 自动管理引用计数
std::shared_ptr<Resource> res = std::make_shared<Resource>();
{
    auto res2 = res;  // refcount 变为 2
    res2->use();
}  // refcount 变为 1，不释放
res->use();  // 安全：资源仍有效
```

### 3. 仅移动类型（Move-Only Types）

```cpp
// 安全：编译期保证不会出现双重释放或使用后释放
std::unique_ptr<Resource> a = std::make_unique<Resource>();
// std::unique_ptr<Resource> b = a;  // 编译错误：不可复制
std::unique_ptr<Resource> b = std::move(a);  // 仅移动，编译器保证 a 不可再访问
```

### 4. 工厂函数返回（隐式所有权转移）

```cpp
// 安全：工厂函数返回 unique_ptr，所有权明确转移
std::unique_ptr<Connection> connect(const char *url) {
    auto conn = std::make_unique<Connection>(url);
    if (!conn->open()) return nullptr;  // 异常路径：所有权不泄漏
    return conn;  // 正常路径：所有权转移
}
```

## 边界情况

1. **`realloc(p, 0)` 行为**: 标准未定义（类 free 行为在部分实现）→ 标记为 suspicious
2. **C 风格接收者函数**: `list_add(list, item)` 后调用者继续使用 item（取决于 list 实现）→ 降级为 suspicious
3. **自定义分配器**: 使用 arena 分配器的场景 → 所有权由 arena 管理，非传统释放模式
4. **Rust/C++ 互操作所有权**: 通过 `Box::into_raw()` / `Box::from_raw()` 跨越 FFI 边界 → 检查配对调用是否完整

## CWE 映射

| CWE | 说明 | 本规则覆盖 |
|-----|------|-----------|
| CWE-416 | Use After Free | 所有权转移后使用 |
| CWE-415 | Double Free | 重复释放（所有权不清） |
| CWE-772 | Missing Release of Resource | 所有权未转移导致泄漏 |
| CWE-911 | Improper Update of Reference Count | 引用计数管理错误 |

## SEI CERT C++ 参考

- **MEM50-CPP**: Do not access freed memory
- **MEM51-CPP**: Properly deallocate dynamically allocated resources
- **MEM56-CPP**: Do not store an already-owned pointer value in an unrelated smart pointer (CWE-415/CWE-416风险)
- **MEM57-CPP**: Avoid using default operator new for over-aligned types
