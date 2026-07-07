# TASK-002: self-check.sh Section 13 — pre-filter 标记 + cp -r 禁止检查

> **Feature**: FEATURE-002-index-driven-detection
> **前置**: TASK-001（模板修改完成后才能验证标记存在）

## 改动说明

在 `scripts/self-check.sh` 新增 Section 13（Template Security Gate），3 项检查。

### 13a: pre-filter 非跳过标记

验证 3 个命令模板均包含 `<!-- @secguardian:non-skippable step=pre-filter -->`。

```bash
for cmd in secguard secaudit secreview; do
    if grep -q '@secguardian:non-skippable step=pre-filter' "commands/${cmd}.md"; then
        echo "  ✅ ${cmd}: pre-filter gate present"
    else
        echo "  ❌ ${cmd}: missing pre-filter gate"
        FAILED=$((FAILED+1))
    fi
done
```

### 13b: 禁止 bulk copy

验证 3 个命令模板不包含 `cp -r.*knowledge`（排除注释中的命令文档引用）。

```bash
for cmd in secguard secaudit secreview; do
    # 搜索时排除注释行（以 # 开头或 > 开头），只检查 bash 代码块
    if grep -n 'cp -r.*knowledge' "commands/${cmd}.md" | grep -v '^\s*#' | grep -v '^\s*>' > /dev/null; then
        echo "  ❌ ${cmd}: contains cp -r knowledge bulk copy"
        FAILED=$((FAILED+1))
    else
        echo "  ✅ ${cmd}: no bulk copy"
    fi
done
```

### 13c: 禁止创建 knowledge 目录

验证 3 个命令模板不包含 `mkdir -p.*knowledge`。

```bash
for cmd in secguard secaudit secreview; do
    if grep -n 'mkdir.*knowledge' "commands/${cmd}.md" | grep -v '^\s*#' | grep -v '^\s*>' > /dev/null; then
        echo "  ❌ ${cmd}: creates knowledge directory"
        FAILED=$((FAILED+1))
    else
        echo "  ✅ ${cmd}: no knowledge dir creation"
    fi
done
```

## 验证方法

`bash scripts/self-check.sh` → Section 13 三绿通过。
