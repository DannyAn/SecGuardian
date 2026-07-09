# 所有权转移例外规则

## 安全模式（不报告）

1. **realloc 是唯一使用者**: `p = realloc(p, new_size);` — 标准惯用模式，安全
2. **释放后立即 NULL**: `free(p); p = NULL;` → 后续使用安全（无解引用）
3. **移动后不访问**: `auto b = std::move(a);` 且后续代码不访问 `a` → 安全
4. **引用计数管理**: 对象由引用计数控制，释放由计数决定 → 不视为所有权转移问题
5. **RAII 包装**: 指针由 `std::unique_ptr` / `std::shared_ptr` 管理 → 不报告

## 边界情况

1. **`realloc(p, 0)` 行为**: 标准未定义（类 free 行为在部分实现）→ 标记为 suspicious
2. **C 风格接收者函数**: `list_add(list, item)` 后调用者继续使用 item（取决于 list 实现）→ 降级为 suspicious
3. **自定义分配器**: 使用 arena 分配器的场景 → 所有权由 arena 管理，非传统释放模式
