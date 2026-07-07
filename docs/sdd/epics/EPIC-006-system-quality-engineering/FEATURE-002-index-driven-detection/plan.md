# FEATURE-002: 实施计划

## 文件清单

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| `commands/secguard.md` | 修改 | 增加 pre-filter 标记 + 符号表门控逻辑 + 去除 cp -r + 0 漏洞跳过验证 |
| `commands/secaudit.md` | 修改 | 同上（同步变更） |
| `commands/secreview.md` | 修改 | 同上（同步变更） |
| `scripts/self-check.sh` | 修改 | 新增 Section 13: pre-filter 标记检查 + cp -r 禁止检查 |

## 实施步骤

### Step 1: 去除 3 个命令模板的 bulk copy

文件：`commands/secguard.md`、`commands/secaudit.md`、`commands/secreview.md`

改动内容（每个文件）：
- 去掉 `mkdir -p "$SCAN_DIR" "$USER_PROJECT/.codeagent/secguardian/knowledge"`
- 去掉 `cp -r "$SECGUARDIAN_HOME/knowledge/." "$USER_PROJECT/.codeagent/secguardian/knowledge/"`
- 更新知识库路径注释：`.codeagent/secguardian/knowledge/...` → `$SECGUARDIAN_HOME/knowledge/...`
- 更新"知识库本地拷贝"说明块 → "bash cat 直接读取"说明

### Step 2: 强制 index.json 符号表门控

文件：`commands/secguard.md`（主要）

在 Step 3（语言与检测器匹配）中新增"预筛"步骤，放置在"3d 精确加载"之前：

```
3c.5 检测器预筛（NON-SKIPPABLE）
  - 加载每个检测器前，先在 index.json.symbols.functions 中查找关联函数名
  - 无匹配 → 跳过该检测器，记录 "Skipped: no matching symbol in index"
  - 有匹配 → 进入 3d 加载规则全文
  - 插入 <!-- @secguardian:non-skippable step=pre-filter -->
```

文件：`commands/secaudit.md`、`commands/secreview.md`

同步类似逻辑（audit 用 audit-rules 关联函数，review 用 review-rules）。

### Step 3: 0 漏洞自动跳过验证管道

文件：3 个命令模板的 Step 3.5（验证管道入口）

增加 findings 数量检查，0 时自动跳转至渲染。

### Step 4: self-check.sh Section 13

新增 3 项检查：
- 13a: 验证 3 个命令模板含 `<!-- @secguardian:non-skippable step=pre-filter -->`
- 13b: 验证 3 个命令模板不含 `cp -r.*knowledge`（排除注释中的命令文档）
- 13c: 验证 3 个命令模板不含 `mkdir -p.*knowledge`（排除 scan_dir 创建行中的 knowledge）

### Step 5: 验证

- `bash scripts/self-check.sh`（L1）
- `bash scripts/e2e-verify.sh`（L4，含回归测试）
- 在 examples/cpp-vuln-demo 手动触发一次扫描确认

## 回退方案

如果修改破坏了现有扫描流程，git revert 最后 1 个 commit。
<｜｜DSML｜｜parameter name="file_path" string="true">/Users/kongan/workbench/github/SecGuardian/docs/sdd/epics/EPIC-006-system-quality-engineering/FEATURE-002-index-driven-detection/plan.md