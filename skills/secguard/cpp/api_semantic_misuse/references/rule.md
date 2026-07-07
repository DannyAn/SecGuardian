# API 语义误用 — 脆弱模式与安全模式

## realloc(p, 0)

**脆弱模式**:

```c
// 结果不可移植: 释放 vs 分配零字节对象取决于实现
ptr = realloc(ptr, 0);
```

**安全模式**:

```c
free(ptr);
ptr = NULL;
```

**争议点**: C23 将 realloc(p, 0) 的行为定义为明确等同于 `free(p)`。对于声明使用 C23 的项目可降级。

## snprintf 返回值忽略

**脆弱模式**:

```c
snprintf(buf, sizeof(buf), "%s", user_input);
// buf 内容可能被截断，后续使用截断后的 buf 无感知
```

**安全模式**:

```c
int n = snprintf(buf, sizeof(buf), "%s", user_input);
if (n < 0 || (size_t)n >= sizeof(buf)) {
    // 处理错误或截断 — 至少不静默使用截断数据
    buf[sizeof(buf) - 1] = '\0';
    return -1;
}
```

**变量长度场景** — 需额外检查:

```c
int n = snprintf(buf, sizeof(buf), "%s %d", a, b);
// 即使格式固定，C 标准库实现也可能因 locale 设置导致 snprintf 返回 > sizeof(buf)
```

## strncpy 未 null-terminate

**脆弱模式**:

```c
char buf[32];
strncpy(buf, source, sizeof(buf));
// 当 strlen(source) >= 32 时, buf 不包含 '\0' 终止符
puts(buf);  // UAF-like: 读到栈上未定义字节
```

**安全模式**:

```c
char buf[32];
strncpy(buf, source, sizeof(buf) - 1);
buf[sizeof(buf) - 1] = '\0';
```

**C11 替代**:

```c
strncpy_s(buf, sizeof(buf), source, _TRUNCATE);
```

## memcpy 重叠区域

**脆弱模式**:

```c
// 源和目标在同一 buffer 且移动方向导致重叠
memcpy(&arr[1], &arr[0], n);
```

**安全模式**:

```c
// memmove 保证起始地址任意顺序都可正常工作
memmove(&arr[1], &arr[0], n);
```

**例外**: 当重叠方向已知且安全（如从高地址向低地址移动且 dst < src）时，memcpy 可以被正确使用。但这种分析（prove non-overlapping）需要严格别名分析，超出简单检查范围。一律推荐 memmove。

## memset 大小错误

**脆弱模式**:

```c
void clear(struct mytype *p) {
    memset(p, 0, sizeof(p));  // sizeof pointer, not sizeof struct
}
```

**安全模式**:

```c
void clear(struct mytype *p) {
    memset(p, 0, sizeof(*p));
}
```

**数组参数传递**:

```c
// 数组退化为指针 — sizeof(arr) 不可靠
void clear_buf(char buf[], size_t len) {
    memset(buf, 0, len);  // len 必须由 caller 传入
}
```

## `_s` 变体扩展

| 标准函数 | `_s` 替代 | 附加语义检查 |
|---------|-----------|-------------|
| `strcpy` | `strcpy_s` | 目标大小参数检查和运行时约束处理 |
| `memcpy` | `memcpy_s` | 重叠检测（运行时返回错误而非 UB） |
| `scanf` 系列 | `scanf_s` | 缓冲区大小作为额外参数 |

**`_s` 函数的常见误用**:

```c
// 脆弱: 参数顺序与原始函数不同
strcpy_s(dst, sizeof(dst), src);   // OK: 标准签名 (dst, dst_size, src)
// 但如果写为:
strcpy_s(dst, src, sizeof(dst));   // BUG: size 位置在 src 参数位上

// 脆弱: 传递 0 作为大小 → 无操作，但其他 _s 函数行为不一致
strcpy_s(dst, 0, src);  // 运行时机约处理返回 EINVAL
```

## 工具辅助

```bash
# 用 cppcheck 初步筛选
cppcheck --enable=warning,style --suppress=*:test/* src/
# 在 CI 中用 gcc -D_FORTIFY_SOURCE=3 检测部分运行时误用
```
