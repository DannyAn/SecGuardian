# CHANGE-001: 生产验证发现 — AI 绕开 index.json 检测、知识库污染、规则过度加载

> **Feature**: FEATURE-002-index-driven-detection
> **日期**: 2026-07-07
> **来源**: 生产环境 OpenCode 扫描会话 ses_0c5929（C 语言，122 文件，788 函数，47 检测器，0 漏洞）

## 发现背景

v0.15.1 在生产环境对 `./src`（C 语言项目）执行 `/secguard` 扫描。扫描结果正确（0 漏洞，评分 100），但执行过程暴露了 3 个结构性缺陷。

AI Agent（MiniMax 2.7）在扫描后对执行过程进行了独立分析，加上人工复核生产日志，发现以下问题。

## 发现 1（最致命）：AI 绕过 index.json 全量 grep

**现象**: 执行日志显示连续 8 次独立 `grep` 调用搜索危险函数（`gets`、`strcpy`、`sprintf`、`memcpy`、`strncpy`、`system`、`popen`、`strchr`），每次产生"Agent Usage Reminder"提示，且均返回"Not found"。

**根因**: Step 2 已生成 `index.json`（含 788 个函数的符号表），但 AI 在 Step 3 执行检测时没有查阅符号表，而是全文件 grep。

**为什么框架被架空**: index.json 的 `symbols.functions` 已经是完整的"函数→文件→行号"映射。AI 需要知道"`strcpy` 在代码中是否存在"，只需查 JSON 数组，不需要扫 .c 文件。8 次 grep = 8 次 shell 调用 = 8 倍延迟和 token 消耗。

**session 中的证据**: 执行日志中 grep 调用节段，每次有完整调用栈和 Agent Usage Reminder，而 `index.json` 验证步骤输出的是"索引通过，788 函数"——AI 拥有了符号表但没用它。

**严重性**: ★★★（致命。索引器是项目唯一编译代码，如果它的输出不被使用，整个架构失去意义。）

## 发现 2（次致命）：知识库 cp -r 污染项目目录

**现象**: Step 1 中 `cp -r "$SECGUARDIAN_HOME/knowledge/." "$USER_PROJECT/.codeagent/secguardian/knowledge/"` 将 ~90 个知识库文件全部复制到项目 `.codeagent/` 目录下。

**影响**: OpenCode 编辑器右侧 Modified Files 面板突然新增 90+ 文件，用户第一感知是"项目被污染了"。如果项目 git 忽略了 `.codeagent/`，这些文件不会被 commit，但编辑器的 Diff 视图依然会显示。

**根因**: 之前为了解决 OpenCode 外部目录权限弹窗（read 工具读 `$SECGUARDIAN_HOME/knowledge/` 触发权限确认），采取了"拷贝到项目内读"的方案。这是**过度补偿**——为了修复权限弹窗，引入了一个更严重的结构性污染。

**严重性**: ★★★（项目污染。修复方案本身比原始问题更严重。）

## 发现 3（重要）：检测器规则全文加载无预筛

**现象**: 47 个检测器规则文件被全文加载到 AI 上下文。对于实际无匹配函数的检测器，这些规则文本完全浪费。

**根因**: 缺乏"先查 index.json 符号表确认是否有目标函数，有才加载规则"的门控机制。AI 按清单逐一 `read` 规则全文，然后才分析是否适用于当前代码。

**示例**: `system-command-injection` 检测器 → 先全文加载 200+ 行规则 → 再去 grep `system()` → 发现没调用 → 规则白读。

**合理流程**: 加载检测器 → 查 `index.json.symbols.functions` 有无 `system` → 无 → 记录 `Skipped: no system() in index.json` → 不加载规则全文 → 下一个。

**严重性**: ★★（效率问题。0 漏洞场景 token 浪费尤为突出。）

## 次要发现

- **验证管道在 0 漏洞时不应执行**: 0 findings → 验证管道 P1/P2/P3 无意义，应自动跳过并注明 `skipped_by_zero_findings`
- **findings 目录树在 0 漏洞时未生成**: 渲染器仍需被调用以输出完整结构（report.md, summary.json 等）

## 设计输入（供 ADR 和 Spec 使用）

1. **强制 index.json 门控** —— Step 3 检测执行必须经过"查 index.json 符号表 → 有匹配才加载规则全文"的不可跳过步骤
2. **去除知识库 cp -r** —— 按需读取 `$SECGUARDIAN_HOME/knowledge/`，用 bash `cat` 而非 bulk copy
3. **优先级：正确性 > 效率 > 权限** —— 权限弹窗是最后解决的问题。宁可不修权限，也要先保证检测流程正确
4. **验证管道适应 0 漏洞场景** —— 无 findings 时自动跳过
