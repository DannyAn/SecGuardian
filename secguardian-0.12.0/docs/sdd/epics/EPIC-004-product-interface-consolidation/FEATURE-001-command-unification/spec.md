# Command Interface Unification + Knowledge Layer Restructuring

> **Feature**: FEATURE-001-command-unification
> **Epic**: EPIC-004-product-interface-consolidation
> **状态**: 📋 Spec 阶段
> **日期**: 2026-06-21
> **作者**: JonyAn + Claude Code
> **设计参考**: project-codeguard (CoSAI/OASIS) — 知识层与 workflow 层分离模式

---

## 1. 问题陈述

### 1.1 当前痛点

1. **命令参数歧义**：三个命令各有一套参数格式（secguard=`<path> [mode] [filters]`, secreview=`<path> [language]`, secaudit=`<skill-name> [path]`）。language 位置不统一，AI 解析易出错。`/secguard ./src memory.* cpp` 中 `memory.*` 和 `cpp` 谁是谁无法确定。

2. **Detector 索引手工维护**：`skills/secguard/cpp/references/language-index.md` 手工抄写 61 个 detector 的元数据，与 detector frontmatter 中的 `language` 字段不同步，必然产生 drift。

3. **Gemini .toml 手工维护**：`commands/gemini/*.toml` 是三个 `.md` 的 TOML 副本，改 `.md` 后须手动同步 `.toml`，多次出现不同步问题。

4. **SecAudit 不是工作流**：secaudit 暴露 17 个独立 skill 给用户逐个调用，违背"旗舰产品出一份完整审计报告"的原始设计意图。用户需要 `/secaudit ./src python` 一次跑完。

5. **知识层命名不一致**：`knowledge/guard-rules/`（secguard）、skill 内嵌审计知识（secaudit）、`skills/*/references/*.md`（secreview）——三个概念三个位置，认知负担高。

6. **Step 2.5 职责误用**：当前 Step 2.5 试图用 index.json 符号表决定"该跳过哪些 detector"，实质做了 detector 选择工作，而决定权已由 language + filter 两层决定。

### 1.2 用户场景

| 场景 | 当前问题 | 改造后 |
|------|---------|--------|
| `secaudit ./src python` | 只列出 17 个 skill，用户必须再选一个 | 直接跑完整审计，17 phase 顺序执行 |
| `secaudit ./src python --focus input-validation` | 不存在 | 只跑单项 |
| `secguard ./src cpp memory.*` | 有歧义（memory.* 是 language 还是 filter？） | 明确：language=cpp, filter=memory.* |
| `secreview ./src` | AI 自动检测语言，不可控 | 语言显式/自动双路径 |
| 修改 secguard.md 后 | 必须手动改 secguard.toml | 构建时自动生成 |

---

## 2. 设计目标

| # | 目标 | 可度量标准 |
|---|------|-----------|
| G1 | 三命令参数格式一致 | 三个命令 `<path> <language>` 前缀相同 |
| G2 | 知识库命名一致 | 三个知识库 `{command}-rules/` 模式，无例外 |
| G3 | SecAudit 单命令出完整报告 | 一个 `/secaudit ./src python` 执行全部 17 个 phase |
| G4 | 无手工维护的索引文件 | `language-index.md` 退役，`language-index.md` 自动生成 |
| G5 | 无手工维护的平台格式 | `.toml` 构建时自动生成，不再手工编辑 |
| G6 | Step 2.5 不做 detector 选择 | 代码确认只优化执行效率，不跳过任何 detector |

---

## 3. 需求规格

### REQ-001: 命令参数统一

三个命令统一为 `<path> <language>` 前缀：

```
/secguard  <path> <language> [filters]
/secreview <path> <language>
/secaudit  <path> <language> [--focus <domain>]
```

- language 为必需的第二个位置参数（secreview 保留自动检测作为向后兼容 fallback）
- filter 支持 `memory.*`（namespace 通配）、`memory.buffer-overflow`（精确匹配）、`memory.*,crypto.*`（逗号并集）
- secaudit 的 `--focus` 参数支持 17 个域名的精确匹配

### REQ-002: 知识层重组

```
当前 → 迁移后
knowledge/guard-rules/*.md              → knowledge/guard-rules/*.md
skills/secaudit/{17 domains}/SKILL.md → knowledge/audit-rules/*.md
skills/secreview/{5 lang}/references/* → knowledge/review-rules/*.md
```

