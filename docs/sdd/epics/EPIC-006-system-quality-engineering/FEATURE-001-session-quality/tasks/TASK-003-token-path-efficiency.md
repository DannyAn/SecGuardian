# TASK-003: Token/路径效率

> **所属**: FEATURE-001-session-quality
> **优先级**: P0/P2

## 改动项

### 1. todowrite → 原生 task 系统 (P0)

当前: 命令模板中用 `**Tool: todowrite** // **Input:** {"todos": [...]}` 示例。
7 次 todowrite 调用序列化 ~50KB 无效 token（已完成项每次重传）。

改为: 指示 Agent 使用原生 task 系统（`TaskCreate` → `TaskUpdate`），
不要使用 todowrite。

命令模板替换:
```markdown
<!-- omit todowrite — 使用原生 task 系统 -->
> ⚠️ **不要使用 `todowrite` 工具**。使用原生 task 系统（TaskCreate + TaskUpdate）追踪进度。
> 停用 todowrite 原因：每次调用重传全部已完成项，每会话浪费 ~50KB。
```

### 2. $RECORDER 用量固化 (P2)

当前: 命令模板已用 `$SECGUARDIAN_HOME/scripts/record-finding.py`，
但 Agent 可能回退到硬编码路径。

改为: 强调 "**必须使用** `$SECGUARDIAN_HOME`"。

### 3. SECGUARDIAN_HOME 发现后立即 cd (P0)

Pre-flight 脚本成功后立即 `cd "$USER_PROJECT"`，
使得后续所有命令从用户项目目录执行。

## 修改文件

- `commands/secguard.md`
- `commands/secaudit.md`
- `commands/secreview.md`
- `commands/secfix.md`
