---
name: secguard-cpp-use-after-free
description: "检测 free 后继续使用指针导致的释放后使用（UAF）漏洞"
category: language-specific
language: cpp
topic: [memory]
signal_source: call_sites[category="memory"]
---

# 释放后使用检视算子

## 元数据

- id: memory.use-after-free
- severity: critical
- cwe: CWE-416
- category: memory
- signal_source: call_sites[category="memory"], alloc_free.free_sites

## 信号预筛

从 index.json 的 alloc_free.pairs 和 call_sites 中筛选：

- callee 匹配: free, realloc
- 配对数据源: alloc_free.pairs 中的 free_sites 数组 + call_sites 中的 free 调用
- 同一函数内的 free 调用点后 5 行内的指针解引用

## 检视协议

### Step 1: 信号确认
对每个 free(p) 调用点：
1. 读取后续代码（±15 行）
2. 确认指针 p 在 free 后是否被解引用（p->field, *p, p[i]）
3. 确认 free 后指针无重新赋值

### Step 2: 证据链构建
Source → Propagate → Sink:
- Source: malloc/calloc 分配点
- Propagate: 指针传递给 free
- Sink: free 后指针解引用操作

### Step 3: 参数审计

**指针别名**: 检查同一区域内是否有别名指向同一地址
```c
char *alias = p;
free(p);
alias[0] = 'x';  // alias 同样悬空
```

**realloc 后使用旧指针**:
```c
char *newbuf = realloc(p, 200);
p[0] = 'x';  // realloc 可能已移动内存
```

### Step 4: 跨函数补证
Max depth 1: 当 free 和使用在不同函数中时，查调用图确认调用顺序。

### Step 4.5: 多信号归并分析

当同一 caller function 内有多个信号时，先聚合再分析：
1. 按行号分组，检查信号间依赖（如 integer_overflow 绕过 → buffer_overflow 失效）
2. 归并后形成统一分析基线（避免重复读取同一段源码）
3. 在证据链中标注 cross_signal_analysis: true

### Step 5: 事实锚定反思（3 问判定矩阵）

必须回答 3 个域专用事实问题。答案必须基于源码证据链中的行号引用。

**Q1**: free 和 use 之间指针未被重新分配?
**Q2**: 使用的指针确是被 free 的同一对象?
**Q3**: free 后是解引用指针还是仅 dangling 引用?

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

每个 finding 遵循三段式证据链。
