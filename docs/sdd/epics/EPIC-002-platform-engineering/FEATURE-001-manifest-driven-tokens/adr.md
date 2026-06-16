# ADR — Manifest-Driven Tokens Architecture Decision

> **Feature**: FEATURE-001-manifest-driven-tokens
> **原则**: Brainstorm 决定方向 → ADR 记录决策

---

## ADR-001: HTML 注释标记 vs 模板引擎

**日期**: 2026-06-07
**状态**: ✅ Accepted

### Decision

采用 `NNN<!-- @secguardian:token_name -->` HTML 注释标记格式，而非引入模板引擎。

`sync-manifest.sh` 读取 `manifest.json` 权威值，用 `sed` 替换标记前的数字。

### Reason

- **人类可读**：部署后的 Markdown 文件中标记是 HTML 注释，不影响渲染
- **零依赖**：不需要 Jinja2/Handlebars/Mustache 等模板引擎
- **Git 友好**：diff 只显示数字变化，不破坏文件结构
- **CI 可验证**：`--check` 模式简单比对数字，非零退出码

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| **Jinja2 模板** | 引入 Python 依赖，构建流程复杂化 |
| **Handlebars/Mustache** | 引入 Node.js 依赖，过度工程 |
| **Git hooks 自动替换** | 在 commit 时修改文件，开发者困惑 |
| **CI 仅警告不阻断** | 警告会被忽略——必须非零退出码强制修复 |
| **YAML frontmatter 变量** | Markdown 解析器兼容性不确定 |

### Consequences

- `scripts/sync-manifest.sh` 成为构建关键路径（`package.sh` → `deploy.sh` 调用链）
- `self-check.sh` §7.6 集成 `--check` 模式
- 新增 detector 时只需改 `manifest.json` + 写 detector 文件，其他文件自动同步
