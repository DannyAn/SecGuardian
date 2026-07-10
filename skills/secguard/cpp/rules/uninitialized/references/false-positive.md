> **定位**: 抑制决策树 — 回答"LLM 报告了未初始化，但实际安全时怎么办" | **加载时机**: Phase 2c Counter Evidence | **消费方**: Judge (Step 7)

# 未初始化内存 — 误报抑制规则

## 抑制决策树

```
检测到 struct_inits[partial_init/no_init] 或 variable_writes[read_before_write]
    │
    ├── 分配方式检查
    │   ├── calloc / memset → SUPPRESS（已归零）
    │   ├── 全局/static 变量 → SUPPRESS（.bss 归零）
    │   ├── = {0} / = {} 声明 → SUPPRESS（全字段归零）
    │   └── malloc / 栈声明 → 继续检查
    │
    ├── 字段使用检查
    │   ├── 未初始化字段从未被读取 → DOWNGRADE to informational
    │   ├── 未初始化字段仅传给 memset → SUPPRESS
    │   └── 未初始化字段被读取 → 继续检查
    │
    ├── 字段类型检查
    │   ├── 未初始化的字段为 int/char（非指针）→ 降级 severity
    │   ├── 未初始化的字段为函数指针/data指针 → 保持 severity
    │   └── 未初始化的字段仅用于日志/调试输出 → SUPPRESS
    │
    └── 编译保护检查
        ├── -ftrivial-auto-var-init=zero → SUPPRESS (栈自动归零)
        ├── -fsanitize=memory → 不抑制（运行时检测到则确认）
        └── valgrind 报告已确认 → 不抑制
```

## 已知安全模式

### 1. calloc 归零

```c
// SUPPRESS: calloc 将所有字段初始化为零
struct Config *cfg = (struct Config *)calloc(1, sizeof(struct Config));
cfg->path = strdup("/etc/app");
// cfg->debug_level 为 0（calloc 归零），安全
```

### 2. memset 整体初始化

```c
// SUPPRESS: memset 将所有字节置零
struct Buffer *buf = (struct Buffer *)malloc(sizeof(struct Buffer));
memset(buf, 0, sizeof(struct Buffer));
buf->size = 1024;
// 其他字段为 0（memset 保证），安全
```

### 3. 声明时初始化

```c
// SUPPRESS: = {0} 将所有字段归零
struct Request req = {0};
req.client_ip = get_ip();
// 其他字段为 0，安全

// SUPPRESS: 指定初始化器覆盖所有字段
struct Point p = {.x = 10, .y = 20};
```

### 4. 全局/静态变量

```c
// SUPPRESS: 全局变量在 .bss 段自动归零
static struct Config g_cfg;
g_cfg.path = "/etc/app";
// g_cfg.flags = 0（bss 保证），安全
```

### 5. 编译器自动初始化

```c
// SUPPRESS: Clang/GCC 14+ -ftrivial-auto-var-init=zero
// 启用此选项后，所有栈变量自动归零
void foo() {
    int x;          // 编译器自动初始化为 0
    struct S s;     // 编译器自动初始化为 0
}
```

## C++ RAII 模式

```cpp
// SUPPRESS: 构造函数初始化所有成员
struct Config {
    std::string path;
    int flags = 0;
    int debug_level = 0;
    Config() : path("/etc/app") {}
};
Config cfg;  // 所有成员已初始化

// SUPPRESS: std::make_unique with value init
auto cfg = std::make_unique<Config>();
```

---

## 参考资料

- SEI CERT C: EXP33-C (Do not read uninitialized memory)
- CWE-457: Use of Uninitialized Variable
- CWE-908: Use of Uninitialized Resource
- Clang: -ftrivial-auto-var-init=pattern|zero (since Clang 8)
