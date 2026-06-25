# TASK-007: 命令文档更新

## Goal

更新 commands/*.md 两处：修复指导动态生成 + 新增输出路径。

## Done

- [ ] commands/secguard.md Step 4a 修复指导改为"根据代码上下文动态生成"
- [ ] commands/secaudit.md Step 4a 同上
- [ ] commands/secreview.md Step 4a 同上
- [ ] commands/secguard.md Step 4d 增加 human/ + ai/ + report.html 路径说明
- [ ] commands/secaudit.md Step 4d 同上
- [ ] commands/secreview.md Step 4d 同上

## Design

Step 4a 关键改动：

```markdown
### Step 4a: 输出 findings

每个 finding 的 fix 段必须基于当前代码上下文动态生成：
- 分析具体使用了什么 API/库（f-string vs 参数化？sprintf vs snprintf？）
- 针对当前上下文给出具体的 before → after 代码
- 不是从 detector 知识库拷贝固定模板
```

## Files

- commands/secguard.md
- commands/secaudit.md
- commands/secreview.md

## Verification

```bash
for cmd in secguard secaudit secreview; do
  echo "=== $cmd ==="
  grep -c "动态生成\|上下文.*不是.*模板" "commands/$cmd.md"
  grep -c "executive-summary\|remediation-pack\|report\.html" "commands/$cmd.md"
done
```
