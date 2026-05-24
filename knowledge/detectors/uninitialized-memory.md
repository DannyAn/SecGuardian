---
detector: uninitialized-memory
severity: medium
cwe: CWE-457
language: [c, cpp]
tags: [memory, stack, heap, undefined-behavior]
---

# 未初始化内存使用 (Uninitialized Memory)

## 检测概要

检查变量在定义后、读取前是否已显式赋值初始化。

## 检测逻辑

### Step 1: 搜索未初始化的局部变量

```c
// BAD: 使用未初始化的变量
int x;
if (x > 0) { ... }              // x 的值未定义
```

### Step 2: 搜索未初始化的堆分配

```c
// BAD: malloc 后直接读取
char *buf = malloc(100);
printf("%s", buf);              // buf 内容是垃圾数据
```

### Step 3: 部分初始化

```c
// BAD: struct 部分初始化
struct Point { int x, y; };
struct Point p;
p.x = 10;
printf("%d", p.y);              // p.y 未初始化

// BAD: 数组部分初始化
int arr[10];
arr[0] = 1;
int sum = arr[5];               // arr[5] 未初始化
```

## 误报排除

| 场景 | 原因 |
|------|------|
| 全局/静态变量 | 自动零初始化 |
| `calloc` 分配 | 自动零初始化 |
| `{}` 值初始化 (C++) | 零初始化 |
| `memset`/`bzero` 后使用 | 已初始化 |
| 作为输出参数传递 | 由被调用函数初始化 |

## 检测模式汇总

```
# 局部变量声明后直接读取
int|char|float|double ... ;
→ (中间无赋值)
→ if|printf|return 使用该变量

# malloc 后无 memset/calloc
malloc|new
→ (无 memset|bzero|calloc)
→ 读取分配的内存

# struct/array 部分使用
struct S var;
→ 对部分字段赋值
→ 读取未赋值字段
```