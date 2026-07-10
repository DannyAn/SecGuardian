> **定位**: 跨函数分析指导 — 回答"未初始化内存跨函数传递时怎么分析？" | **加载时机**: Phase 2b Investigator (W4 跨函数补证) | **消费方**: Investigator (Step 5)

# 未初始化内存 — 跨函数分析

## 分析边界

跨函数深度限制为 1（超出降级为 suspicious）。仅在以下场景中进行跨函数追踪。

## 场景 1: 结构体指针传出（return/out param）

```c
// 被调用者：分配并部分初始化
struct Config *create_config() {
    struct Config *cfg = malloc(sizeof(struct Config));
    cfg->path = "/etc/app";    // 仅初始化 path
    // cfg->flags 未初始化
    return cfg;                 // 传出：调用者收到部分初始化的结构体
}

// 调用者：直接使用
void main() {
    struct Config *c = create_config();
    if (c->flags & O_RDWR) {}  // ← 使用未初始化字段 — 跨函数 depth=1 可追踪
}
```

**分析规则**: 如果 create_config 中 `struct_inits[cat="partial_init"]` 且调用者直接使用 `->field`，确认 CONFIRMED。如果调用者先设置所有缺失字段再使用，SUPPRESS。

## 场景 2: 结构体值传递（by-value）

```c
void init_partial(struct Request req) {
    req.client_ip = get_ip();
    // req.method 未初始化，但按值传递不影响调用者
}

void caller() {
    struct Request req = {0};  // 调用者已全字段归零
    init_partial(req);         // 按值传递，调用者不受影响 — SUPPRESS
}
```

## 场景 3: 初始化函数（wrapper init）

```c
// GOOD: 专门的初始化函数覆盖所有字段
void config_init(struct Config *cfg) {
    memset(cfg, 0, sizeof(*cfg));
    cfg->path = "/etc/app";
    cfg->flags = O_RDONLY;
}

// 调用者：通过初始化函数保证完整性
void main() {
    struct Config cfg;
    config_init(&cfg);  // SUPPRESS: 初始化函数覆盖所有字段
    use(&cfg);
}
```

**分析规则**: 如果分配/声明后立即传给初始化函数，且该函数覆盖了所有字段，SUPPRESS。仅部分覆盖 → CONFIRMED。

## 场景 4: 回调函数中访问

```c
void register_handler(void (*cb)(struct Data *)) {
    struct Data d;             // 未初始化
    d.callback_data = get_data();
    cb(&d);                    // 回调中可能读取未初始化字段
}
```

**分析规则**: depth=1，追踪回调接收的结构体类型与声明时的字段覆盖差异。高不确定度 → SUSPICIOUS。

## 追踪信号映射

| 调用侧模式 | 跨函数信号 | 分析动作 |
|-----------|-----------|---------|
| `f = create_xxx()` | 返回值类型含未初始化字段 | 追踪调用者是否在使用前补全 |
| `init_xxx(&s)` | 参数指针，被调用者部分写入 | 检查被调用者覆盖了哪些字段 |
| `callback(&s)` | 回调接收未初始化结构体 | 标记 SUSPICIOUS，需人工确认 |
| `return &s` (栈) | 返回栈地址 + 未初始化 | 确认为 CONFIRMED（return stack addr 本身是 UAF） |

## 参考资料

- SEI CERT C: EXP33-C (跨函数未初始化追踪)
- CWE-457: 跨函数 uninitialized variable 传播
