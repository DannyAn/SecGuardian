---
detector: use-after-free
severity: critical
cwe: CWE-416
language: [c, cpp]
tags: [memory, heap, exploitation, dangling-pointer]
---

# 释放后使用 (Use-After-Free)

## 检测概要

检查指针在 `free()`/`delete` 后是否被继续使用（读或写），这是可被利用的严重内存安全问题。

## 检测逻辑

### Step 1: 搜索释放点后的指针使用

定位每个 `free(ptr)` / `delete ptr` / `delete[] ptr` 调用，然后追踪该函数作用域内 ptr 的后续使用。

### Step 2: 使用模式分类

**模式 1：同函数内释放后使用**
```c
// BAD: free 后又使用
free(ptr);
ptr->field = value;           // Use-After-Free!
printf("%s", ptr);            // Use-After-Free!
```

**模式 2：跨函数释放后使用**
```c
// BAD: 释放后传递给其他函数
void process_data(char *data) {
    // 处理 data
}
void caller() {
    char *buf = malloc(100);
    free(buf);
    process_data(buf);        // Use-After-Free! buf 已释放
}
```

**模式 3：通过别名使用**
```c
// BAD: 别名绕过
char *p1 = malloc(100);
char *p2 = p1;
free(p1);
strcpy(p2, "data");           // Use-After-Free! p2 仍指向已释放内存
```

**模式 4：realloc 后继续使用旧指针**
```c
// BAD: realloc 可能移动内存，旧指针变为悬空
char *old = malloc(100);
char *new = realloc(old, 200);
if (new) {
    old[0] = 'x';             // Use-After-Free 或访问已移动内存!
}
```

**模式 5：C++ 成员函数返回 this 指针的悬空引用**
```c++
// BAD: 临时对象成员函数返回的指针
std::string temp = get_name();
const char *ptr = temp.c_str();
// temp 被销毁...
printf("%s", ptr);             // 悬空指针!
```

### Step 3: 跨函数/跨文件追踪

对于复杂情况，重点关注：
1. 指针作为函数返回值的释放义务（谁分配谁释放）
2. C++ 析构函数中的隐式释放
3. 回调函数中释放主函数的指针

## 误报排除

| 场景 | 原因 |
|------|------|
| `free(p); p = NULL;` 后使用 p | 使用 NULL 而非已释放内存（虽然仍是逻辑错误） |
| `realloc` 返回的新指针不等 | 旧指针已通过 realloc 内部释放，但使用新指针安全 |
| 自定义内存池 | free 不是真正的释放，内存仍在池中 |
| `std::unique_ptr::reset()` 后 RAII 保证 | unique_ptr 自动置空 |
| 静态分析已排除的死代码 | 不可达路径中的使用 |

## 检测模式汇总

```
# free/delete 后同作用域使用
free(ptr)|delete ptr
→ (无 ptr = NULL|ptr = nullptr|return)
→ 访问 ptr|ptr->|*ptr|ptr[

# 别名 UAF
p2 = p1
→ free(p1)
→ 使用 p2

# realloc 后使用旧指针
old_ptr = malloc(N)
→ new_ptr = realloc(old_ptr, M)
→ 检查 new_ptr 后仍使用 old_ptr
```
