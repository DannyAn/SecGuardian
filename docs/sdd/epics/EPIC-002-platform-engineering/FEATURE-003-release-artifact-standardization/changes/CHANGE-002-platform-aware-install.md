# CHANGE-002: 安装器实现平台感知——install.sh 尊重各 AI Agent 差异性

> **Feature**: FEATURE-003-release-artifact-standardization
> **日期**: 2026-07-06
> **关联 ADR**: ADR-001

## 变更描述

install.sh 从"盲拷贝"升级为"平台感知安装"——每个平台的 bundle 内置全部三个 AI Agent 格式，
install.sh 按目标平台提取对应格式的文件。

同时创建了平台安装约定文档，固化每个平台的差异性知识。

## 变更原因

用户验证发布版后发现了两个严重问题:

1. **平台特殊性被忽略**: OpenCode 需要 `codeagent-extension.json`（不是 `extension.json`），
   Gemini CLI 需要 `.toml` 命令（不是 `.md`），Claude Code 需要 `.claude-plugin/plugin.json`。
   安装器完全没考虑这些差异，导致安装后命令无法被 AI Agent 识别。

2. **知识未固化**: 平台差异性只存在于 deploy.sh 的实现中，没有独立文档解释为什么每个平台不同。
   后续维护者无法理解和遵循这些约定。

## Before

```
# 每个 OS/arch 的 bundle 只包含 extensions 的合并文件
# (含冲突: 4 个 extension.json 互相覆盖，skills 同名互相覆盖)
# install.sh 盲拷贝到目标目录，不做任何平台适配

secguardian-0.14.0-darwin-arm64.tar.gz  ← 仅 merged extensions
  ├── extension.json                    ← 最后一个扩展的，前面的被覆盖
  ├── commands/*.md
  ├── skills/cpp/                       ← secguard-cpp 和 secreview-cpp 冲突
  ├── knowledge/
  └── scripts/

# install.sh claude → 直接 cp -r 到 ~/.claude/plugins/secguardian/
# 缺少 .claude-plugin/plugin.json → Claude 无法识别
# OpenCode 情况同理 → 无 codeagent-extension.json
# Gemini 同理 → 无 .toml 命令
```

## After

```
# 每个 OS/arch 的 bundle 包含全部三个 AI 平台格式，预建好所有 manifest

secguardian-0.14.0-darwin-arm64.tar.gz
  ├── .claude-plugin/plugin.json        ← Claude Code manifest (预建)
  ├── codeagent-extension.json          ← OpenCode manifest (预建)
  ├── gemini-extension.json             ← Gemini CLI manifest (预建)
  ├── commands/
  │   ├── secguard.md                   ← .md 命令 (Claude + OpenCode)
  │   ├── secguard.toml                 ← .toml 命令 (Gemini)
  │   ├── secguardian/                  ← 命名空间命令 (Claude)
  │   └── ...
  ├── plugins/
  │   └── secguardian.js               ← OpenCode plugin script
  ├── GEMINI.md                         ← Gemini context file
  ├── skills/
  │   ├── secguard-cpp/                 ← 前缀防冲突
  │   ├── secreview-cpp/                ← 前缀防冲突
  │   └── ...
  ├── knowledge/
  └── scripts/

# install.sh claude → cp -r + 清理其他平台多余文件 + 写入正确 SECGUARDIAN_HOME
# install.sh nga     → cp -r + 清理多余文件 + 安装 opencode-plugin.js
# install.sh cac     → cp -r + 清理 .md 命令（仅留 .toml）+ 安装 GEMINI.md
# 每个内包也支持直接通过 extension manager 安装
```

## 关键差异点

| 方面 | Before | After |
|------|--------|-------|
| Bundle 内容 | 仅扩展文件合并，有文件冲突 | 3 平台全部格式预建，无冲突 |
| Skills 命名 | 可能有冲突（同名覆盖） | 命令名前缀防冲突 |
| 安装方式 | 盲拷贝 | 平台感知拷贝 + 清理 + 环境变量注入 |
| Extension Manager 兼容 | 不兼容 | 每个内包可直接用于 extension manager |
| 文档 | 无 | `docs/platform-install-conventions.md` |

## 迁移影响

- 需要重新打包 v0.14.0 release（删除旧 assets，上传新 bundle）
- deploy.sh 不受影响（保持原逻辑不变）
- install.sh 需要配合新的 bundle 格式使用（旧格式兼容无需考虑）
- 新增文档 `docs/platform-install-conventions.md`
