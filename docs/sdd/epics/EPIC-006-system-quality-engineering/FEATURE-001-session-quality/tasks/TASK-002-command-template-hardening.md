# TASK-002: 命令模板加固

> **所属**: FEATURE-001-session-quality
> **优先级**: P0/P1

## 改动项

### 1. 索引器 timeout 30s (P0)

当前: TIMEOUT_CMD 条件执行（"if timeout exists ... else skip"），超时 120s。

改为: 无条件使用。系统没有 `timeout` 时提示安装 coreutils。
超时 30s。超时后输出友好错误。

```bash
INDEXER="$SECGUARDIAN_HOME/scripts/secguardian-index"
if command -v timeout &>/dev/null; then
    timeout 30 "$INDEXER" --lang <lang> --path <path> --output "index.json" || {
        echo "⚠️ Indexer timed out after 30s. Use --skip-index or upgrade hardware."
        exit 1
    }
else
    echo "WARNING: 'timeout' not found — install coreutils for timeout protection"
    "$INDEXER" --lang <lang> --path <path> --output "index.json"
fi
```

### 2. Step 3.5 非跳过标记 (P1)

在验证步骤前插入 HTML 注释标记。`scripts/self-check.sh` 会验证标记未被移除。

```markdown
<!-- @secguardian:non-skippable step=validate -->
> 以下三轮验证**任何时候不可跳过**。这是强制性安全检查。
```

### 3. cd USER_PROJECT + 相对路径 (P0)

每个 bash 步骤第一行添加 `cd "$USER_PROJECT"`。
所有项目内路径统一用相对路径，减少 permission prompt。

### 4. 错误分类 (P2)

索引器失败 = 不可重试，终止扫描。
record-finding 失败 = 可重试，可跳过单个 finding。

## 修改文件

- `commands/secguard.md`
- `commands/secaudit.md`
- `commands/secreview.md`
- `commands/secfix.md`
