# 所有权转移误报抑制策略

## 抑制规则

1. **realloc 习惯用法**: `p = realloc(p, new_size)` — 抑制（标准惯用）
2. **RAII/智能指针**: 使用 C++ 智能指针管理的对象 → 抑制
3. **释放后赋值**: `free(p); p = new_value;` → 抑制
4. **句柄而非指针**: 整型句柄（如文件描述符）的"释放" → 不适用所有权转移分析

## 常见误报

1. **realloc 返回 NULL 但旧指针仍有效**: `ptr = realloc(ptr, size); if (!ptr)` — 此时旧 ptr 丢失是内存泄漏，非 UAF
2. **自定义 delete 包装器**: `safe_delete(&p)` 内部置 NULL → 抑制
3. **函数命名约定**: `*_release` 可能不释放内存，只释放资源句柄 → 检查实现
