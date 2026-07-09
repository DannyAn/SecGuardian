# AI Agent 平台安装约定

> 本文档固化三个目标平台（Claude Code / OpenCode / Gemini CLI）的安装约定，
> 供 `install.sh`、`release.sh` 和 `deploy.sh` 维护参考。
>
> **原则**: 每个 AI Agent 平台都有自己的 extension manager 格式要求，
> 安装时必须遵循对应规范，否则命令无法被识别。

## 总览

| 方面 | Claude Code | OpenCode | Gemini CLI (cac) |
|------|-------------|----------|-----------------|
| 目标目录 | `~/.claude/plugins/secguardian/` | `~/.config/opencode/extensions/secguardian/` | `~/.gemini/extensions/secguardian/` |
| Manifest 文件名 | `.claude-plugin/plugin.json` | `codeagent-extension.json` | `gemini-extension.json` |
| 命令格式 | `.md` Markdown | `.md` Markdown | `.toml` |
| 额外文件 | `commands/secguardian/` 命名空间 | `plugins/secguardian.js` | `GEMINI.md` |
| 平台入口 | `/secguard <path>` 等 | `/secguard <path>` 等 | `/secguard <path>` 等 |
| SECGUARDIAN_HOME | `~/.claude/plugins/secguardian` | `~/.config/opencode/extensions/secguardian` | `~/.gemini/extensions/secguardian` |

## 详细约定

### 1. Manifest 文件名差异

每个平台要求的 manifesto/extension 文件名不同，这是**最容易出错的地方**：

| 平台 | 文件名 | 为什么不同 |
|------|--------|-----------|
| **Claude Code** | `.claude-plugin/plugin.json` | Claude Code 的插件系统要求 manifest 以 `.claude-plugin/plugin.json` 格式放置 |
| **OpenCode** | `codeagent-extension.json` | OpenCode 扩展管理器识别 `codeagent-extension.json`（不是 `extension.json`） |
| **Gemini CLI** | `gemini-extension.json` | Gemini CLI 扩展系统识别 `gemini-extension.json` |

**安装时不能简单复制 extension.json，必须使用对应平台的 manifest 文件名。**

### 2. 命令文件格式

| 平台 | 命令文件格式 | 示例 | 说明 |
|------|------------|------|------|
| **Claude Code** | `.md` | `commands/claude/secguard.md` (源) → `commands/secguard.md` (部署) | Markdown 格式，YAML frontmatter |
| **OpenCode** | `.md` | `commands/opencode/secguard.md` (源) → `commands/secguard.md` (部署) | 同 Claude 的 .md 格式 |
| **Gemini CLI** | `.toml` | `commands/gemini/secguard.toml` | TOML 格式，由 `gen-toml.sh` 从 `commands/claude/` 生成 |

Gemini CLI **不支持** `.md` 命令文件，必须使用 `.toml`。反之亦然——Claude Code 和 OpenCode 不支持 `.toml`。

### 3. 目标目录结构

```
# Claude Code (~/.claude/plugins/secguardian/)
.claude-plugin/
  plugin.json            # 官方 manifest
commands/
  secguard.md            # .md slash commands
  secaudit.md
  secreview.md
  secfix.md
  secguardian/           # 命名空间子目录
    secguard.md          # /secguardian:secguard
    secaudit.md          # /secguardian:secaudit
    secreview.md         # /secguardian:secreview
    secfix.md            # /secguardian:secfix
skills/                  # 所有 skill 目录
  secguard-cpp/
  secaudit-input-validation/
  secreview-cpp/
  secfix-.../
knowledge/               # detector + language + protocol + standard 知识库
scripts/                 # 工具脚本 + 二进制
.secguardian-env         # SECGUARDIAN_HOME 环境变量

# OpenCode (~/.config/opencode/extensions/secguardian/)
codeagent-extension.json # 官方 manifest
commands/                # .md commands (同上)
skills/
knowledge/
scripts/
.secguardian-env

# plugins/secguardian.js 安装到 ~/.config/opencode/plugins/secguardian.js

# Gemini CLI (~/.gemini/extensions/secguardian/)
gemini-extension.json    # 官方 manifest
commands/                # .toml commands
skills/
knowledge/
scripts/
GEMINI.md                # Gemini 上下文文件
.secguardian-env
```

### 4. Skill 命名规则

