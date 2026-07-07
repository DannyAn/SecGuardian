---
name: secguard-cpp-ownership_transfer
description: "Detect use-after-free via ownership transfer violations including realloc misuse and container-stored dangling pointers"
category: language-specific
language: cpp
topic: [memory]
signal_source: call_sites[category="memory"]
---

# Ownership Transfer 检视算子

## 元数据

- id: memory.ownership_transfer
- severity: high
- cwe: CWE-416 (related)
- category: memory
- signal_source: call_sites[category="memory"]

## 信号预筛

从 index.json 的 call_sites 中筛选：

- callee 匹配: `free`, `realloc`, `delete`, `delete[]`, `*_free`, `*_destroy`, `*_release`, `FREE_*`
- 按信号分组: 优先处理 `realloc` 调用（需检查旧指针后续使用），其次含有同作用域内 free 后指针使用的函数，最后考虑跨函数的释放模式

## 检视协议

### Step 1: 信号确认
对每个预筛信号:
1. 读取调用点源码（±15 行）
2. 确认调用点真实存在，且调用属于内存释放或所有权转移操作

### Step 2: 证据链构建
Source → Propagate → Sink:
- Source: 通过 `malloc`/`calloc`/`new` 分配的原始指针
- Propagate: 指针被传递、赋值给别名 `p2 = p1`、存储在容器中、或作为函数参数传递
- Sink: `free(p)` 或 `realloc(p, new_size)` 执行后，原始指针或其别名在后续代码中被解引用（`p->field`、`p[index]`、`*p`）或传递给另一个使用函数

### Step 3: 安全变体参数审计
1. **realloc 不当使用**:
   - `p = realloc(p, new_size);` — 安全：realloc 可能返回不同的指针，但旧指针被更新
   - `q = realloc(p, new_size); free(p);` — 双重释放：realloc 内部已释放 p，`free(p)` 导致 double-free
   - `q = realloc(p, new_size); p[0] = 'x';` — 释放后使用：如果 realloc 移动了内存，p 已无效

2. **释放后别名使用**:
   - `free(p); p2->field = 1;` — 如果 `p2 == p` 则为 UAF
   - 检查函数范围内是否存在别名赋值 `p2 = p` 或 `p2 = p + offset`

3. **容器/数据结构中的悬空指针**:
   - 释放指针后未从容器中移除: `free(p); list_contains(p) == true`
   - 检查同一数组或链表中存储的指针

4. **所有权转移的调用者错误**:
   - 函数参数标明 `__attribute__((ownership_takes(p)))` 或类似语义
   - 调用者继续使用已被调函数释放的指针
   - 函数文档说"调用者负责调用 free"但调用者没有 — 视为 resource-leak 而非此算子

5. **C++ 移动语义不当**:
   - 移动后继续访问原始对象: `auto b = std::move(a); a.method();` // a 已转移

### Step 4: 跨函数补证
Max depth 1, beyond → downgrade to suspicious
- 检查被调用函数内部是否执行 free，但调用者在调用后仍使用该指针
- 检查函数返回值是否为所有权转移信号（如 realloc 返回值）
- 对 C++ unique_ptr 的 move，追踪到构造后原对象不再使用

### Step 5: 5 轮反思
1. **事实校对**: 确认释放操作（free/realloc/delete）确实发生，且释放后代码路径确实可达
2. **因果闭环**: 后续使用的确解引用了已释放的内存，而非仅对指针变量重新赋值
3. **寻找豁免**: 指针在释放后有 `p = NULL` 赋值、或者释放通过 `RAII`/智能指针管理
4. **根因归并**: 同函数内多次悬空使用是否来自单次释放，应合并为一条 finding
5. **保守定性**: realloc 模式中，如果 realloc 返回值未被检查且旧指针被使用，标记为 confirmed; 跨函数所有权转移不明确时降级为 suspicious