- 所有知识文件内容不变，只改变路径
- `knowledge/` 下的所有引用路径同步更新

### REQ-003: language-index.md 自动生成

构建时脚本扫描 `knowledge/guard-rules/*.md` 的 frontmatter `language` 字段，输出 `knowledge/language-index.md`：

```markdown
# 语言检测器索引（自动生成）

## cpp
guard-rules/buffer-overflow, guard-rules/double-free, ...
audit-rules/cryptography, audit-rules/input-validation, ...

## python
guard-rules/sql-injection, guard-rules/xss, ...
audit-rules/cryptography, audit-rules/input-validation, ...
```

- 格式：Markdown，按语言分组，`## {language}` 作为定位锚点
- AI 读取时定位到 `## cpp` 即可消费，不需解析 JSON
- 生成脚本：`scripts/sync-language-index.sh`

### REQ-004: language-index.md 退役

`skills/secguard/cpp/references/language-index.md` 停止维护并删除。所有引用该文件的 10+ 个文档改为引用 `knowledge/language-index.md`。

### REQ-005: .toml 构建时自动生成

`commands/gemini/*.toml` 不再手工维护，改为构建时从 `.md` 自动转换：

```bash
# 从 commands/secguard.md → commands/gemini/secguard.toml
# 从 commands/secaudit.md → commands/gemini/secaudit.toml
# 从 commands/secreview.md → commands/gemini/secreview.toml
```

- 转换逻辑：提取 `.md` 的 frontmatter `description` + 全部正文 → 填入 `.toml` 的 `description` + `prompt`
- `.toml` 文件加入 `.gitignore`，不再 git 跟踪

### REQ-006: SecAudit 旗舰工作流

新增 `skills/secaudit/workflow-secaudit/SKILL.md`，定义 17 个 phase 的编排：

```
Phase 1: 技术栈识别
Phase 2: 攻击面分析
Phase 3: 输入验证审计
Phase 4: 认证与会话审计
...
Phase 17: 汇总报告生成
```

全量模式（`/secaudit ./src python`）：加载 17 个审计领域知识 + 匹配的 guard rules
单项模式（`/secaudit ./src python --focus input-validation`）：加载 1 个领域知识 + 匹配的 guard rules

### REQ-007: Step 2.5 职责纠正

将 Step 2.5 从"检测器筛选"改为"扫描目标定位"：

- 职责：用 index.json 符号表为已加载的 detector 找靶子，不跳过任何已加载的 detector
- 输入：已确定的 detector 集合（由 language + filter 决定）
- 输出：每个 detector 在代码中的精准目标位置列表

---

## 4. 设计方案

### 4.1 整体架构

```
┌────────────────────────────────────────────────────────────┐
│                      用户输入                               │
│  /secguard ./src cpp memory.*                              │
│  /secaudit ./src python                                    │
│  /secreview ./src java                                     │
└──────────────┬─────────────────────────────────────────────┘
               │
               ▼
┌────────────────────────────────────────────────────────────┐
│                    Command Parsing                          │
│  path=<path> + language=<lang> + [filters/focus]           │
└──────────────┬─────────────────────────────────────────────┘
               │
               ▼
┌────────────────────────────────────────────────────────────┐
│           Knowledge Loading (via language-index.md)         │
│  Step 3: 读 language-index.md → 按语言获取检测器清单        │
│  Step 3: 按 filter 裁剪 → 得到精准清单                      │
│  Step 3: 精确加载对应知识文件（不遍历全部）                   │
└──────────────┬─────────────────────────────────────────────┘
               │
               ▼
┌────────────────────────────────────────────────────────────┐
│    Step 2.5: 扫描目标定位（只优化，不跳过）                   │
│  读 index.json → 为每个 detector 找精准目标位置              │
└──────────────┬─────────────────────────────────────────────┘
               │
               ▼
┌────────────────────────────────────────────────────────────┐
│                    执行检测 / 审计 / 检视                    │
│  secguard: 按 detector 逐条执行                             │
│  secaudit: workflow 按 phase 1-17 顺序编排                   │
│  secreview: 按语言反模式列表逐条检视                          │
└──────────────┬─────────────────────────────────────────────┘
               │
               ▼
┌────────────────────────────────────────────────────────────┐
│                   输出（保持 v5.0 不变）                      │
│  findings 目录树 → render-report.py → 6 文件                 │
└────────────────────────────────────────────────────────────┘
```

### 4.2 知识层对应关系