当每个命令扩展有同名的 skill（如 `secguard` 和 `secreview` 都有 `cpp` skill），
部署时用命令名做前缀以避免冲突：

| 来源 | 原始 Skill 名 | 部署后 Skill 名 |
|------|-------------|----------------|
| `secguard-secguardian` | `skills/cpp/` | `skills/secguard-cpp/` |
| `secreview-secguardian` | `skills/cpp/` | `skills/secreview-cpp/` |
| `secaudit-secguardian` | `skills/secaudit/` | `skills/secaudit-secaudit/` |

规则: `$(basename "$ext_dir" | sed 's/-secguardian//')-$(basename "$skill_dir")`
即去掉 `-secguardian` 后缀，然后 `command-skillname`。

### 5. 额外文件

| 文件 | 用途 | 安装到 |
|------|------|--------|
| `.claude-plugin/plugin.json` | Claude Code 官方插件 manifest，用于 marketplace 注册 | Claude: `~/.claude/plugins/secguardian/.claude-plugin/plugin.json` |
| `codeagent-extension.json` | OpenCode 扩展 manifest | OpenCode: `~/.config/opencode/extensions/secguardian/codeagent-extension.json` |
| `gemini-extension.json` | Gemini CLI 扩展 manifest | Gemini: `~/.gemini/extensions/secguardian/gemini-extension.json` |
| `plugins/secguardian.js` | OpenCode 插件脚本（从 `scripts/opencode-plugin.js` 复制） | OpenCode: `~/.config/opencode/plugins/secguardian.js` |
| `commands/secguardian/*.md` | Claude Code 命名空间命令，防命令冲突 | Claude: `~/.claude/plugins/secguardian/commands/secguardian/` |
| `commands/*.toml` | Gemini CLI TOML 格式命令（由 gen-toml.sh 生成） | Gemini: `~/.gemini/extensions/secguardian/commands/` |
| `GEMINI.md` | Gemini CLI 上下文文件，在 `~/.gemini/extensions/` 下自动加载 | Gemini: `~/.gemini/extensions/secguardian/GEMINI.md` |
| `.secguardian-env` | Shell 环境变量配置文件，设置 SECGUARDIAN_HOME | 所有平台对应目录 |

### 6. 二进制位置

所有平台的 indexer 二进制文件路径一致:
```
scripts/bin/secguardian-index     ← 可执行二进制
scripts/secguardian-index.ps1     ← Windows PowerShell 包装脚本
```

### 7. Claude Code 额外步骤：Marketplace 注册

Claude Code 插件安装后必须通过 marketplace 注册才能被识别：

```bash
# 创建本地 marketplace
mkdir -p ~/.claude/plugins/marketplaces/secguardian-local/.claude-plugin

# 编写 marketplace.json
cat > ~/.claude/plugins/marketplaces/secguardian-local/.claude-plugin/marketplace.json << JSON
{
  "name": "secguardian-local",
  "plugins": ["plugins/secguardian"]
}
JSON

# 创建 symlink
mkdir -p ~/.claude/plugins/marketplaces/secguardian-local/plugins
ln -sfn ~/.claude/plugins/secguardian \
  ~/.claude/plugins/marketplaces/secguardian-local/plugins/secguardian

# 注册 marketplace
claude plugin marketplace add ~/.claude/plugins/marketplaces/secguardian-local 2>/dev/null || true

# 安装插件
claude plugin install secguardian@secguardian-local 2>/dev/null || true
```

`deploy.sh` 的 `register_claude_plugin()` 函数已自动完成此步骤。

### 8. Gemini CLI: `.toml` 命令生成

`.toml` 命令由 `gen-toml.sh` 从 `.md` 命令自动生成：

```bash
bash scripts/gen-toml.sh
# 生成到 commands/gemini/*.toml
```

生成规则:
- `description`: 从 `.md` YAML frontmatter 的 `description` 字段提取
- `prompt`: 跳过 frontmatter，将正文嵌入 TOML multiline string
- `{{args}}` 占位符: 自动插入在 prompt 开头

## 验证清单

在实现新平台安装时，检查以下项目:

- [ ] Manifest 文件使用正确的文件名
- [ ] 命令文件使用正确的格式 (.md vs .toml)
- [ ] Skills 使用命令名前缀
- [ ] 平台额外文件已包含
- [ ] SECGUARDIAN_HOME 指向正确路径
- [ ] 二进制可执行权限已设置
- [ ] (Claude) Marketplace 已注册
