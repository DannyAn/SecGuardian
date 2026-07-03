# ADR — Command Unification Architecture Decisions

> **Feature**: FEATURE-001-command-unification
> **原则**: Brainstorm 决定方向 → ADR 记录决策

---

## ADR-001: 三命令统一为 `<path> <language>` 参数格式

**日期**: 2026-06-21
**状态**: ✅ Accepted

### Decision

所有三个产品命令统一为 `<path> <language>` 前缀：

```
/secguard  <path> <language> [filters]
/secreview <path> <language>
/secaudit  <path> <language> [--focus <domain>]
```

### Reason

- language 是第二个位置参数，消除 AI 的解析歧义（无需猜测第二个参数是 filter 还是 language）
- 与 `README.md` 已有的示例 `/secguard examples/cpp-vuln-demo/src cpp` 对齐
- secreview 从 `[language]`（可选）改为 `<language>`（显式），保持自动检测向后兼容

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 用 flag 消除歧义（`--lang python --filter memory.*`） | 过长，不符合 slash command 的简洁直觉 |
| AI 自动检测语言（保留现状） | 用户指定 `memory.*` 时 AI 无法判断第二个参数是 filter 还是 language |

### Consequences

- 3 个 `commands/*.md` 的使用示例 + 解析逻辑需要重写
- secaudit 需要从 skill-name 作为主参数改为 path 为主参数
- secreview 需从 `[language]` 可选升级为显式（老用法向后兼容）

---

## ADR-002: 知识层统一为 `{command}-rules/` 命名模式

**日期**: 2026-06-21
**状态**: ✅ Accepted

### Decision

```
knowledge/
  guard-rules/       ← 当前 detectors/（61 个）
  audit-rules/       ← 新增（17 个审计领域，从 skills/secaudit/*/SKILL.md 迁移）
  review-rules/      ← 新增（5 个语言反模式，从 skills/secreview/*/references/*.md 迁移）
```

### Reason

- 统一后缀 `-rules`：所有知识都是"规则"，不引入 `detectors`、`domains`、`rules` 三个不同概念
- 产品前缀：`guard`、`audit`、`review` 与命令的语义部分一致，不需要记忆转换
- `ls knowledge/` 一眼看到三个 `*-rules/` 目录，每个对应一个产品

### Consequences

- `knowledge/guard-rules/` 改名为 `knowledge/guard-rules/`，10+ 个引用文件更新路径
- 17 个 secaudit SKILL.md + 5 个 secreview references 迁移到 knowledge/
- `language-index.md` 从这三个目录自动聚合生成

---

## ADR-003: SecAudit 独立 workflow skill + knowledge 层分解

**日期**: 2026-06-21
**状态**: ✅ Accepted

### Decision

SecAudit 从 17 个独立 `skills/secaudit/*/SKILL.md` 变为：

```
skills/secaudit/workflow-secaudit/SKILL.md  ← 唯一 workflow（17 phase 编排）
knowledge/audit-rules/*.md                   ← 17 个审计领域知识文件
```

### Reason

- `skills/` 是 workflow 层，不应承载知识。17 个审计领域逻辑本质是知识，应放在 `knowledge/`
- 与 secguard 架构一致：两者都是 thin workflow + thick knowledge
- 参考 project-codeguard 的 security-review skill：1 个 workflow + knowledge 层规则
- 解决"17 个 skill 如何调度"的问题——不存在 17 个 skill，只有 1 个

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 保留 17 个 SKILL.md 在 skills/，workflow 编排它们 | 17 个调度入口，command 层扛调度压力（并行/串行/依赖管理） |
| `knowledge/rules/` 下 flat 存放，用 `type` 字段区分 | 三种知识粒度不同、消费方式不同，强塞一个目录增加认知负担 |

### Consequences

- `skills/secaudit/*/SKILL.md` 17 个文件的内容迁移到 `knowledge/audit-rules/*.md`
- `skills/secaudit/workflow-secaudit/SKILL.md` 新增，编排 17 个 phase
- `--focus` 参数是单项审计的入口，路由到对应领域知识文件

---

## ADR-004: language-index.md 使用 Markdown 而非 JSON

**日期**: 2026-06-21
**状态**: ✅ Accepted

### Decision

`knowledge/language-index.md` 使用紧凑 Markdown 格式：

```markdown
## cpp
guard-rules/buffer-overflow, guard-rules/double-free, ...
audit-rules/cryptography, audit-rules/input-validation, ...

## python
guard-rules/sql-injection, guard-rules/xss, ...
```

### Reason

- Markdown 的 `## {language}` 锚点允许 AI 只定位到需要的语言段，不需要读取整个文件
- JSON 的引号/逗号/中括号在 token 层面比纯 Markdown 重 30-50%
- AI 不解析 JSON 结构，只读 `## cpp` 下面的文本即可

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| JSON 格式（`{"cpp": [...], "python": [...]}`） | token 开销大，且 AI 无法部分读取 |
| 运行时遍历 knowledge/ 目录 | 每次扫描都要遍历 83 个文件提取 frontmatter |

### Consequences

- 新增 `scripts/sync-language-index.sh`，构建时自动生成
- `skills/secguard/cpp/references/language-index.md` 退役

---

## ADR-005: Gemini .toml 构建时自动生成

**日期**: 2026-06-21
**状态**: ✅ Accepted

### Decision

`commands/gemini/*.toml` 不再手工维护，构建时从 `commands/*.md` 自动转换生成。

### Reason

- 人工维护必然产生 drift，已多次出现不一致
- 转换逻辑简单：提取 frontmatter `description` + 正文 → 填入 TOML 的 `description` + `prompt`

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 手工维护 | 已出现多次不同步问题 |
| Python converter 管线（像 project-codeguard 的 BaseFormat） | 过于重量级，只有 3 个 .toml 文件，shell 级别 wrapper 足够 |

### Consequences

- `.toml` 加入 `.gitignore`
- 新增 `scripts/sync-toml.sh`
- `package.sh` 中集成 `.toml` 生成步骤
