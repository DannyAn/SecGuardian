# CHANGE-001: 初始实现 — 脱敏脚本 + 模板集成 + 自检守卫

## 类型

初始实现（本 FEATURE 的首次交付）

## 背景

实验证明 AI Agent 在源码中发现 `// VULNERABILITY [CWE-xxx]` 注释时会走捷径，
直接基于注释内容输出 finding，完全绕过 guard-rule 分析和 Detection Spec 验证。

本 CHANGE 记录了该 FEATURE 的全部实现内容。

## 变更内容

### 1. scripts/strip-answer-cards.py（新增）

答案卡脱敏脚本，定位并剥离以下模式：

| 模式 | 处理方式 |
|------|---------|
| `// VULNERABILITY [CWE-xxx]:` | 清空该行 |
| `// CWE-xxx:` | 清空该行 |
| `// BAD:` | 清空该行 |
| `// TP-\d+:`, `// P[0-3]-\d+:` | 清空该行 |
| `* - CWE-xxx:` 块注释内 | `(sanitized)` 占位 |
| `* VULNERABILITIES:` 块注释内 | `(sanitized)` 占位 |

设计要点：
- 空行保留（不影响行号对齐）
- 只处理 index.json 记录的文件
- 幂等操作
- dry-run 模式用于预检
- 输出 `.strip-manifest.json`

### 2. commands/secguard.md（修改）

三处修改：

1. **Step 2.5a.5 新增脱敏步骤**：在 2.5a（读 index.json）后、2.5b（读源码）前执行
2. **Step 2.5b 规则 1 修改**：指向 `.codeagent/secguardian/stripped/<file>` 而非原始路径
3. **Step 3d 规则 3 修改**：验证读取也指向脱敏副本

### 3. scripts/self-check.sh（修改）

§13 新增 13e 检查 secguard 模板中包含 strip-answer-cards.py 引用。
仅检查 secguard（secaudit/secreview 不做源码级检测）。

## 设计决策

- **脱敏而非重新排序**：模板顺序重排不能强制 AI 遵守，脱敏移除答案卡本身才有效
- **只为 secguard 实现**：只有 secguard 做源码级检测，secaudit 和 secreview 不需要
- **空行替换而非删除**：行号保持不变，索引器符号表与脱敏副本精确对齐

## 影响范围

| 文件 | 操作 | 风险 |
|------|------|------|
| scripts/strip-answer-cards.py | 新增 112 行 Python | 低（独立脚本，不影响核心管线） |
| commands/secguard.md | 修改 +3 处 | 低（模板变更，影响 AI 行为） |
| scripts/self-check.sh | 修改 +15 行 | 低（新增检查） |

## 验证

```bash
bash scripts/self-check.sh  # → 172/172 passed
```
