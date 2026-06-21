 # TASK-004: JS 解析器 keyword 过滤增强

 ## Goal

 在 parser_javascript.go 的关键字 dedup 列表中补全 `try`, `do`, `catch`，
 避免这些 JavaScript 关键字被 `jsMethodInObj` 和 `jsArrowInObj` 的正则
 模式误匹配为函数名。

 ## Files Changed

 - `internal/parser/parser_javascript.go` — 2 处 dedup 列表添加关键字

 ## Verification

 ```bash
 (cd internal && go test ./parser/... 2>&1 | grep -v 'failed to trim cache')
 ```
