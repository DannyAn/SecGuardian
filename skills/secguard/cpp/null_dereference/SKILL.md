---
name: secguard-cpp-null-dereference
description: "检测 C/C++ 代码中动态内存分配后未判空直接解引用导致的空指针解引用漏洞"
category: language-specific
language: cpp
topic: [memory]
signal_source: call_sites[category="memory"]
---

# 空指针解引用检视算子

## 元数据

- id: memory.null-dereference
- severity: critical
- cwe: CWE-476
- category: memory
- signal_source: call_sites[category="memory"]

## 信号预筛

从 index.json 的 call_sites 中筛选：

- callee 匹配: malloc, calloc, realloc
- 按信号分组:
  - 直接分配组: malloc(sizeof(T) * n), calloc(n, sizeof(T))
  - 再分配组: realloc(ptr, new_size) → 需额外检查原指针
  - inline 模式: xmalloc(n) 等自定义包装 → 查定义是否已封装 NULL 检查

## 检视协议

### Step 1: 信号确认

对每个预筛信号:
1. 读取分配点源码（±10 行）
2. 确认分配点的返回值有变量接收（`T *p = malloc(...)`）
3. 识别分配点后面的第一个分支结构（if / switch / ternary / assert）

### Step 2: 证据链构建

构建 Source → Propagate → Sink 证据链:
- Source: 分配函数的返回值（哪个指针变量）
- Propagate: 分配点后紧接着的控制流
- Sink: 第一个解引用点（`p->field`、`p[0]`、`*p`、`func(p)`）

### Step 3: 安全变体参数审计

审计分配后的 NULL 检查模式：

**直接 NULL 检查（安全）**:
```c
p = malloc(n);
if (p == NULL) {
    return -1;  // 正确处理
}
p->field = 42;  // 安全使用
```

**无 NULL 检查（不安全）**:
```c
p = malloc(n);
p->field = 42;  // p 可为 NULL → 空指针解引用
```

**inline if 模式**:
```c
// 安全：xmalloc 封装确保非 NULL 或 abort
p = xmalloc(n);
// 若 xmalloc = malloc + assert(p) → 安全
// 若 xmalloc = malloc（无检查）→ 不安全

// 安全：条件分支包含赋值
if ((p = malloc(n)) == NULL) return -1;
// 使用在 if 之后 → 安全
```

**realloc 特殊审计**:
```c
// 不安全：realloc 返回 NULL 时原指针丢失
p = realloc(p, new_size);
p[0] = 1;  // realloc 失败时 p=NULL → 崩溃 + 原内存泄漏

// 安全：临时指针 + NULL 检查
tmp = realloc(p, new_size);
if (tmp == NULL) {
    free(p);
    return -1;
}
p = tmp;
```

**calloc 溢出审计**:
```c
// 即使有 NULL 检查，calloc(n, size) 的乘法溢出也需要关注
p = calloc(n, sizeof(large_struct));  // 若 n * sizeof 溢出 → 返回小分配
if (p != NULL) {
    p[n-1] = ...;  // 溢出检查点
}
```

### Step 4: 跨函数补证

当分配的指针传入子函数使用：
- 追踪深度=1，检查被调函数是否在入口做 NULL 检查
- 若子函数无条件解引用 → 确认漏洞（前提：子函数在任何路径下都会解引用）
- 若子函数有 NULL 检查 → 安全

### Step 4.5: 多信号归并分析

当同一 caller function 内有多个信号时，先聚合再分析：
1. 按行号分组，检查信号间依赖（如 integer_overflow 绕过 → buffer_overflow 失效）
2. 归并后形成统一分析基线（避免重复读取同一段源码）
3. 在证据链中标注 cross_signal_analysis: true

### Step 5: 事实锚定反思（3 问判定矩阵）

必须回答 3 个域专用事实问题。答案必须基于源码证据链中的行号引用。

**Q1**: malloc/calloc/realloc 返回值已检查 NULL?
**Q2**: 检查后使用路径中仍可能为 NULL?
**Q3**: 使用前有赋值操作（覆盖了 NULL 风险）?

判定矩阵规则:
| Q1 | Q2 | Q3 | 结论 |
|----|----|----|------|
| YES(安全) | YES | YES | SUPPRESS — 三绿灯，安全可证 |
| YES(安全) | YES | NO | informational — 基本安全但有隐患 |
| YES(安全) | NO | — | CONFIRMED — 条件不满足即漏洞 |
| NO(危险) | YES | YES | CONFIRMED — 危险信号已确认 |
| NO(危险) | NO | — | CONFIRMED — 多角度证实漏洞 |
| Mixed | Mixed | Mixed | 强制详细分析后判断 |

## 输出格式

每个 finding 遵循三段式证据链：
```json
{
  "evidence_chain": {
    "source": {"description": "malloc(1024) 返回值赋给 buf", "file": "src/reader.c", "line": 20},
    "propagate": {"description": "无 NULL 检查分支，直接使用 buf", "file": "src/reader.c", "line": 21},
    "sink": {"description": "buf[0] = getchar() 在 buf 可能为 NULL 时解引用", "file": "src/reader.c", "line": 22}
  }
}
```
