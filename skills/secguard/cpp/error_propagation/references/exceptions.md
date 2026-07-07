# 错误传播 — 边缘情况抑制

## 抑制条件

以下情况应降低 confidence 或标记为 intentional：

| 条件 | 适用 API | 处理 |
|------|---------|------|
| `checked_malloc` 包装（内部 exit） | malloc | 包装函数保证不返回 NULL → 不标记 |
| `xmalloc` / `MALLOC` 宏 | malloc | 知名模式（xmalloc 封装内含 abort）→ 跳过 |
| `assert(fd > 0)` 在前 | open/fopen | assert 仅在 Debug 检查 → Release 模式无保护，标记但 confidence: medium |
| 返回值被检查且代码路径明确处理错误 | 所有 | 同函数内无后续使用 → 不标记 |
| `std::vector` / `std::string` 内部 alloc | malloc | STL 内部的内存分配不可控 → 不标记 |
| `throw` 替代返回值检查 (C++) | 所有 | 如果函数体用 `throw` 传递分配失败而非返回值 → 需检查调用者有无 catch |
| `new` 而非 `new (std::nothrow)` | operator new | 默认 new 抛出 bad_alloc → 不需要 NULL 检查 |
| read/write 调用在 retry 循环中 | read/write | `while ((n = read(fd, buf, sz)) > 0)` 是正确模式 |
| close 返回值在 shutdown 路径 | close | `close(fd)` 出错时通常 log 即可（已无法恢复）→ 标记但 low severity |
| 返回值被赋值给未使用的局部变量 | 所有 | 值被忽略（写了等于没写）→ 等效于 (void)casting，仍标记 |

## 忽略注释

```c
// secguard:error-propagation-ignore
// secguard:ignore[unchecked-fopen]
// secguard:ignore[unchecked-malloc]
// NOLINTNEXTLINE(concurrency-*)
```

## assert 的局限性

```c
FILE *fp = fopen(path, "r");
assert(fp != NULL);     // Debug 模式通过; Release (NDEBUG) 时 assert 消失
fread(buf, 1, n, fp);  // Release 模式: fread(NULL) → crash
```

即使有 assert，标记 confidence 但降低 severity：使用 `assert` 而非运行时检查 → 是已知的防御性编程弱习惯，但风险取决于发布模式。

## C++ 异常安全

```cpp
// C++ 中使用异常可以不显式检查:
auto fp = std::make_unique<FileReader>(path);  // 构造可能抛异常
fp->read();

// 但如果检查通过 if/else 实现:
if (auto fp = FileReader::open(path)) {
    fp->read();
} else {
    // 错误已处理 — 正确
}
```

在纯 C++ 项目中，使用异常机制的代码不应被此检测器标记，除非模式明显是 C 风格（如构造函数内部 fopen 后不检查）。
