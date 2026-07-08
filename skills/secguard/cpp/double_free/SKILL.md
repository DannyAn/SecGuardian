---
name: secguard-cpp-double-free
description: "检测 C/C++ 代码中同一指针被多次释放导致的双重释放漏洞，包括错误处理路径和别名指针的双重释放"
category: language-specific
language: cpp
topic: [memory]
signal_source: alloc_free.free_sites, call_sites[category="memory"]
---

# 双重释放检视算子

## 元数据

- id: memory.double-free
- severity: critical
- cwe: CWE-415
- category: memory
- signal_source: alloc_free.free_sites, call_sites[category="memory"]

## 信号预筛

从 index.json 的 call_sites 和 alloc_free.pairs 中筛选：

- callee 匹配: free（从 call_sites 获取所有 free 调用）
- 配对数据源: alloc_free.pairs 中的 free_sites 数组
  - 同一分配记录有 >= 2 个 free_sites → 初步怀疑 double-free
  - 同一指针变量上的连续 free 调用（无中间赋值）→ 高优先级

## 检视协议

### Step 1: 信号确认

对每个预筛信号:
1. 读取所有 free 调用点源码（每个 ±10 行）
2. 确认被释放的指针变量名（`free(p)` → 追踪 p）
3. 检查 free 之间是否有赋值操作改变了 p 的值

### Step 2: 证据链构建

构建 Source → Propagate → Sink 证据链:
- Source: 第一次 free(p) 的调用点
- Propagate: free 之间 p 的控制流路径（是否有条件分支、循环、赋值）
- Sink: 第二次 free(p) 的调用点

### Step 3: 安全变体参数审计

审计 free(p) 之间的控制流：

**路径不可达（不构成 double-free）**:
```c
if (cond) {
    free(p);     // 第一次
} else {
    free(p);     // 第二次，互斥分支 → 安全
}
```

**路径可达（double-free）**:
```c
free(p);         // 第一次
// p 未重新赋值
free(p);         // 第二次 → double-free
```

**指针重新赋值后**:
```c
free(p);         // 第一次
p = malloc(512); // 重新赋值
free(p);         // 第二次，释放新分配 → 安全（如无泄漏）
```

**NULL 重置模式**:
```c
free(p);
p = NULL;
free(p);         // free(NULL) 是 C 标准定义的安全操作 → 安全
```

**错误处理路径**:
```c
if (cond) {
    free(p);
    return -1;
}
// ...
free(p);         // cond 为真时 double-free
```

### Step 4: 跨函数补证

当 free 和第二次 free 在不同函数中：
- 查调用图确认是否存在调用关系
- 若函数 A 调用函数 B，且 A 和 B 都对同一指针调用了 free → 确认
- 若 A 先 free 再调用 B，B 内部再 free（同指针通过全局/参数传入）→ double-free

### Step 4.5: 多信号归并分析

当同一 caller function 内有多个信号时，先聚合再分析：
1. 按行号分组，检查信号间依赖（如 integer_overflow 绕过 → buffer_overflow 失效）
2. 归并后形成统一分析基线（避免重复读取同一段源码）
3. 在证据链中标注 cross_signal_analysis: true

### Step 5: 事实锚定反思（3 问判定矩阵）

必须回答 3 个域专用事实问题。答案必须基于源码证据链中的行号引用。

**Q1**: 两次 free 之间同一指针没有重新分配?
**Q2**: 第二次 free 不在错误处理路径中?
**Q3**: 指针在第一次 free 后已被置 NULL?

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
    "source": {"description": "第一次 free(p) 在 shutdown()", "file": "src/cleanup.c", "line": 42},
    "propagate": {"description": "p 未重新赋值，控制流可通过 return 路径到达第二次 free", "file": "src/cleanup.c", "line": 43},
    "sink": {"description": "第二次 free(p) 在 cleanup() → 同一指针释放两次", "file": "src/cleanup.c", "line": 55}
  }
}
```
