> **定位**: 安全排除规则 — 回答"什么情况下 memory.uninitialized 不适用？" | **加载时机**: Phase 2c Counter Evidence | **消费方**: Judge (Step 7)

# 未初始化内存 — 例外规则

## 安全模式（不报告）

### 1. calloc 归零

`calloc` 将所有字节初始化为零，后续即使只显式设置部分字段，其余字段也是安全的零值。

```c
// SUPPRESS: calloc 将所有字段归零
struct Config *cfg = calloc(1, sizeof(struct Config));
cfg->path = strdup("/etc/app");  // cfg->flags=0, cfg->debug=0 (calloc 保证)
```

### 2. memset/bzero 整体初始化

```c
// SUPPRESS: memset 将整个结构体置零
struct Buffer *buf = malloc(sizeof(struct Buffer));
memset(buf, 0, sizeof(struct Buffer));
buf->size = 1024;  // 其他字段为 0，安全
```

### 3. C99 指定初始化器

```c
// SUPPRESS: 指定初始化器覆盖所有字段，其余归零
struct Point p = {.x = 10, .y = 20};
// p.z = 0（指定初始化器保证）
```

### 4. 声明时 `= {0}` 或 `= {}`

```c
// SUPPRESS: 所有字段归零
struct Request req = {0};
```

### 5. 全局/静态变量（.bss 段自动归零）

```c
// SUPPRESS: 全局变量在 .bss 段，自动初始化为 0
static struct Config g_cfg;
// g_cfg 的所有字段为 0
```

### 6. 编译器自动初始化

Clang/GCC 14+ 支持 `-ftrivial-auto-var-init=zero` 或 `pattern`，将所有栈变量自动初始化。

```c
// SUPPRESS: 编译器选项保证初始化
// $ cc -ftrivial-auto-var-init=zero
void foo() {
    int x;  // 编译器自动初始化为 0
}
```

### 7. MSan/Valgrind 已确认

如果运行时检测工具（MemorySanitizer、Valgrind）已标记但开发团队已评估为"不可利用"，降级为 informational。

### 8. C++ 构造函数

```cpp
// SUPPRESS: 构造函数初始化所有成员
struct Config {
    std::string path;
    int flags = 0;
    Config() : path("/etc/app") {}  // flags 通过类内初始值初始化
};
```

## 参考资料

- SEI CERT C: EXP33-C — Do not read uninitialized memory
- CWE-457: Use of Uninitialized Variable
- CWE-908: Use of Uninitialized Resource
- Clang: -ftrivial-auto-var-init (since Clang 8)
- Linux kernel: CONFIG_INIT_STACK_ALL_ZERO
