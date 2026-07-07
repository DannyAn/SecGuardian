# FEATURE-002: 强制 index.json 符号表驱动的检测执行

## 问题陈述

生产扫描日志（ses_0c5929）暴露了检测执行流程的 3 个结构性缺陷：

1. **AI 绕开 index.json**：Step 2 生成的符号表（788 函数）未被用于定位危险函数，AI 做 8 次全文件 grep
2. **知识库 bulk copy 污染项目**：`cp -r` 将 ~90 个知识库文件散落项目目录
3. **检测器全文加载无预筛**：47 个检测器全部加载全文，即使当前代码不存在对应函数

## 设计目标

| 目标 | 度量标准 | 验证方法 |
|------|---------|---------|
| 检测执行强制使用 index.json 符号表 | 生产日志中 0 次 grep 调用 | 审查扫描会话日志 |
| 知识库不复制到项目目录 | `.codeagent/secguardian/knowledge/` 目录不被创建 | 扫描后检查该目录不存在 |
| 检测器预筛后加载 | 不匹配的检测器不加载全文 | token 消耗对比 |
| 0 漏洞时自动跳过验证管道 | findings=0 → verification skipped | e2e 测试 |

## 需求规格

### REQ-001: index.json 符号表门控

命令模板中 Step 3（检测执行）必须包含以下不可跳过的结构：

```
加载检测器元数据 → 查 index.json.symbols.functions → 有匹配 → 读规则全文
                                                     → 无匹配 → 跳过，记录原因
```

在 pre-filter 步骤前插入 `<!-- @secguardian:non-skippable step=pre-filter -->` 标记。
`scripts/self-check.sh` 增加正则检查验证标记存在。

**涉及文件**: `commands/secguard.md`, `commands/secaudit.md`, `commands/secreview.md`

### REQ-002: 去除知识库 bulk copy

去掉以下两行（3 个命令模板共 6 行）：

```bash
mkdir -p "$SCAN_DIR" "$USER_PROJECT/.codeagent/secguardian/knowledge"
cp -r "$SECGUARDIAN_HOME/knowledge/." "$USER_PROJECT/.codeagent/secguardian/knowledge/"
```

所有知识库读取路径改为 `$SECGUARDIAN_HOME/knowledge/...`，使用 bash `cat`。
知识库读取指令必须使用 bash 而非 `read` 工具（避免 OpenCode 外部目录权限弹窗）。

**涉及文件**: 同上

### REQ-003: 检测器预筛 - 加载前查 index.json

命令模板明确指定不匹配时跳过逻辑：

```
1. 加载检测器，先查 index.json.symbols.functions 中是否有关联函数名
2. 有 → 加载规则全文，读取该函数代码 ±10 行
3. 无 → 跳过，记录 "Skipped: no matching symbol for {detector}"
4. 复用 alloc_free.pairs / lock_graph.mutexes 作为补充信号
```

**涉及文件**: `commands/secguard.md`

### REQ-004: 0 漏洞自动跳过验证管道

在验证管道入口增加检查：

```bash
# 0 漏洞 → 自动跳过验证管道
if [ ! -f "$FINDINGS_FILE" ] || [ "$(jq '.findings | length' "$FINDINGS_FILE" 2>/dev/null || echo 0)" = "0" ]; then
    echo "Skipped: 0 findings — verification pipeline skipped (skipped_by_zero_findings)"
    # 直接进入渲染
fi
```

**涉及文件**: `commands/secguard.md`, `commands/secaudit.md`, `commands/secreview.md`

### REQ-005: self-check.sh 新增正则检查

新增 Section 13 检查项：
- 验证 3 个命令模板均包含 `pre-filter` 非跳过标记
- 验证 3 个命令模板不包含 `cp -r.*knowledge` bulk copy 行
- 验证 3 个命令模板不包含 `mkdir -p.*knowledge` 创建知识库目录的行

**涉及文件**: `scripts/self-check.sh`

## 不做什么

- 不改 Go 索引器（`internal/`）
- 不改 `render-report.py`
- 不改 `record-finding.py`
- 不改项目架构文档（CLAUDE.md/AGENTS.md 已在之前改为薄引用层）
- 不修 OpenCode 权限弹窗（按 ADR-002.3 优先级，P2 最后处理）

## 风险与约束

- **风险**: 命令模板修改后需要全量验证（L1+L4）
- **风险**: `self-check.sh` 新增的正则检查不能有 false positive
- **约束**: 所有修改在 3 个命令模板中同步（secguard.md / secaudit.md / secreview.md）
- **约束**: 修改后重新 deploy 验证扫描正确性
