 # TASK-002: Go build 假阳性修复

 ## Goal

 在 self-check.sh 和 ci-check.sh 中，Go build 命令设置 `GOCACHE` 为可写临时目录，
 避免 Go 1.23+ 缓存 trim 失败返回 exit code 1 导致的假阳性。

 ## Files Changed

 - `scripts/self-check.sh` — 2 条 Go build 命令增加 GOCACHE
 - `scripts/ci-check.sh` — Go build 命令增加 GOCACHE

 ## Verification

 ```bash
 bash scripts/self-check.sh | grep 'Go compilation'
 bash scripts/ci-check.sh 2>&1 | grep 'Go 编译'
 # 确认两处 Go build 均显示 OK
 ```
