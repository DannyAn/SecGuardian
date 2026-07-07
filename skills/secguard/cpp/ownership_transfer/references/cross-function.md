# 所有权转移跨函数追踪

## 规则

当指针所有权转移通过函数参数或返回值跨函数传递时，追踪目标函数内部的行为。

### 最大深度: 1 层

```c
void *acquire() {
    return malloc(100);
}

void use() {
    void *p = acquire();
    free(p);
    // p 后续是否被使用？
}
```

### 深度上限

超过 depth 1 的调用链 → 降级为 suspicious。

## 常见模式

1. **工厂函数返回分配**: 调用者需注意释放责任
2. **容器接管**: list_append(list, item) 后 list 负责 item 生命周期
3. **realloc 返回值**: realloc 可能返回新地址，旧地址已释放
4. **跨模块释放**: 模块 A 分配、模块 B 释放 → 确保使用相同分配器
