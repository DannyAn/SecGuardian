# FEATURE-003: Answer-Card Independence — 防止 AI 走捷径读取源码注释标注

## 问题陈述

生产扫描和生产实验（ses_0c50）暴露了一个**架构性问题**：AI Agent 在读取源码时，
如果遇到 `// VULNERABILITY [CWE-xxx]:` 或 `// CWE-xxx:` 等"答案卡"标注注释，
会直接短路——不经 guard-rule 分析就把标注列出的问题直接输出为 finding。

具体证据（ses_0c50 会话日志 2152-2767 行）：
1. AI 读取所有源码文件（含 VULNERABILITY 注释）
2. AI 立即列出 27 个 findings（仅凭阅读注释）
3. AI 最后才加载 guard rules "验证"

此流程完全绕过了以下核心架构：
- **Detection Spec**：规则文件的检测规范未被使用
- **符号表门控**：index.json 的函数预筛未被使用
- **Guard Rule 检测逻辑**：检测器文件未被加载即完成"检测"

**根因**：答案卡标注存在于源码中，AI 不需要分析代码或匹配规则，
直接从注释行读取漏洞类别和位置。这是 Signal-LLM 协作架构的致命弱点。

## 受控实验证明

建立 `examples/java-vuln-demo-stripped/`（剥离全部 67 条答案卡注释），
与原始版本对比扫描结果：

| 维度 | 原始版本（有答案卡） | 剥离版本（无答案卡） | 差异 |
|------|---------------------|---------------------|------|
| 检出总数 | 27 | 28 | +1 |
| Critical | 12 | 12 | 0 |
| High | 13 | 14 | +1（JWT secret 独立检出） |
| Medium | 2 | 2 | 0 |
| 各分类匹配 | — | 18/19 类完全一致 | — |

**结论**：剥离答案卡后无退化（还多检出 1 个），证明 guard-rule 独立检测有效。
答案卡是捷径，不是必需品。

## 设计目标

| 目标 | 度量标准 | 验证方法 |
|------|---------|---------|
| 源码中的 VULNERABILITY 注释不进入 AI 上下文 | 脱敏副本中 0 个 VULNERABILITY 行 | `grep -c VULNERABILITY` 输出 = 0 |
| AI 只能读脱敏副本 | 模板强制指令 + 阻止直接读原始文件 | self-check §13e 检查 |
| 行号不因脱敏偏移 | 空行保留 → 索引器符号表行号与脱敏副本一致 | 扫描后 target_function 起始行匹配 |
| 机制可回归测试 | self-check 通过 | `bash scripts/self-check.sh` |
| 0 答案卡时正常执行 | 无答案卡的项目不报错，不卡死 | strip-answer-cards.py exit 0 |

## 需求规格

### REQ-001: 答案卡脱敏脚本

新增 `scripts/strip-answer-cards.py`，可处理以下模式：

```
// VULNERABILITY [CWE-xxx]: description        → 清空该行
// CWE-xxx: description                          → 清空该行
// BAD: description                               → 清空该行
// TP-\d+: / // P[0-3]-\d+: 分类标注              → 清空该行
* - CWE-xxx: description（块注释内）              → (sanitized) 占位
* VULNERABILITIES:（块注释内）                     → (sanitized) 占位
```

约束：
- 只读 index.json 记录的文件（不扫描无关文件）
- 空行保留 → 行号不变
- 不可修改原始文件
- exit 0（0 答案卡 → 正常退出）
- 输出脱敏清单 `.strip-manifest.json`

**涉及文件**: `scripts/strip-answer-cards.py`

### REQ-002: secguard 模板集成

在 `commands/secguard.md` Step 2.5 中新增脱敏步骤（2.5a.5），
在符号表读取后、源码读取前执行 strip-answer-cards.py。

模板要求：
- bash 调用 strip-answer-cards.py → 输出脱敏副本到 `.codeagent/secguardian/stripped/`
- 强制读取规则指向 `.codeagent/secguardian/stripped/<file>` 而非原始路径
- 阻止 AI 绕过脱敏副本直接读原始文件

**涉及文件**: `commands/secguard.md`

### REQ-003: 自检守卫

`scripts/self-check.sh` §13e 检查 secguard 模板中包含 strip-answer-cards.py 引用。

**涉及文件**: `scripts/self-check.sh`
