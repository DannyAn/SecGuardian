# TASK-002: A-2 JS Regex 解析防护

> **文件**: internal/parser/parser_re.go
> **目标**: 增加 512KB 文件和 2000 字符行长限制

## 具体改动

在 JS/TS 解析路径入口处：

1. 检查文件大小 > 512KB → 跳过（返回空结果）
2. 检查行长度 > 2000 字符 → 跳过该行

与 parser_ts.go 一致的防护逻辑。

## 验证

- `grep '512\*1024\|2000' internal/parser/parser_re.go` 命中
- self-check 通过
