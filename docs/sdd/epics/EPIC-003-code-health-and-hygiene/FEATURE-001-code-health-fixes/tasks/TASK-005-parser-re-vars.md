 # TASK-005: parser_re.go 变量提取扩展

 ## Goal

 在正则解析 fallback（parser_re.go）中对 Go、Java、Python 三种语言增加
 变量名提取功能。此前仅 C/C++ 有变量提取。

 注意：JavaScript 跳过，因为 parser_javascript.go 已独立处理。

 ## Files Changed

 - `internal/parser/parser_re.go` — 3 个新增 if 块 (Go/Java/Python)
   - Go: 匹配 `var name` 和 `name :=` / `name =` 模式
   - Java: 匹配 `Type name =` 声明模式
   - Python: 匹配行首 `name =` 赋值模式（使用 isKeyword 过滤控制流）

 ## Verification

 ```bash
 (cd internal && gc=$(mktemp -d) && GOCACHE=$gc go test ./parser/... 2>&1 | grep -v 'failed to trim'; rm -rf "$gc")
 ```
