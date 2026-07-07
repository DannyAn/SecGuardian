# 释放后使用误报抑制策略

## 抑制规则

1. **赋值后使用**: free 和 deref 之间有 `p = new_value` 赋值 → 抑制
2. **智能指针包装**: 通过智能指针间接访问 → 抑制
3. **数组索引变化**: `free(arr); arr = new_arr; arr[0] = x;` → arr 已更新，安全
4. **线程退出标志**: `free(ctx); ctx->running = 0;` → 如果 ctx->running 在 free 前已被读取，释放后写可能是无害的（但 UB），降级为 suspicious

## 常见误报

1. **统计计数**: `free(p); counter--;` — 仅计数，非指针解引用
2. **日志输出文件名**: `free(buf); log("freed %s", filename);` — filename 非指针变量
3. **地址打印**: `free(p); printf("ptr was %p", (void*)p);` — 仅打印地址值，非解引用
4. **false 路径**: `free(p); if (cond) { p->x = 1; }` — cond 在 free 后必然为 false → 不可达
