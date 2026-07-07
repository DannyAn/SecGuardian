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

### Step 5: 5 轮反思
1. 事实校对: free 和使用之间是否有赋值？
2. 因果闭环: 路径是否必然可达？
3. 寻找豁免: 是否使用智能指针？
4. 根因归并: 同分配点的多次使用合并
5. 保守定性: 跨函数不明确 → 降级

## 输出格式

每个 finding 遵循三段式证据链。
