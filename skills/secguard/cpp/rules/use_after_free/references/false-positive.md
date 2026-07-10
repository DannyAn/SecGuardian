> **定位**: 区分真正的 use-after-free 与误报场景的判别逻辑 | **加载时机**: Phase 2c Counter Evidence | **消费方**: Judge (Step 7)

# 释放后使用误报抑制策略

## 抑制规则

1. **赋值后使用**: free 和 deref 之间有 `p = new_value` 赋值 → 抑制
2. **智能指针包装**: 通过智能指针间接访问 → 抑制
3. **数组索引变化**: `free(arr); arr = new_arr; arr[0] = x;` → arr 已更新，安全
4. **线程退出标志**: `free(ctx); ctx->running = 0;` → 如果 ctx->running 在 free 前已被读取，释放后写可能是无害的（但 UB），降级为 suspicious

## 常见误报

1. **统计计数**: `free(p); counter--;` — 仅计数，非指针解引用
2. **日志输出文件名**: `free(buf); log("freed %s", filename);` — filename 非指针变量
3. **地址打印**: `free(p); printf("ptr was %p", (void*)p);` — 仅打印地址值，非解引用
4. **false 路径**: `free(p); if (cond) { p->x = 1; }` — cond 在 free 后必然为 false → 不可达

---

## C++ RAII (Resource Acquisition Is Initialization) 模式

在 C++ 代码或 C 代码中使用 RAII 风格管理资源时，以下模式是安全的，**不得标记为漏洞**：

### 1. 构造函数分配 + 析构函数释放

当资源在构造函数/工厂函数中获取，并由配对的 destroy/release 函数管理生命周期时：

```c
// SUPPRESS: 工厂函数返回分配的资源，调用者通过配对的 destroy 函数释放
ResourceHandle *ResourceHandle_create(size_t size) {
    ResourceHandle *h = (ResourceHandle *)malloc(sizeof(ResourceHandle));
    h->data = malloc(size);  // 安全：ResourceHandle_destroy 负责释放
    h->size = size;
    h->owned = 1;
    return h;
}
void ResourceHandle_destroy(ResourceHandle *h) {
    if (h && h->owned) {
        free(h->data);
        h->data = NULL;
        h->owned = 0;
    }
    free(h);
}
// 用法：process_buffer() 中 create → use → destroy 是完整的 RAII 模式
```

构造函数中的 NULL 检查缺失由 create/destroy 契约管理——调用者负责检查返回值。

### 2. 智能指针所有权

```cpp
// SUPPRESS: unique_ptr 保证单次删除
std::unique_ptr<Resource> ptr = std::make_unique<Resource>();
ptr->use();  // 安全

// SUPPRESS: shared_ptr 保证引用计数后删除
std::shared_ptr<Resource> ptr = std::make_shared<Resource>();
```

### 3. Scope Guard 和自定义删除器

C 风格资源使用 RAII 包装器：

```cpp
// SUPPRESS: 自定义删除器保证 fclose
struct FileCloser { void operator()(FILE* f) { if (f) fclose(f); } };
std::unique_ptr<FILE, FileCloser> file(fopen("x", "r"));
```

```c
// SUPPRESS: GCC cleanup attribute 保证作用域退出时释放
__attribute__((cleanup(free_ptr))) char *buf = malloc(128);
```

### 抑制规则

如果以下任何一项成立，抑制 null_dereference / use_after_free / double_free / memory_leak / resource_leak 的 finding：

- 资源在堆栈对象的构造函数/工厂函数中获取，在配对的 destroy/release 中释放
- 资源由 unique_ptr、shared_ptr 或具有自定义删除器的等价物持有
- 资源作用域与 `}` 后的栈展开（GCC cleanup 属性）或 C++ 析构函数严格关联
- create/destroy 配对函数在同一翻译单元中定义，destroy 函数处理了所有释放路径
