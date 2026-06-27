# FEATURE-005: Indexer Robustness — Progress

> **Status**: ✅ 已完成（2026-06-27）

## Task 状态

| # | Task | 状态 | 开始 | 完成 | 备注 |
|---|------|------|------|------|------|
| 1 | index.json 聚合字段 | ✅ 已完成 | 2026-06-27 | 2026-06-27 | context.go + main.go: file_count/function_count/call_edge_count/primary_language |
| 2 | JS minified bundle 防御 | ✅ 已完成 | 2026-06-27 | 2026-06-27 | parser_javascript.go: 文件大小 >512KB + 单行 >2000 字符 → 跳过 |
| 3 | auto 模式路径排除 | ✅ 已完成 | 2026-06-27 | 2026-06-27 | main.go skipDir: +target/build/static/public |
| 4 | `--lang` 指令传参 | ✅ 已完成 | 2026-06-27 | 2026-06-27 | commands/secguard.md Step 2: +--lang <language> |

## 关键里程碑

| 日期 | 事项 |
|------|------|
| 2026-06-27 | SDD 七环初始化完成（Brainstorm → Spec → ADR → Plan → Tasks） |
| 2026-06-27 | TASK-001 实施完成（4 次 commit，共 4 次提交） |
| 2026-06-27 | TASK-002 实施完成（JS bundle 守卫） |
| 2026-06-27 | TASK-003 实施完成（路径排除） |
| 2026-06-27 | TASK-004 实施完成（`--lang` 传参） |
| 2026-06-27 | **FEATURE-005 全部完成** |

## E2E 验证

```bash
# 完整的索引器冒烟测试（验证 TASK-001 + TASK-002 + TASK-003）
cd internal && go run . --path ../examples/java-vuln-demo --lang java --output /tmp/e2e.json
# 输出应有: file_count/function_count/call_edge_count/primary_language=java
# 输出不应包含 .js 文件（--lang java 过滤 + 路径排除兜底）

# 确认命令层 --lang 传参
grep '\-\-lang <language>' commands/secguard.md
# 输出: $INDEXER --lang <language> --path <path> --output ...
```

## 下一步

- FEATURE-003 (Build & Deployment Verification)：解决 validate 脚本未打包 + guard-rules 未部署
- FEATURE-004 changes：安全评分公式修正
