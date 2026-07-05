# TASK-001: C-5 MatchAllocFree O(n²) 缓解

> **文件**: internal/indexer/indexer.go
> **目标**: 增加函数作用域哈希分组，将全文件遍历限制到同函数内
> **风险**: 跨函数 free 可能 miss，有回退

## 具体改动

在 MatchAllocFree 函数中：

1. 构建 `funcScopes` — 从 symbols.functions 提取函数起始行 → 结束行的映射
2. 对每个 alloc line，查找所在的 func scope（最小的 start ≤ line ≤ end）
3. 如果有匹配的 func scope → 只在该范围内搜索 free
4. 如果没有匹配 → 回退全文件搜索

## 验证

- `bash scripts/self-check.sh` 通过
- 示例项目走索引构建正常
