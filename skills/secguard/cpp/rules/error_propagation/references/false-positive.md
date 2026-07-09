# 错误传播 — 误报抑制

## 信号级误报抑制

### 1. xmalloc / checked_alloc 惯用语

```c
void *xmalloc(size_t sz) {
    void *p = malloc(sz);
    if (!p) {
        perror("xmalloc");
        exit(EXIT_FAILURE);    // 保证不返回
    }
    return p;
}
```

**检测**: 如果分配函数有配套的 "不返回 NULL" 包装，且该包装通过 `exit()`/`abort()`/`longjmp()` 处理 OOM → 跳过来自该包装的调用点。

### 2. glib 等框架的 GError 模式

```c
// GError 使用 out parameter 报告错误
GError *err = NULL;
gchar *data = g_file_get_contents("config.json", NULL, &err);
if (err) {
    g_error_free(err);
    return;
}
// 正常使用 data — 正确
```

**检测**: GLib 中的函数通过 `GError**` 参数而非返回值报告错误。对这类框架，仅检查返回值是片面的，需要识别 GError 参数的处理。

### 3. 不可失败操作

```c
// 以下操作在当前平台/场景下几乎不可能失败
void *p = malloc(64);           // 极小的分配量
close(fd);                      // 关闭已打开的文件描述符
fclose(fp);                     // 关闭已打开的文件流
```

**检测**: 
- `close()` 返回值在不可恢复的清理路径中不检查 → 降级为 info
- `malloc(64)` 等小常量值 → 理论上可失败但实际上极罕见 → 标记但 confidence: low
- `fclose()` 在正常路径仍需检查（可能无法刷入所有缓冲数据）→ 仅在清理路径才降级

### 4. RAII 包装

```cpp
// C++ RAII 包装确保构造时检查或抛出
std::ifstream file("config.txt");
std::string content((std::istreambuf_iterator<char>(file)),
                     std::istreambuf_iterator<char>());
```

**检测**: 使用 C++ IOStream/RAII 类的代码 → 跳过（构造失败通过异常机制处理，错误传播由异常保障，不在 error_propagation 检测器的检查范围内）。

### 5. 调试/日志函数

```c
#define LOG_DEBUG(fmt, ...) fprintf(log_fp, fmt, ##__VA_ARGS__)
```

**检测**: 明显是日志/调试用途的 fopen/fprintf → 降级为 low（日志失败不应影响主逻辑）。区分方式：检查文件路径是否包含 `/var/log/`、`/tmp/` 或 `LOG`/`DEBUG` 等前缀。

### 6. 返回值被后续条件检查

```c
int fd = open(path, O_RDONLY);
if (fd < 0) {
    // 错误已处理 — 下面不再使用 fd
    return -1;
}
// fd 在此安全使用
```

**检测**: 如果 `open()` 的返回值赋值语句和 `if (fd < 0)` / `if (fd == -1)` 检查语句之间没有其他使用（如 read/close）→ 正确模式。检测器必须检查赋值语句和检查语句之间是否没有干扰使用。

## 项目级抑制

```json
{
  "detectors": {
    "error_propagation": {
      "severity_cap": "medium",
      "suppress": [
        "close-return-ignore",
        "mallox-signal-cleanup"
      ]
    }
  }
}
```

## 信噪比统计

| 模式 | 真实检出的估计 FP 率 | 说明 |
|------|--------------------|------|
| fopen 未检查 | ~5% | 大多数是真 bug |
| malloc 未检查 | ~20% | OOM 在桌面环境极其罕见，但嵌入式/内存受限系统是真实问题 |
| read/write 返回值忽略 | ~30% | 许多代码忽略 partial write 或错误（非健壮代码） |
| close 返回值忽略 | ~60% | 一半情况下是可接受的（清理阶段无法恢复） |
| (void) 强制丢弃 | ~80% | 显式标记"我知道但我不管" |
