# 释放后使用例外规则

## 安全模式（不报告）

1. **置 NULL 后使用**: `free(p); p = NULL;` → 之后对 p 的任何操作不影响实际内存
2. **重新分配**: `free(p); p = malloc(n); p->field = x;` → 安全
3. **提前 return**: `free(p); return;` → 无后续使用路径
4. **引用计数保护**: `if (--refcount == 0) { free(p); }` → 其他使用者仍合法
5. **智能指针**: `std::unique_ptr` / `std::shared_ptr` 管理的指针不适用

## 边界情况

1. 释放后仅指针地址比较（不访问内容）: `if (p == other_ptr)` → 这是合法的，不访问已释放内存
2. 释放后指针传递给 `free()`: `free(p); free(p);` → 这是 double-free 而非 UAF，转 double_free skill
3. 释放后 sizeof 操作: `free(p); size_t s = sizeof(*p);` → sizeof 是编译期操作，不实际解引用
