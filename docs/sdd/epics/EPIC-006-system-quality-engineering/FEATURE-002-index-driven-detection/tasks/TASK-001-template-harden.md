# TASK-001: 修改 3 个命令模板 — 去 bulk copy + 加预筛门控 + 0 漏洞跳过验证

> **Feature**: FEATURE-002-index-driven-detection
> **前置**: 无（第一个 Task）
> **涉及文件**: `commands/secguard.md`, `commands/secaudit.md`, `commands/secreview.md`

## 改动清单

### 1a. 去掉 bulk copy（3 个文件）

每个文件中找到以下两行并删除：

```bash
mkdir -p "$SCAN_DIR" "$USER_PROJECT/.codeagent/secguardian/knowledge"
cp -r "$SECGUARDIAN_HOME/knowledge/." "$USER_PROJECT/.codeagent/secguardian/knowledge/"
```

### 1b. 更新知识库路径注释

- `.codeagent/secguardian/knowledge/...` → `$SECGUARDIAN_HOME/knowledge/...`
- 替换"知识库本地拷贝"说明块为"bash cat 直接读取"说明
- 确保 `read` 工具路径不使用 `.codeagent/secguardian/knowledge/`

### 1c. 增加 pre-filter 门控步骤

在 Step 3（语言与检测器匹配）的"3d 精确加载"之前插入：

```
<!-- @secguardian:non-skippable step=pre-filter -->
#### 3c.5 检测器预筛（不可跳过）

> 检测器加载前必须经 index.json 符号表门控。这是核心架构约束。

对裁剪后的检测器清单中的每个检测器：
1. 读取该检测器对应的目标函数名（guard-rule 文件名即函数名，或规则内容中声明的关联函数）
2. 在 `index.json.symbols.functions` 中查询目标函数是否存在
3. **无匹配 → 跳过，记录 "Skipped: no matching symbol for {detector} in index.json" → 不加载规则全文**
4. 有匹配 → 进入 3d，加载规则全文
5. alloc_free.pairs / lock_graph.mutexes 作为补充信号查阅
```

**secguard.md**：对 guard-rules 做预筛（函数名即规则名，如 `strcpy` → buffer-overflow）
**secaudit.md**：对 audit-rules 做域级预筛（按 phase 关联的域/函数）
**secreview.md**：对 review-rules 做语言级预筛（按语言映射）

### 1d. 增加 0 漏洞跳过验证管道

在 Step 3.5（验证管道）入口：

```bash
# 0 findings → 跳过验证管道
FINDINGS_JSON="$SCAN_DIR/findings.json"
if [ -f "$FINDINGS_JSON" ] && [ "$(jq -r '.findings | length' "$FINDINGS_JSON" 2>/dev/null || echo 0)" = "0" ]; then
    echo "Skipped: 0 findings — verification pipeline skipped (skipped_by_zero_findings)"
    # 直接进入 Step 4 渲染
else
    # 正常执行验证管道
    ...
fi
```

## 验证方法

1. `bash scripts/self-check.sh` — 新增的 Section 13 应全部通过
2. `bash scripts/e2e-verify.sh` — 端到端回归测试
3. 目视检查：`grep -n "cp -r.*knowledge" commands/*.md` 应返回 0
