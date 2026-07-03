# TASK-004: commands/secguard.md Step 2 加入 `--lang <language>` 传参

> **Feature**: FEATURE-005 (Indexer Robustness)
> **REQ**: REQ-001
> **ADR**: ADR-001

## Goal

在 `commands/secguard.md` Step 2（line 171）中，将索引器调用命令从 `$INDEXER --path <path> --output...` 改为 `$INDEXER --lang <language> --path <path> --output...`，确保 AI Agent 在执行扫描时把用户指定的语言参数传递给索引器。

## Done

- [ ] `commands/secguard.md` line 171: 在 `$INDEXER` 之后增加 `--lang <language>`
- [ ] `dev-deploy.sh` 部署后确认修改生效
- [ ] 验证：对所有 5 种语言，AI Agent 扫描时索引器收到语言参数

## Files Changed

### commands/secguard.md (line 171)

```diff
- $INDEXER --path <path> --output .codeagent/secguard-secguardian/scans/<scan_id>/index.json
+ $INDEXER --lang <language> --path <path> --output .codeagent/secguard-secguardian/scans/<scan_id>/index.json
```

> 这个修改是 1 行文本替换，但影响所有 5 个语言的扫描——所有语言使用同一个 `commands/secguard.md` 的 Step 2 指令。

## 为什么只改这一处

`commands/secguard.md` 是 `/secguard` 命令的入口 SKILL.md。5 个语言（cpp/go/java/python/js）的 `skills/secguard/*/SKILL.md` 都写着"前置: Command 层面已完成 `secguardian-index`"。也就是说所有语言的索引器调用逻辑都集中在 `commands/secguard.md` 的 Step 2 中。改这一处 = 覆盖所有语言。

## 回溯补注

C/Python/Go 测试没发现这个问题的原因：所有 5 个语言的 Step 2 都是缺失 `--lang` 的。Java 项目的 `src/main/resources/static/` 含大型 minified bundle 才触发了超时。这不是 Java 特有的问题，是所有语言的 bug。

## Verification

```bash
cd /Users/kongan/workbench/github/secguardian

# 1. 确认修改
grep -n '\-\-lang <language>' commands/secguard.md

# 2. 部署
bash scripts/dev-deploy.sh

# 3. 对任意项目触发扫描验证
# (需要手动执行 /secguard ./src java 后确认索引器输出含 "Language: java")
```
