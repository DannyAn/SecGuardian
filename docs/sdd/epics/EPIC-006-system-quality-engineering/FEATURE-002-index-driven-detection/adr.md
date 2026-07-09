# ADR-002: 强制 index.json 符号表驱动的检测执行

> **Feature**: FEATURE-002-index-driven-detection
> **日期**: 2026-07-07
> **前置**: CHANGE-001（生产验证发现）

## ADR-002.1: 检测执行必须经过 index.json 符号表门控

**状态**: 采纳

**问题**: 生产日志显示 AI 在执行检测时绕开 `index.json.symbols.functions`，使用 8 次独立 `grep` 调用搜索危险函数。索引器的符号表输出未被使用。

**决策**: Step 3 检测执行流程改为：

```
加载检测器元数据（名称、关联函数、适用语言）
    ↓
查询 index.json.symbols.functions — 关联函数是否存在？
    ↓ 是
加载检测器规则全文 → 读取目标函数所在文件 ±10行 → 执行语义分析
    ↓ 否
跳过该检测器，记录 "Skipped: no matching symbol for {detector} in index.json"
```

此预筛步骤不可跳过。命令模板中该步骤加 `<!-- @secguardian:non-skippable step=pre-filter -->` 标记，被 `self-check.sh` 验证。

**否决方案**:
- **grep 降级方案**（rg→grep 链式降级）—— 治标不治本。问题不是 grep 的工具链，而是 AI 根本没试 index.json。即使实现最佳 grep，依然绕过了索引器体系。
- **在 record-finding.py 加校验** —— 晚了。校验在渲染层，AI 此时已经 grep 完了全部文件。

## ADR-002.2: 取消知识库 bulk copy，改为按需 cat

**状态**: 采纳

**问题**: `cp -r "$SECGUARDIAN_HOME/knowledge/." "$USER_PROJECT/.codeagent/secguardian/knowledge/"` 将 ~90 个文件复制到项目目录，触发编辑器文件列表污染。

**决策**: 去掉 `mkdir -p .../knowledge` 和 `cp -r`。知识库文件直接在需要时用 `bash cat` 从 `$SECGUARDIAN_HOME/knowledge/` 读取。bash `cat` 不会触发 OpenCode 外部目录权限弹窗。

路径调整：
- 检测器规则：`$SECGUARDIAN_HOME/knowledge/guard-rules/{name}.md`
- 语言画像：`$SECGUARDIAN_HOME/skills/secguard-{lang}/references/language-features.md`
- language-index：`$SECGUARDIAN_HOME/knowledge/language-index.md`
- 协议文件：`$SECGUARDIAN_HOME/knowledge/protocols/{name}.md`

**否决方案**:
- **只拷贝 metadata/索引文件而非全量** —— 复杂度高于收益。按需 cat 已经够用，且不需要维护拷贝白名单。
- **保留拷贝但改为增量/软链** —— 依然会出现在 Modified Files 中。

## ADR-002.3: 优先级顺序（最重要 → 最不紧急）

**状态**: 采纳

**决策**: 以下三条构成项目的优先级铁律：

```
P0: 正确性 — AI 遵循设计流程，使用 index.json 符号表，检测结果可靠
P1: 效率 — 不浪费 token、不重复 shell 调用、预筛跳过无关检测器
P2: 权限 — OpenCode 确权弹窗、文件污染等外部问题
```

**P2 的明确约束**: 权限问题是"最后要解决的问题"。宁可不修权限弹窗，也要保证流程正确、能检出漏洞。如果某个改动同时影响正确性和权限，优先保证正确性。

**理由**: 权限弹窗是 UX 问题，用户点一次确认就过去了。绕开 index.json 是全流程可信问题，会导致漏报。

**否决方案**: 试图一次性解决全部三个优先级——已因 cp -r 方案证明有害（为了修权限弹窗，引入了项目污染这个更严重的问题）。

## ADR-002.4: 0 漏洞场景自动跳过验证管道

**状态**: 采纳

**问题**: findings 为空时，三轮验证管道（P1 语义验证 → P2 反证搜索 → P3 裁决庭）不应执行。

**决策**: 在验证管道入口检查 findings 数量：
- findings > 0 → 正常执行验证管道
- findings == 0 → 跳过并注明 `skipped_by_zero_findings`，直接进入渲染步骤

**否决方案**: 要求用户加 `--no-verify` 手动跳过 —— 用户不应为"没有发现"的结果做额外操作。

## ADR-002.5: 命令模板中 Step 3 的预筛步骤必须可被自检验证

**状态**: 采纳

**决策**: 在命令模板的 index.json 预筛步骤前插入标记行 `<!-- @secguardian:non-skippable step=pre-filter -->`。
在 `scripts/self-check.sh` 中增加正则检查验证该标记在 3 个命令模板中均未遭移除。

**理由**: CHANGE-001 暴露的问题根本在于 AI 不遵守设计流程。标记 + 自动化验证是确保流程不被下轮修改意外移除的唯一可扩展手段。
