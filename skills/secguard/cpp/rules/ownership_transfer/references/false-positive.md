> **定位**: 区分真正的所有权转移问题与安全的资源管理模式 | **加载时机**: Phase 2c Counter Evidence | **消费方**: Judge (Step 7)

# 所有权转移误报抑制策略

## 判定决策树

```
检测到疑似所有权转移问题
│
├─ 释放后有立即 NULL 赋值？
│  ├─ free(p); p = NULL; → 抑制（明确放弃所有权）
│  ├─ obj = std::move(src); src 后续未使用 → 抑制
│  └─ 否: 继续
│
├─ 是否为 realloc 模式？
│  ├─ p = realloc(p, new_size) + 检查返回值 → 抑制（标准惯用）
│  ├─ p = realloc(p, 0) → 标记为 suspicious（未定义行为）
│  ├─ tmp = realloc(p, s); if (tmp) p = tmp; → 抑制（安全重分配模式）
│  └─ ptr = realloc(ptr, s); 无 NULL 检查 → **报告**（泄漏风险）
│
├─ 容器所有权转移？
│  ├─ std::vector 重新分配（元素被 move/复制）→ 抑制（RAII 管理）
│  ├─ C 数组 realloc 后旧指针未更新 → **报告**
│  ├─ 容器 resize/shrink_to_fit 触发元素析构 → 抑制（标准容器行为）
│  └─ 否: 继续
│
├─ 是否为智能指针管理？
│  ├─ std::unique_ptr / std::shared_ptr → 抑制
│  ├─ 自定义 RAII 类 + 正确的析构函数 → 抑制
│  ├─ GCC __attribute__((cleanup)) → 抑制
│  └─ 否: 继续
│
├─ 句柄/非指针资源？
│  ├─ 整型 fd/句柄（close(fd)）→ 不适用（非内存所有权）
│  ├─ 数据库连接/锁句柄 → 检查资源生命周期
│  └─ 否: 继续
│
└─ 默认: **报告** 为所有权转移问题
```

## realloc 模式安全性判别

| 模式 | 安全性 | 说明 |
|------|--------|------|
| `p = realloc(p, n); if (!p) { /* error */ }` | **泄漏风险** | 失败时原 p 丢失（CWE-401） |
| `tmp = realloc(p, n); if (tmp) p = tmp; else free(p);` | 安全 | 正确的暂存模式 |
| `p = realloc(p, n);` 无检查 | **风险** | 双重失败：泄漏 + 可能 NULL deref |
| `realloc(p, 0)` | **未定义** | C17: 实现定义行为；推荐用 free |

## vector/容器重新分配安全性

```cpp
// 安全：std::vector 自动管理元素生命周期
std::vector<Resource> vec;
vec.push_back(Resource());  // move 或 copy
vec.resize(10);             // 新增元素默认构造
vec.clear();                // 所有元素析构，内存可能保留或释放
// 无需手动干预 — RAII 保证正确性

// 需注意：存储原始指针的容器（不报告但需审查）
std::vector<char*> ptrs;
ptrs.push_back(malloc(100));
ptrs.clear();  // 泄漏！需先 free 每个元素
// 这不属于所有权转移问题，属于 memory_leak
```

## 抑制规则

1. **realloc 习惯用法**: `p = realloc(p, new_size)` — 抑制（标准惯用）
2. **RAII/智能指针**: 使用 C++ 智能指针管理的对象 → 抑制
3. **释放后赋值**: `free(p); p = new_value;` → 抑制
4. **句柄而非指针**: 整型句柄（如文件描述符）的"释放" → 不适用所有权转移分析

## 常见误报

1. **realloc 返回 NULL 但旧指针仍有效**: `ptr = realloc(ptr, size); if (!ptr)` — 此时旧 ptr 丢失是内存泄漏，非 UAF
2. **自定义 delete 包装器**: `safe_delete(&p)` 内部置 NULL → 抑制
3. **函数命名约定**: `*_release` 可能不释放内存，只释放资源句柄 → 检查实现
4. **零长度分配**: `malloc(0)` 可能返回 NULL 或唯一指针 → 不同平台行为不同，抑制（非所有权问题）
