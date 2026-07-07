# 内存泄漏假阳性抑制策略 (False Positive Suppression)

## 所有权语义抑制

### 1. 基于函数名推断

```c
// SUPPRESS: create/alloc 前缀表示所有权转移
struct User *create_user(const char *name);

// SUPPRESS: get_ 返回非所有权指针
const char *get_name(void);  // 通常返回内部静态或 const

// SUPPRESS: find/lookup/search 返回非所有权引用
struct Node *find_node(int id);  // 可能在树中，不转移所有权
```

**配置方式**:
```json
{
  "ownership_transfer_patterns": {
    "allocator": ["^create_", "^alloc_", "^make_", "^duplicate", "^strdup$", "^new_"],
    "borrow": ["^get_", "^find_", "^lookup_", "^peek_", "^current_"]
  }
}
```

### 2. 基于返回值检查

```c
// SUPPRESS: 指针存入容器（容器负责释放）
ev = malloc(sizeof(*ev));
event_queue_push(queue, ev);  // 队列接管所有权
return;  // 不 free → 正确

// SUPPRESS: 指针赋值给结构体字段
obj->buffer = malloc(1024);
// obj 的析构/清理函数会释放 obj->buffer
```

## 生命周期模式抑制

### 1. 一次性初始化（编译时可验证）

```c
// SUPPRESS: static 局部变量仅在首次调用分配
void ensure_loaded() {
    static char *cache = NULL;
    if (!cache) {
        cache = malloc(1024);
        load_defaults(cache);
    }
    // cache 在进程生命周期内有效
}
```

### 2. 线程局部存储

```c
// SUPPRESS: thread-local 变量
static __thread char *tls_buf = NULL;
void ensure_tls_buffer() {
    if (!tls_buf) tls_buf = malloc(256);
    // 线程结束时由线程清理函数释放
}
```

### 3. 自定义分配器

```c
// SUPPRESS: 使用自定义分配器（在 safe_allocators 中注册）
void *my_alloc(size_t n) {
    static char pool[65536];
    static size_t offset = 0;
    void *p = pool + offset;
    offset += n;
    return p;  // 非堆分配，无需 free
}
```

## 技术抑制

### Alloc-Free 配对可靠性

index.json 的 `alloc_free.pairs` 可能产生假配对或假遗漏：

1. **间接释放**: 通过 `my_free(ptr)` 包装调用 → 需在 safe_free_functions 中注册
```json
{
  "safe_free_wrappers": ["my_free", "buffer_free", "pool_release"]
}
```

2. **释放标记**: `ptr = NULL` 后指针不再可达 → 保守视为已释放
```c
free(ptr);
ptr = NULL;  // SUPPRESS: 双重释放防护，但第一个 free 是真实的
```

## 抑制决策树

```
发现 alloc (malloc/calloc) 在函数 F 中
├─ F 所属文件为 test_* 或 *_test → SUPPRESS (info) [测试允许小泄漏]
├─ 分配在 static/global init 路径上
│  ├─ 进程存续期有效 → SUPPRESS (info)
│  └─ 库的 init/cleanup 模式 → SUPPRESS (high)
├─ 分配在循环中 → 循环内必须有 free
│  ├─ 循环体末尾 free → SUPPRESS (high)
│  └─ 无 free → CONFIRM (high)
├─ 分配在非循环函数中
│  ├─ 函数所有 return 路径检查 free
│  │  ├─ 全部有 free → SUPPRESS (high)
│  │  ├─ 部分有 → 查缺少的路径
│  │  │  ├─ goto cleanup 模式 → SUPPRESS (high)
│  │  │  └─ 直接 return → CONFIRM (high)
│  │  └─ 全部无 free → 看所有权
│  │     ├─ return 该指针 → 查看调用者
│  │     │  ├─ 调用者 free → SUPPRESS
│  │     │  └─ 调用者无 free → CONFIRM (high)
│  │     └─ 不返回指针 → CONFIRM (high)
│  └─ RAII/智能指针 → SUPPRESS (high)
└─ 分配在函数入口，函数类成员
   ├─ 有析构函数释放 → SUPPRESS (high)
   └─ 无析构 / C 风格 → CONFIRM (high)
```
