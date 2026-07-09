# 内存泄漏豁免规则 (Memory Leak Exceptions)

## 所有权转移豁免

以下模式中，分配的内存所有权转移给调用者，不视为泄漏：

```c
// EXCEPTION: create/alloc/new 前缀函数
struct Config *create_config(const char *path) {
    struct Config *cfg = malloc(sizeof(*cfg));
    // ... 初始化 ...
    return cfg;  // 所有权转移给调用者
}
// 调用者负责 free(cfg)

// EXCEPTION: strdup 返回
char *duplicate = strdup(original);  // caller 负责 free

// EXCEPTION: get_ 返回静态或传入指针
const char *get_name(void) {
    static const char *name = "builtin";
    return name;  // 不涉及动态分配
}
```

**判定依据**: 函数名含 `create`、`alloc`、`dup`、`clone`、`new`、`make`、`build` 且返回指针 → 所有权转移。

## 生命周期管理豁免

### 1. 全局/静态指针

```c
// EXCEPTION: 全局唯一分配，进程结束时 OS 回收
static char *global_buf = NULL;
void init() {
    global_buf = malloc(1024);  // 不释放，进程存续期间一直存在
}
```

**注意**: 保守模式下对此类仅标记为 info 级别。仅在进程退出时泄漏少量内存可接受。

### 2. 缓存/池

```c
// EXCEPTION: 对象池，内存被复用
static struct object_pool pool;
void *pool_alloc(size_t size) {
    return pool_get(&pool, size);  // 从池获取，非每次新分配
}
```

### 3. Arena/Region 分配器

```c
// EXCEPTION: 一次性释放全部
void process_frame() {
    Region r = region_create(4096);
    char *buf1 = region_alloc(&r, 100);
    char *buf2 = region_alloc(&r, 200);
    // ... 使用 buf1, buf2 ...
    region_destroy(&r);  // 统一释放全部
    // buf1/buf2 不可单独释放
}
```

## 程序退出豁免

```c
// EXCEPTION（INFO 级别）: main 或线程函数结束时
int main() {
    char *buf = malloc(1024);
    // 使用 buf
    return 0;  // 进程退出，OS 回收。仅标记为 info
}

// NOT AN EXCEPTION: 长期运行服务的循环中泄漏
while (1) {
    char *buf = malloc(1024);
    // 不 free → 进程将持续增长直到 OOM
}
```

## 非豁免情况

```c
// NOT AN EXCEPTION: TODO 注释不构成豁免
char *buf = malloc(1024);
// TODO: free buf later ← 没有 free 调用，标记为泄漏

// NOT AN EXCEPTION: 条件编译释放不可靠
#ifdef CLEANUP
    free(buf);  // 无 CLEANUP 定义时仍泄漏
#endif

// NOT AN EXCEPTION: realloc 多次覆盖
p = malloc(1024);
p = malloc(2048);  // 1024 泄漏
p = malloc(4096);  // 2048 泄漏
free(p);           // 仅释放 4096
```
