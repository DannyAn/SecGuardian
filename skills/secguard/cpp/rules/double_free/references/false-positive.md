# 双重释放误报抑制策略

## 抑制规则

1. **free(NULL) 模式**：两次 free 之间有 `p = NULL` 赋值 → 抑制
2. **重新分配模式**：两次 free 之间有 `p = malloc(n)` 或 `p = calloc(n, size)` → 抑制
3. **互斥分支模式**：两个 free 在 `if/else` 互斥分支中 → 抑制
4. **return 退出模式**：第一个 free 后函数立即 return → 抑制
5. **编译器内置函数**：`__builtin_expect` / `likely` / `unlikely` 不影响控制流分析，忽略
6. **条件编译分支**：`#ifdef` 分支中的 free 在目标平台可能不可达 → 降级为 suspicious

## 常见误报场景

1. **延迟释放队列**：指针被加入延迟释放队列，后续函数调用 `process_pending_frees()` 处理 → 实际非 double-free
2. **调试/断言路径**：`assert(p != NULL); free(p);` — assert 在 Release 编译下被移除 → 按配置决定
3. **线程安全模式**：锁保护下的引用计数 free — 静态分析难以确定可达路径 → 标记为 suspicious
