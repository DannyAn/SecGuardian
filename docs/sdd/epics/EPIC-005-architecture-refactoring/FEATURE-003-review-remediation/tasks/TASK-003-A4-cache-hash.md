# TASK-003: A-4 索引缓存增加内容 hash

> **文件**: scripts/secguardian-index (wrapper)
> **目标**: 在缓存 key 中加入源文件内容的 MD5 前缀

## 具体改动

在缓存路径生成逻辑中：

1. 计算源文件内容的 MD5（前 4KB 以减少开销）
2. 将 hash 前缀插入到缓存 key、路径中
3. 如果 hash 变 → 缓存 miss → 重建索引

## 验证

- `grep 'md5sum\|md5' scripts/secguardian-index` 命中
- 手动测试：改源码内容后缓存应该 miss
