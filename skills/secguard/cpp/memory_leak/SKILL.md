---
name: secguard-cpp-memory-leak
description: "检测 C/C++ 代码中动态分配内存后未释放导致的内存泄漏，包括分配-释放不匹配和异常路径泄漏"
category: language-specific
language: cpp
topic: [memory]
signal_source: call_sites[category="memory"], alloc_free.pairs
---

# 内存泄漏检视算子

## 元数据

- id: memory.memory-leak
- severity: high
- cwe: CWE-401
- category: memory
- signal_source: call_sites[category="memory"], alloc_free.pairs

## 信号预筛

从 index.json 的 call_sites 和 alloc_free.pairs 中筛选：

- callee 匹配: malloc, calloc, realloc, free
- 配对数据源: alloc_free.pairs 中的每条记录
  - alloc_func / alloc_file / alloc_line / alloc_function
  - free_sites 数组（每个释放点的 file + line + free_func）
- 未配对分配: free_sites 为空的记录 → 高优先级疑似泄漏

## 检视协议

### Step 1: 信号确认

对每个预筛信号:
1. 读取 alloc_free.pairs 记录，确认分配点的文件/行号
2. 若 free_sites 为空 → 疑似泄漏，进入 Step 2
3. 若 free_sites 存在但数量异常（如重复释放 → 转 double_free 检测器）

### Step 2: 证据链构建

构建 Source → Propagate → Sink 证据链:
- Source: 分配点（malloc/calloc/realloc 所在行）
- Propagate: 从分配到函数所有退出路径的控制流
- Sink: 分配所在函数的每个 return 点，检查是否有 free()

### Step 3: 安全变体参数审计

审计分配所在函数的所有退出路径：

**简单函数（单一 return）**:
```c
char *p = malloc(1024);
if (init(p) != 0) {
    free(p);       // ← 异常路径有释放
    return NULL;
}
use(p);
return p;          // ← 正常路径返回指针（所有权转移给调用者）
```
所有权转移的 return 不视为泄漏。需要判断函数命名惯例（create/alloc/get 前缀）。

**多 return 函数**:
```c
// LEAK: 中间 return 路径未释放
char *p = malloc(1024);
if (cond1) return NULL;     // ← LEAK: p 未释放
if (cond2) return ERR_VAL;  // ← LEAK: p 未释放
free(p);
return OK;
```

**goto cleanup 模式（安全）**:
```c
char *p = malloc(1024);
char *q = malloc(512);
if (!p || !q) {
    free(p);    // free(NULL) 是安全的
    free(q);
    return NULL;
}
// ... 使用 ...
cleanup:
    free(p);
    free(q);
    return ret;  // 统一释放点
```

### Step 4: 跨函数补证

当分配点通过参数传入子函数进行释放：
- 检查子函数是否在所有路径上调用 free
- 若子函数在某些路径不 free 但返回指针（所有权归调用者）→ 确认传递路径

### Step 4.5: 多信号归并分析

当同一 caller function 内有多个信号时，先聚合再分析：
1. 按行号分组，检查信号间依赖（如 integer_overflow 绕过 → buffer_overflow 失效）
2. 归并后形成统一分析基线（避免重复读取同一段源码）
3. 在证据链中标注 cross_signal_analysis: true

### Step 5: 事实锚定反思（3 问判定矩阵）

必须回答 3 个域专用事实问题。答案必须基于源码证据链中的行号引用。

**Q1**: 分配后有对应的 free/释放操作?
**Q2**: 所有退出路径（含错误路径）都有释放?
**Q3**: 所有权转移给了返回/全局容器?

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
    "source": {"description": "malloc(4096) 在 load_config() 中分配", "file": "src/config.c", "line": 30},
    "propagate": {"description": "在函数 3 个 return 路径中仅 1 个调用了 free()", "file": "src/config.c", "line": 30},
    "sink": {"description": "return -1 路径在 line:50，return NULL 路径在 line:65，均跳过 free", "file": "src/config.c", "line": 50}
  }
}
```
