# API 语义误用 — 边缘情况抑制

## 抑制条件

以下情况应降低 confidence 或标记为 intentional：

| 条件 | 适用 API | 处理 |
|------|---------|------|
| 参数来自 constexpr/宏 | 所有 | 如果 size 在编译期可确定为正确值，且意图可见 → 降级为 info |
| `realloc(p, 0)` 用于 C11/C23 兼容代码 | realloc | 检查项目标准版本声明（C11 起 realloc(p,0) 是实现定义；C23 起等价 free） |
| `strncpy` + 下一行立即 `buf[n-1]='\0'` | strncpy | 这是安全模式 → 不标记 |
| `snprintf` 返回值丢弃且 format 固定 | snprintf | 如 `snprintf(buf, sizeof(buf), "%d", counter)` → 不可能截断 → low severity |
| `memcpy` 源和目标通过 restrict 保证不重叠 | memcpy | 仅当调用处两个指针参数明确加上 restrict 限定且无混叠可能 |
| calloc + memset | memset | `calloc(n, size)` 已归零 → 紧随其后的 `memset(p, 0, n*size)` 是冗余的 → FP |
| 工具链自动生成的 API 包装 | 所有 | 标记 `/* GENERATED */` 或 `// NOLINTNEXTLINE` → 跳过 |
| `strncpy(dst, "", n)` 清零惯用语 | strncpy | `strncpy(dst, "", sizeof(dst))` 是已知清零惯用语 → 语义正确 |

## 检测器忽略指令

当用户代码含有以下注释时，跳过该调用点：

```c
// secguard:api-semantic-misuse-ignore
// secguard:ignore[realloc-zero]
// secguard:ignore[strncpy-not-null-terminated]
// NOLINTNEXTLINE(cert-*)
```

## 语言标准版本依赖

| 标准 | realloc(p,0) | strncpy 行为 |
|------|--------------|-------------|
| C89/C90 | 实现定义 | 同 C99 |
| C99 | 实现定义或未定义 | 同 C99 |
| C11 | 实现定义（DR 400 澄清） | 同 C99 |
| C17 | 同 C11 | 同 C99 |
| C23 | 明确等于 `free(p)` | 同 C99 |

若项目声明使用 C23 (`-std=c23`)，则 `realloc(p, 0)` 不再是需要标记的语义误用。
