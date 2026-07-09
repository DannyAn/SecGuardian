# API 语义误用 — 跨函数追踪

## 追踪规则

对本检测器的步进（Step 4），最大深度为 1 级。具体做法：

1. 在 `call_graph.edges` 中查找当前函数（API 调用发生的函数）的 reverse edges
2. 对每个在 `symbols.functions` 中有定义的 caller，读取其函数体 ±5 行
3. 检查 caller 传递的参数是否通过包装函数原样透传

## 常见包装模式

### 模式 A: 简单透传

```c
// caller 中:
my_secure_copy(buf, sizeof(buf), user_input);

// 被检测函数:
void my_secure_copy(char *dst, size_t sz, const char *src) {
    strncpy(dst, src, sz);       // 此处是 strncpy 调用点
    // dst[sz-1] = '\0';         // 如果没有这行 → 标记
}
```

检查 caller 传的 `sz` 是否与 `sizeof(dst)` 一致。如果 caller 传 `strlen(src) + 1` 而不是 `sizeof(dst)`，则应标记。

### 模式 B: realloc 封装

```c
// caller 中:
resize_buffer(&buf, 0);

// 被检测函数:
void resize_buffer(void **p, size_t new_size) {
    *p = realloc(*p, new_size);  // realloc(p, 0)
}
```

如果 `resize_buffer` 语义明确包含 "free" 模式（size=0 表示释放）→ 不标记。需要检查函数名和注释。

### 模式 C: snprintf 包装

```c
// caller 中:
log_message(buf, sizeof(buf), "user=%s", getenv("USER"));

// 被检测函数:
void log_message(char *buf, size_t sz, const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sz, fmt, args);  // 返回值被忽略
    va_end(args);
}
```

如果包装函数始终在返回后立即使用 `buf`（如写入日志文件），则忽略返回值仅在输入不受信任时是问题。检查 caller 是否在之后检查 `buf` 内容或 `strlen(buf)`。

## 数据流追踪策略

对于参数来源，只追踪连续赋值链：

```c
// 需要追踪: 赋值链在同一个函数内
size_t n = sizeof(struct Foo);
clear_memory(ptr, n);  // n 来自 sizeof(struct Foo)
```

```c
// 需要追踪: 参数来自全局/结构体成员（深度限制 1 级）
void init(struct config *cfg) {
    memset(buffer, 0, cfg->buf_size);
    // 检查 cfg->buf_size 的初始化赋值点 → 如果 config 来自外部输入则标记
}
```

```c
// 不需要追踪: 深度超过 1 的间接赋值
void foo() {
    int *size = get_size_ptr();  // 需要再调一个函数才能得到值
    memset(buf, 0, *size);
    // → 超出深度限制，若不能从上下文确定 size 值，标记但 confidence: low
}
```

## 对 `_s` 包装的 reverse 检查

```c
// 标准 strcpy_s 签名: errno_t strcpy_s(char *dest, rsize_t destsz, const char *src);
// 如果调用者错误地交换了参数:
wrapper(dst, src, sizeof(dst));

void wrapper(char *d, const char *s, size_t sz) {
    strcpy_s(d, sz, s);  // 此处 sz 和 s 顺序与标准不同
    // 但检查 caller 传参可知是正确映射 → 不标记
}
```
