# API 语义误用 — 误报抑制

## 信号级误报抑制

在 Step 1（信号预筛）检测到 callee 后，在 Step 2（证据链）开始时执行以下预检以跳过已知 FP：

### 1. realloc(p, 0) — 人为 free 封装

```c
// 常见 pattern: 自定义向量/缓冲区释放宏
#define VEC_FREE(v) do { realloc((v).data, 0); (v).data = NULL; } while(0)
```

**检测**: 如果调用点位于宏实现中，且周围代码显示 free-like 意图 → 跳过。

### 2. memset + sizeof(ptr) — 正巧等于预期值

```c
struct Small { char data[8]; };
struct Small *p = malloc(sizeof(*p));
memset(p, 0, sizeof(p));   // 在 64-bit 系统上 sizeof(p) == 8 == sizeof(struct Small)
```

**检测**: 比较 `sizeof(ptr)` 的值和目标结构体的大小。如果匹配且结构体恰好是指针大小 → 标记但 confidence: low。因为这种"恰好正确"是偶然的，未来结构体变更后就会出 bug。

### 3. snprintf 返回值 — 调试日志

```c
#define DEBUG_LOG(fmt, ...) \
    do { char _b[256]; snprintf(_b, sizeof(_b), fmt, ##__VA_ARGS__); write(2, _b, strlen(_b)); } while(0)
```

**检测**: 如果 snprintf 调用的 buffer 是局部临时 buffer 且仅在该函数内使用（不暴露给外部）→ 若输入缺乏用户可控性则可降级。

### 4. strncpy — memcpy 风格的已知长度复制

```c
// 已知 source 正好是固定长度且够短
char key[32];
strncpy(key, "SECRET", sizeof(key));
// 这是一个已知安全的常量字符串 → 后续肯定以 '\0' 结尾（因为常量 < 32）
```

**检测**: source 参数是字符串字面量且长度 < sizeof(dst) → 正确终止。但仍建议显式 `key[sizeof(key)-1]='\0'`。

### 5. memcpy — 从固定偏移复制自身

```c
// array 操作: a[i] = a[j] — 编译器生成的 memcpy
struct Point a, b;
a = b;  // 编译器可能生成 memcpy(&a, &b, sizeof(a))
```

**检测**: memcpy 参数来自结构体赋值、长字面量初始化等编译器生成的 memcpy → 不标记。检测方法：调用点在 `symbols.functions` 中没有对应 entry（即不在任何用户函数内）或者位于编译器生成的 copy 构造函数内。

### 6. 传入 0 作为 snprintf 的 size 参数

```c
// 有意查询所需缓冲区长度
int needed = snprintf(NULL, 0, "%s", data);
```

**检测**: `snprintf(NULL, 0, ...)` 是标准用法获取所需长度 → 不标记。

## 环境/项目级抑制

在 `scan.json` 或项目 `.secguard.json` 中配置：

```json
{
  "detectors": {
    "api_semantic_misuse": {
      "severity_cap": "medium",
      "suppress": [
        "realloc-zero",
        "snprintf-ignore-return-debug"
      ]
    }
  }
}
```

## 信噪比统计

| 模式 | 真实检出的估计 FP 率 | 说明 |
|------|--------------------|------|
| realloc(p,0) 全局 | ~30% | 许多代码来自 C11/C23 兼容库 |
| snprintf 忽略返回值 | ~40% | 大量 DEBUG 日志和固定格式调用 |
| strncpy 未 null-terminate | ~15% | 大多数现代代码用 strlcpy 或 _s |
| memcpy 重叠 | ~5% | 重叠区域几乎总是语义错误 |
| memset sizeof(ptr) | ~1% | 几乎总是 bug |
