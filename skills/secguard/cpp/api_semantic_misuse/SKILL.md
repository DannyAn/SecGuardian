---
name: secguard-cpp-api-semantic-misuse
description: "API called with semantically wrong arguments — realloc(p,0), overlapping memmove, ignored snprintf return, wrong memset size, strncpy without null-termination, memcpy overlapping regions"
category: language-specific
language: cpp
topic: [semantics]
signal_source: call_sites[category="*"]
---

# API 语义误用检视算子

## 元数据

- id: semantics.api_semantic_misuse
- severity: high
- cwe: CWE-628
- category: \* (all)
- signal_source: call_sites[category="\*"]

## 信号预筛

- callee 匹配: realloc, memmove, snprintf, memset, strncpy, memcpy, all `_s` variant functions
- 分组: high priority (argument-level semantic checks)

## 检视协议

### Step 1: 信号确认

通过 `symbols.functions` 定位以下任一 callee 出现的位置：

| callee | 语义误用模式 |
|--------|-------------|
| `realloc(p, 0)` | C 标准允许返回 NULL 或 unique pointer，行为依赖于实现，释放意图使用 `free()` |
| `memmove(dst, src, n)` | 源/目标区域重叠且 n 超过 safety margin（memmove 保证安全但参数含义混淆仍可导致读取错误） |
| `snprintf(buf, size, ...)` | 返回值被忽略 → 截断输出被静默消费 |
| `memset(buf, 0, n)` | n 传入了错误的大小（如 `sizeof(ptr)` 而非 `sizeof(*ptr)`） |
| `strncpy(buf, src, n)` | 未手动 null-terminate → CWE-170 |
| `memcpy(dst, src, n)` | 重叠区域（应使用 memmove） |
| `*_s(buf, size, ...)` | 边界检查正确但语义参数倒置/错误 |

### Step 2: 证据链 (Source→Propagate→Sink)

对每处匹配点，构建参数来源链：

1. **Source**: 函数调用的每个参数来自哪里（字面量、sizeof 表达式、变量、宏）
2. **Propagate**: 参数是否经过算术运算（尤其是除法/取模导致的 rounding error）
3. **Sink**: 参数最终到达哪个形参位置及该形参的预期语义

**检查矩阵**:

```
realloc(ptr, 0)            → 第二个参数是否为字面量 0
snprintf(...) 的返回值      → 返回值是否被检查或使用
sizeof(buf)  vs sizeof(ptr) → 第二个参数是否明确为缓冲区大小 vs 指针大小
strncpy(buf, src, n)       → buf[n-1] 是否在调用后被显式置为 '\0'
memcpy(dst, src, n)        → dst 和 src 区间是否可能重叠
```

### Step 3: 参数审计

对每个匹配的 API 调用，检查：

**realloc(p, 0)**:

```
// 脆弱: realloc(p, 0) — 行为不可移植
p = realloc(p, 0);   // C89 返回 NULL, C11 返回 unique pointer

// 安全: 使用 free + NULL 赋值
free(p);
p = NULL;
```

**snprintf 返回值被忽略**:

```
// 脆弱: 返回值被忽略 — 截断位置未知
snprintf(buf, sizeof(buf), "%s", input);

// 安全: 检查返回值 ≥ sizeof(buf) 表示截断
int n = snprintf(buf, sizeof(buf), "%s", input);
if (n < 0 || (size_t)n >= sizeof(buf)) { /* handle truncation */ }
```

**strncpy 未 null-terminate**:

```
// 脆弱: src 长度 ≥ n 时 buf 不会以 '\0' 结尾
strncpy(buf, src, sizeof(buf));
// buf 未初始化时后续使用可能读到未定义内容

// 安全: 显式设置终止符
strncpy(buf, src, sizeof(buf) - 1);
buf[sizeof(buf) - 1] = '\0';
```

**memcpy 重叠**:

```
// 脆弱: 源和目标重叠 → memcpy 是 undefined behavior
memcpy(buf + 1, buf, n);

// 安全: 使用 memmove — 保证重叠安全
memmove(buf + 1, buf, n);
```

**memset 大小错误**:

```
// 脆弱: sizeof 作用于指针而非数组
char buf[64];
memset(buf, 0, sizeof(buf));   // OK
char *p = buf;
memset(p, 0, sizeof(p));       // BUG: 只清零 8 字节

// 安全: 显式传入数组大小
memset(p, 0, 64);
```

### Step 4: 跨函数补证 (max depth 1)

如果 API 调用发生在包装函数中，查调用图（`call_graph.edges`），向上追溯一级 caller 并检查包装函数的调用语义是否正确。具体处理见 `references/cross-function.md`。

### Step 4.5: 多信号归并分析

当同一 caller function 内有多个信号时，先聚合再分析：
1. 按行号分组，检查信号间依赖（如 integer_overflow 绕过 → buffer_overflow 失效）
2. 归并后形成统一分析基线（避免重复读取同一段源码）
3. 在证据链中标注 cross_signal_analysis: true

### Step 5: 事实锚定反思（3 问判定矩阵）

必须回答 3 个域专用事实问题。答案必须基于源码证据链中的行号引用。

**Q1**: API 使用违反其文档约定或常见语义?
**Q2**: 参数值导致 API 执行意外操作?
**Q3**: API 副作用影响程序状态且未被补偿?

判定矩阵规则:
| Q1 | Q2 | Q3 | 结论 |
|----|----|----|------|
| YES(安全) | YES | YES | SUPPRESS — 三绿灯，安全可证 |
| YES(安全) | YES | NO | informational — 基本安全但有隐患 |
| YES(安全) | NO | — | CONFIRMED — 条件不满足即漏洞 |
| NO(危险) | YES | YES | CONFIRMED — 危险信号已确认 |
| NO(危险) | NO | — | CONFIRMED — 多角度证实漏洞 |
| Mixed | Mixed | Mixed | 强制详细分析后判断 |

