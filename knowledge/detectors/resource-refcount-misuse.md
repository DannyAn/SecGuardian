---
detector: resource-refcount-misuse
severity: medium
cwe: CWE-911
language: [c, cpp]
tags: [resource, refcount, leak, reference]
---

# 引用计数误用 (Refcount Misuse)

## 威胁定义

成对引用计数操作（`get`/`put`、`AddRef`/`Release`、`ref`/`unref`）不匹配，导致资源提前释放（count=0 后继续使用）或永不释放（count 永远 > 0，等同于泄漏）。

## 检测逻辑

### 常见模式

```c
// BAD: get 多于 put — 资源永不释放 (leak)
obj_get(o);
obj_get(o);
obj_put(o);                      // 只 put 一次，count > 0

// BAD: put 多于 get — 资源被提前释放
obj_put(o);                       // 无对应 get

// GOOD: 成对使用
obj_get(o);
/* ... use o ... */
obj_put(o);
```

### C++ 智能指针模式

```cpp
// BAD: 裸指针手动管理引用计数
obj->AddRef();
// ... exception path ...
// obj->Release() not called — leak

// GOOD: 智能引用
std::shared_ptr<Obj> ptr(obj);    // auto refcount
```

## 修复指引

1. 以 `get` 为单位，搜索对应 `put` 是否在同一逻辑范围内
2. C++ 优先使用 `std::shared_ptr` 自动管理引用计数

## 检测模式汇总

```
(.*get\(|.*AddRef\(|.*ref\().*\n(?!.*put\(|.*Release\(|.*unref\()  # get 无对应 put
(.*put\(|.*Release\(|.*unref\().*\n(?!.*get\(|.*AddRef\(|.*ref\()  # put 无对应 get
```
