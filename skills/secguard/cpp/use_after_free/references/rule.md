# 释放后使用规则定义 (Use-After-Free Rule Definitions)

## 核心规则

free(p) 后，指针 p（包括其别名）不得被解引用或传递给其他解引用函数。

## 漏洞模式

### 模式 1: 直接释放后使用
```c
// BAD
free(ptr);
ptr->field = 1;  // UAF

// BAD: 释放后读
free(conf);
printf("%s", conf->name);  // UAF
```

### 模式 2: 释放后写入
```c
// BAD
free(p);
memcpy(p, data, len);  // UAF

// BAD
free(buf);
snprintf(buf, size, "%s", val);  // UAF
```

### 模式 3: 别名使用
```c
// BAD: p2 指向已释放内存
char *p2 = p;
free(p);
p2[0] = 'x';  // UAF
```

### 模式 4: realloc 后使用旧指针
```c
// BAD: realloc 可能移动内存
char *newbuf = realloc(old, 200);
old[0] = 'a';  // UAF: old 可能无效

// BAD: 释放后变量仍被使用
free(ptr);
do_something(ptr);  // 传递已释放指针
```

## 安全模式

```c
// SAFE: 置 NULL
free(ptr);
ptr = NULL;

// SAFE: 重新分配
free(p);
p = malloc(100);
p->field = 1;  // 安全

// SAFE: 提前 return
free(buf);
return;
```

## 安全变体审计

realloc 后只使用返回值指向的内存：
```c
// BAD: realloc 失败时 ptr 仍有效，成功时旧指针悬空
ptr = realloc(ptr, new_size);

// GOOD: 使用临时变量
char *newptr = realloc(ptr, new_size);
if (!newptr) { /* ptr still valid */ }
ptr = newptr;  // 更新指针
```
