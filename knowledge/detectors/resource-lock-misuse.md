---
detector: resource-lock-misuse
severity: high
cwe: CWE-667
language: [c, cpp]
tags: [resource, lock, mutex, pthread]
---

# 锁误用 (Lock Misuse)

## Indexer Input

- `lock_graph.mutexes`: 直接读取预计算的 `pthread_mutex_lock`/`unlock` 位置（file + line），**不再手工搜索**
- `symbols.functions`: 定位 lock 所在函数范围
- 执行方式：遍历 lock_graph.mutexes → 精准读取对应函数 → 检查该函数所有退出路径（return/continue/break/goto）是否都经过 unlock，**不扫描无 lock 的文件**

## 威胁定义

`pthread_mutex_lock` 与 `pthread_mutex_unlock` 配对错误：重复加锁（double-lock 死锁）、只锁不解（lock without unlock）、解锁未持有的锁（unlock without lock）。不同于 `concurrency.race-condition`（时序问题）和 `concurrency.deadlock`（锁序问题），本检测器关注**锁的获取/释放配对**是否完整。

## 检测逻辑

```c
// BAD: 重复加锁
pthread_mutex_lock(&m);
pthread_mutex_lock(&m);          // double lock — deadlock!

// BAD: 错误路径只锁不解
pthread_mutex_lock(&m);
if (error) return;               // m 未解锁!

// BAD: 循环中不解锁
pthread_mutex_lock(&m);
continue;                        // m 未解锁!

// GOOD: 单出口 release
pthread_mutex_lock(&m);
ret = do_work();
pthread_mutex_unlock(&m);
return ret;
```

## 修复指引

每对 `lock`/`unlock` 检查是否在所有退出路径上配对

## 检测模式汇总

```
pthread_mutex_lock.*\n.*pthread_mutex_lock              # 连续两次 lock
pthread_mutex_lock.*\n(?!.*pthread_mutex_unlock).*return  # lock 后无 unlock 即 return
```
