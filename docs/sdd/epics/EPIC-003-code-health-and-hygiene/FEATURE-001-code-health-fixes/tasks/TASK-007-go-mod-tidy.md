 # TASK-007: go mod tidy 依赖清理

 ## Goal

 运行 `go mod tidy` 清理 internal/go.mod 和 go.sum 中的未使用依赖。

 ## Files Changed

 - `internal/go.mod` — 移除未使用的 indirect 依赖
 - `internal/go.sum` — 同步更新

 ## Verification

 ```bash
 (cd internal && gc=$(mktemp -d) && GOCACHE=$gc go build ./... 2>&1 | grep -v 'failed to trim'; rm -rf "$gc")
 ```
