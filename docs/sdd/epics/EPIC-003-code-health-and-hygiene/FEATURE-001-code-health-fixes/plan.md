 # Plan: Code Health Fixes

 ## Goal

 修复 SecGuardian 项目中的 7 项代码健康问题，使所有验证脚本通过，文档准确，解析器健壮。

 ## Tasks

 - [ ] [TASK-001](./tasks/TASK-001-version-sync.md) — 版本同步 0.5.5 → 0.6.0 (4 files)
 - [ ] [TASK-002](./tasks/TASK-002-go-build-false-positive.md) — Go build 假阳性修复 (self-check.sh + ci-check.sh)
 - [ ] [TASK-003](./tasks/TASK-003-agents-docs.md) — AGENTS.md 文档刷新
 - [ ] [TASK-004](./tasks/TASK-004-js-parser-keywords.md) — JS 解析器 keyword 过滤增强
 - [ ] [TASK-005](./tasks/TASK-005-parser-re-vars.md) — parser_re.go 变量提取扩展 (Go/Java/Python)
 - [ ] [TASK-006](./tasks/TASK-006-context-tests.md) — context/ 包测试覆盖
 - [ ] [TASK-007](./tasks/TASK-007-go-mod-tidy.md) — go mod tidy 清理

 ## Verification

 ```bash
 # L1 设计一致性
 bash scripts/self-check.sh
 # L2 结构完整性
 bash scripts/ci-check.sh
 # Go 测试
 (cd internal && go test ./... 2>&1 | grep -v 'failed to trim cache')
 # 完整验证链
 bash scripts/self-check.sh && bash scripts/ci-check.sh && bash scripts/dev-verify.sh
 ```
