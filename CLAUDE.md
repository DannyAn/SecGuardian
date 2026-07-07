# CLAUDE.md — SecGuardian for Claude Code (薄引用层)

> ⚠️ **本文件只包含 Claude Code 平台特有的注册/命名空间信息。**
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

## Claude Code 插件注册机制

**Claude Code v2.1.x 不会自动发现仅靠文件复制的本地插件**。插件必须通过 marketplace 系统注册：

1. 插件文件部署到 `~/.claude/plugins/secguardian/`
2. 创建本地 marketplace 结构：`~/.claude/plugins/marketplaces/secguardian-local/`
3. `marketplace.json` 必须位于 `.claude-plugin/` 子目录下（非根目录）
4. 通过 `claude plugin marketplace add` + `claude plugin install` 注册
5. `deploy.sh` 已自动化以上全部流程（含 CLI 不可用时的 JSON 回退）

**验证插件已安装：**
```bash
claude plugin list                    # 查看 secguardian@secguardian-local 状态
claude plugin validate ~/.claude/plugins/secguardian  # 验证插件结构
```

**部署目标（实际路径，并非 `extensions/`）：**
- Claude Code → `~/.claude/plugins/secguardian/`
- OpenCode   → `~/.opencode/plugins/secguardian/`
- Gemini CLI → `~/.gemini/extensions/secguardian/`

## 命令命名空间策略 (防冲突)

当其他公司也开发了 `secguard`/`secaudit`/`secreview` 命令时，通过以下机制确保互不影响：

| 机制 | 说明 |
|------|------|
| **短命令名** | `/secguard`、`/secaudit`、`/secreview` — 日常便捷使用 |
| **命名空间命令** | `/secguardian:secguard`、`/secguardian:secaudit`、`/secguardian:secreview` — 通过 `commands/secguardian/` 子目录自动获得插件名前缀 |
| **Claude Code 原生歧义消除** | 命令冲突时 Claude Code 自动展示所有匹配命令及来源插件，用户可选择 |
| **插件名即命名空间** | `plugin.json` 中 `"name": "secguardian"` 作为全局唯一标识 |

**实现方式**：`commands/` 目录同时包含平铺命令文件和 `secguardian/` 子目录副本：
```
commands/
├── secguard.md           # /secguard (短名)
├── secaudit.md           # /secaudit (短名)
├── secreview.md          # /secreview (短名)
└── secguardian/          # 子目录 = 命名空间
    ├── secguard.md       # /secguardian:secguard (命名空间名)
    ├── secaudit.md       # /secguardian:secaudit (命名空间名)
    └── secreview.md      # /secguardian:secreview (命名空间名)
```

## 部署后项目结构

```
~/.claude/
├── plugins/
│   ├── secguardian/                      # 插件源文件（marketplace symlink 目标）
│   │   ├── .claude-plugin/plugin.json
│   │   ├── commands/
│   │   │   ├── secguard.md               # /secguard
│   │   │   ├── secaudit.md               # /secaudit
│   │   │   ├── secreview.md              # /secreview
│   │   │   └── secguardian/              # 命名空间子目录
│   │   │       ├── secguard.md           # /secguardian:secguard
│   │   │       ├── secaudit.md           # /secguardian:secaudit
│   │   │       └── secreview.md          # /secguardian:secreview
│   │   ├── skills/                       # 17 个安全审计 skills
│   │   ├── knowledge/                    # 60 检测器 + 5 语言画像 + 协议
│   │   └── scripts/                      # secguardian-index 二进制
│   ├── cache/secguardian-local/          # 插件缓存（claude plugin install 创建）
│   ├── marketplaces/secguardian-local/   # 本地 marketplace
│   │   ├── .claude-plugin/marketplace.json
│   │   └── plugins/secguardian -> ../../../secguardian  (symlink)
│   └── installed_plugins.json            # 插件注册表
└── settings.json                         # enabledPlugins 条目
```
