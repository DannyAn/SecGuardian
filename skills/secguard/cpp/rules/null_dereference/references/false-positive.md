# 空指针解引用假阳性抑制策略 (False Positive Suppression)

## 已知安全包装抑制

### 1. xmalloc 风格的 OOM 处理

在项目中识别并注册已知安全的分配包装函数。通常在 index.json 的 `safe_allocators` 中声明：

```json
{
  "safe_allocators": ["xmalloc", "xcalloc", "xrealloc", "safe_malloc"]
}
```

检测器在信号预筛阶段先检查分配函数是否在安全列表内 → 是则跳过。

### 2. 类型/概念推导抑制

```c
// SUPPRESS: 自定义 new 表达式（C++ 中 throw bad_alloc）
struct Foo *p = new Foo();       // 默认 new 抛异常，永不返回 NULL
p->bar();                        // 安全（除非用 nothrow new）

// SUPPRESS: placement new
new (buf) Foo();                 // 在已有缓冲区构造
```

### 3. 条件编译下的分配

```c
// SUPPRESS IF: #define DEBUG 时无 NULL 检查非问题
#ifdef DEBUG
    char *trace = malloc(1024);
    // debug 模式无 NULL 检查通常用于简化代码
    trace[0] = 0;
#endif
```

## 控制流假阳性

### 1. 间接 NULL 保证

```c
// SUPPRESS: 通过早期 return 隐含保证
char *p = malloc(1024);
if (!p) return -1;
// 以下所有代码都在 p 非 NULL 的路径上
do_work(p);

// SUPPRESS: goto error 模式
char *p = malloc(1024);
if (!p) goto oom;
p[0] = 'a';    // 安全
return 0;
oom:
    log("OOM");
    return -1;
```

### 2. switch/ternary 模式

```c
// SUPPRESS: ternary 保护
char *p = malloc(1024);
char *q = p ? p : fallback_buffer;
q[0] = 'a';  // 无论 q 来自 p 还是 fallback，都是有效的

// SUPPRESS: switch fallthrough 保证
p = malloc(n);
switch (state) {
    case INIT:
        if (!p) return -1;
        // fallthrough
    case READY:
        p[0] = 'a';  // INIT 已检查，READY 继承保证
        break;
}
```

## 抑制决策树

```
发现 malloc/calloc/realloc 调用点
├─ 调用函数在 safe_allocators 列表中 → SUPPRESS (high)
├─ 返回值赋给变量 p
│  ├─ 之后立即有 (p == NULL) 或 (!p) 检查
│  │  ├─ 检查后 return/exit/abort → SUPPRESS (high)
│  │  ├─ 检查后 goto error（error 释放/返回）→ SUPPRESS (high)
│  │  └─ 检查后空语句 / TODO 注释 → CONFIRM (medium)
│  ├─ 之后有 assert(p != NULL)
│  │  ├─ DEBUG 下 / NDEBUG 未定义 → SUPPRESS (medium)
│  │  └─ NDEBUG 已定义 → CONFIRM (high)
│  └─ 之后无任何检查 → 查解引用点
│     ├─ 解引用在分配后 1 行内，且为极小分配 ≤ 8 bytes → SUSPICIOUS (low)
│     ├─ 解引用通过传入子函数（深度 1）
│     │  ├─ 子函数有 NULL 检查 → SUPPRESS
│     │  └─ 子函数无 NULL 检查 → CONFIRM (high)
│     └─ 直接解引用 → CONFIRM (critical)
└─ 返回值未赋值（void 转换或丢弃）
   └─ 可能是 calloc 用于 clearing side effects → SUSPICIOUS (low)
```

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