```
knowledge/
  guard-rules/          ← 61 个 API 级检测规则
    buffer-overflow.md     {severity, language, cwe, namespace}
    sql-injection.md       {severity, language, cwe, namespace}
    ...

  audit-rules/          ← 17 个架构级审计领域
    cryptography.md        {domain, topic, language, owasp_ref}
    input-validation.md    {domain, topic, language, owasp_ref}
    ...

  review-rules/         ← 5 个语言级反模式规则
    go.md                  {language, standards: [sei-cert]}
    python.md              {language, standards: [sei-cert]}
    ...

  language-index.md     ← 自动生成的聚合索引
```

### 4.3 secaudit 路由逻辑

```
/secaudit ./src python --focus cryptography
  → workflow-secaudit 读取 --focus 参数
  → 只加载 knowledge/audit-rules/cryptography.md
  → 只加载 knowledge/guard-rules/ 中 language=python 且 namespace=crypto.* 的文件
  → 执行 Phase: 密码学审计

/secaudit ./src python
  → workflow-secaudit 读取全部 knowledge/audit-rules/*.md
  → 合并全部 guard-rules 中 language=python 的文件
  → 执行 Phase 1-17
```

---

## 5. 文件影响清单

| 操作 | 文件 | 改动量 |
|------|------|--------|
| 修改 | `commands/secguard.md` | 参数格式 + Step 2.5 + Step 3 | 高 |
| 修改 | `commands/secaudit.md` | 参数格式 + 重写为 workflow 路由 | 高 |
| 修改 | `commands/secreview.md` | 参数格式统一 | 中 |
| 新增 | `skills/secaudit/workflow-secaudit/SKILL.md` | 17 phase 编排 | 高 |
| 新增 | `knowledge/language-index.md` | 构建时自动生成 | — |
| 新增 | `knowledge/audit-rules/17 个文件` | 从 skills/secaudit/*/SKILL.md 迁移 | 中 |
| 新增 | `knowledge/review-rules/5 个文件` | 从 skills/secreview/*/references/*.md 迁移 | 低 |
| 新增 | `scripts/sync-language-index.sh` | guard-rules frontmatter 扫描 + 聚合 | 中 |
| 新增 | `scripts/sync-toml.sh` | .md → .toml 转换 | 低 |
| 改名 | `knowledge/guard-rules/` → `knowledge/guard-rules/` | 纯路径迁移 | 中 |
| 删除 | `skills/secguard/cpp/references/language-index.md` | 退役 | 低 |
| 修改 | `.gitignore` | 新增 `commands/gemini/*.toml` | 低 |
| 系统 | 所有引用 `knowledge/guard-rules/` 的 10+ 文件 | 路径批量更新 | 中 |

---

## 6. 风险与约束

| 风险 | 影响 | 缓解 |
|------|------|------|
| 命令格式变更影响已存储在 AI 上下文的历史记录 | 低 | slash command 是 AI 实时执行的，历史不依赖格式 |
| `knowledge/guard-rules/` 改名影响 10+ 文件引用 | 中 | 批量 grep -rl → sed 替换，自动化 |
| secaudit workflow 可能漏掉已有 17 个 skill 的细节 | 高 | 迁移时不删原有内容，先建 workflow 再替换 |
| securit 的 `--focus` 参数实现复杂度超出预期 | 中 | 可推迟到 v2 |

---

## 7. 明确不纳入本 Feature 的

- MCP Server（FEATURE-002-mcp-server 独立追踪）
- 三轮验证管道（FEATURE-003-verification-pipeline 独立追踪）
- Detector 内容本身修改（不改 frontmatter schema）
- SecAudit 的 `--focus` 参数（如复杂度高可延至后续优化）

---

## 8. 验证方法

| # | 验证项 | 方法 |
|---|--------|------|
| V1 | 命令参数正确解析 | 对三个命令的 frontmatter description + usage 进行 review |
| V2 | language-index.md 正确生成 | 运行 sync 脚本后验证 cpp/java/python/go/js 五语言各有对应检测器 |
| V3 | .toml 与 .md 内容一致 | diff 生成的 .toml 与手工维护的旧版 .toml，验证无内容丢失 |
| V4 | secaudit workflow 可执行 | 执行 `/secaudit ./src python --focus cryptography` 验证单项模式 |
| V5 | Step 2.5 不跳过 detector | review commands/secguard.md Step 2.5 文本确认无"跳过"逻辑 |
