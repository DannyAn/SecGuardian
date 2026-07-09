# 双重释放例外规则

## 安全模式（不报告）

### 1. NULL 重置后 free
```c
free(p);
p = NULL;
free(p);  // free(NULL) 是 C 标准定义的安全操作
```

### 2. 互斥控制流分支
```c
if (mode == A) {
    free(p);
} else {
    // p 只在 A 路径释放，B 路径不释放
}
```

### 3. 指针重新分配后第二次释放
```c
free(p);
p = malloc(512);
free(p);  // 释放新分配，非双重释放
```

### 4. 引用计数检查
```c
if (--refcount == 0) {
    free(p);  // 引用计数保证只释放一次
}
```

### 5. RAII/智能指针
C++ 中 `std::unique_ptr` / `std::shared_ptr` 管理的指针不适用此规则。

## 边界情况（需降低严重度）

1. 不同函数中的 free（经调用图确认可到达）→ 降级为 high
2. goto cleanup 模式，当 return 已经跳出释放路径 → 降级为 suspicious
3. 条件编译中的 free（#ifdef 分支）→ 降级为 suspicious
