# 空指针解引用豁免规则 (Null Dereference Exceptions)

## 编译期已知安全模式

### 1. xmalloc 包装族

以下模式已封装 NULL 检查，内部会自动 abort 或退出：

```c
// EXCEPTION: xmalloc abort on OOM
void *p = xmalloc(1024);
p[0] = 'a';  // xmalloc 保证了非 NULL

// EXCEPTION: g_malloc (GLib)
void *p = g_malloc(1024);  // g_malloc 内部 g_error on OOM

// EXCEPTION: kmalloc (Linux kernel)
void *p = kmalloc(1024, GFP_KERNEL);  // __GFP_NOFAIL 时永不失败
```

**如何判定**: 在 index.json 中查找 xmalloc 的定义。若定义包含 `if(!p) abort()` / `if(!p) exit()` / `if(!p) panic()` / `if(!p) return error` → 豁免。

### 2. 小分配永不失败

```c
// EXCEPTION: 极小且不可失败
void *p = malloc(4);   // 理论上可能失败，但实际嵌入式 OOM 之外永不失败

// 但以下不豁免：
void *p = malloc(1024 * 1024 * 1024);  // 大分配不可豁免
void *p = calloc(ULONG_MAX, 8);        // 显然会失败
```

### 3. 分配后立即解引用且在受保护路径

```c
// EXCEPTION: 使用后立即检查的路径保护
char *p = malloc(n);
if (p != NULL) {
    p[0] = 'a';      // 在 if (p != NULL) 块内 → 安全
}
```

## 平台特性豁免

### 1. Linux overcommit

Linux 默认启用 overcommit (`vm.overcommit_memory=0`)，malloc 几乎永远返回非 NULL，但在实际访问时 OOM Killer 可能终止进程。**这不应作为豁免依据**，因为代码可能在非 overcommit 环境下运行。

### 2. 嵌入式裸机

在没有 MMU 的嵌入式系统中，malloc 失败意味着系统已严重退化，但解引用 NULL 导致硬件异常仍是不可接受的。

## 非豁免情况

```c
// NOT AN EXCEPTION: assert 在 NDEBUG 下被移除
char *p = malloc(1024);
assert(p != NULL);     // 仅在 debug 生效，release 被移除
p[0] = 'a';           // release 模式下无保护

// NOT AN EXCEPTION: 空函数体错误处理
char *p = malloc(1024);
if (p == NULL) {
    /* TODO: handle error */  // 空处理，实际无保护
}
p[0] = 'a';

// NOT AN EXCEPTION: realloc 用自身
p = realloc(p, 1024);
// realloc 失败 → p 仍为原值（可能 NULL）
// 若 p 原先为 NULL → 等价于 malloc，仍须检查
```
