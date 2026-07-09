# GEMINI.md — SecGuardian for Gemini CLI (薄引用层)

> ⚠️ **本文件只包含 Gemini CLI 平台特有的命令用法。**
> **所有共享内容（架构/SDD/构建/验证/发布）以 [`AGENTS.md`](AGENTS.md) 为准，本文件不重复。**

## 规范来源索引

| 主题 | 规范位置 (AGENTS.md) | 说明 |
|------|---------------------|------|
| 项目架构/数据流/索引器 | AGENTS.md §核心架构 | Tree-sitter 双解析器、能力边界 |
| SDD 规格开发流程 | AGENTS.md §开发守则第一条 | 七环流程，任何非 trivial 改动前必读 |
| 构建与部署 | AGENTS.md §构建与部署 | deploy.sh / dev-verify.sh 用法 |
| 验证流程 L1-L5 | AGENTS.md §验证流程 | 按修改范围选择验证层 |
| 版本发布 | AGENTS.md §版本发布 | 单入口 scripts/release.sh |
| Manifest Tokens | AGENTS.md §Manifest-Driven Tokens | 修改 detector 数量流程 |

## 命令使用

```
/secguard ./src cpp          # 安全加固扫描（支持 cpp/go/java/python/js）
/secguard ./src *            # 全量扫描，自动检测语言
/secaudit ./src python       # 全量安全审计（13 个审计域）
/secreview ./src java        # 安全编码规范检视
/secfix ./src cpp           # 修复建议生成 (输出 patch files)
```

首次使用需执行 `/skills reload` 让 Gemini CLI 扫描 skills 目录。

## 扫描输出

扫描结果在 `.codeagent/<extension-name>/scans/<scan-id>/`:

```
├── findings/          # ★ v5.0: 按 detector 分类的 finding 目录树
├── findings.json      # 轻量索引（同名升级，不含四段式详情）
├── report.md          # 人读审计报告（六章）
├── results.sarif      # SARIF 2.1.0 (CI/CD 集成)
├── summary.json       # 仪表盘统计
├── manifest.json      # 扫描元数据
├── status.json        # CI 门禁
└── delta.json         # 增量对比
```

## 部署位置

| 源码 | 部署后 (Gemini CLI) |
|------|-------------------|
| `skills/secguard/cpp/SKILL.md` | `.gemini/extensions/secguardian/skills/` |
| `skills/secguard/{lang}/rules/{detector}/rule.md` | `.gemini/extensions/secguardian/skills/` |
| `skills/secaudit/rules/*.md` | `.gemini/extensions/secguardian/skills/secaudit/rules/` |
| `skills/secreview/{lang}/rules/{lang}.md` | `.gemini/extensions/secguardian/skills/secreview/rules/` |
| `knowledge/protocols/*.md` | `.gemini/extensions/secguardian/knowledge/protocols/` |
| `knowledge/standards/*.md` | `.gemini/extensions/secguardian/knowledge/standards/` |
