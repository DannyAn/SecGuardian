 # TASK-001: 版本同步 — 0.5.5 → 0.6.0

 ## Goal

 将 4 个仍使用 "0.5.5" 版本号的文件同步到 "0.6.0"，与 manifest.json 和 CHANGELOG.md 一致。

 ## Files Changed

 - `internal/main.go` — 版本常量
 - `extensions/secguard-secguardian/extension.json` — 版本字段
 - `extensions/secaudit-secguardian/extension.json` — 版本字段
 - `extensions/secreview-secguardian/extension.json` — 版本字段

 ## Verification

 ```bash
 bash scripts/ci-check.sh
 # 确认 [3/5] 版本号一致性全部通过
 ```
