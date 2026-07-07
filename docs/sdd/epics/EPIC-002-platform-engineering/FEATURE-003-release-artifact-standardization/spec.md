# Release Artifact 标准化 — 单包分发 + 统一安装器

> **Feature**: FEATURE-003-release-artifact-standardization
> **Epic**: EPIC-002-platform-engineering
> **状态**: 📋 Spec
> **日期**: 2026-07-06

## 1. 问题陈述

### 1.1 历史 Release 产物混乱

v0.3.1 ~ v0.13.0 期间，GitHub Releases 只有 GitHub 自动生成的 `source.tar.gz`，无构建产物。用户下载后不知如何安装。v0.14.0 修复了构建系统并上传了产物，但产物形态被随意修改（从 platform zip → extension tar.gz），未经设计评审。

### 1.2 具体问题

| 问题 | 表现 | 严重度 |
|------|------|--------|
| **无统一入口** | 每个 extension 独立 tar.gz，用户不知道"下哪个" | P0 |
| **无安装脚本** | 用户下载后需手动了解 deploy.sh 逻辑才能安装 | P0 |
| **产物格式反复** | 发版流程无规范，每次全凭开发者个人判断 | P1 |
| **平台和 extension 的交叉产物** | 4 ext × 5 platform = 20 组合，用户需自己匹配 | P2 |
| **Windows 不友好** | tar.gz 在 Windows 默认无法解压 | P2 |

### 1.3 消费者分析

| 角色 | 下载后第一步 | 关心的 |
|------|------------|--------|
| **Claude Code 用户** | 装到 ~/.claude/plugins/ | 一个命令装完 |
| **OpenCode 用户** | 装到 ~/.config/opencode/extensions/ | 同上 |
| **Gemini CLI 用户** | 装到 ~/.gemini/extensions/ | 同上 |
| **CI/CD 工程师** | 在 pipeline 中自动化安装 | 可脚本化、可校验 |

**结论：用户不想理解扩展包结构，只想一条命令完成安装。**

## 2. 方案

### 2.1 产物形态

```
# 📦 GitHub Release Assets —— 只有一个包需要下载

secguardian-0.14.0.tar.gz                ← ★ 唯一需要下载的包（~35MB）
SHA256SUMS                                ← 校验文件（单独提供）

# 解压后内容
secguardian-0.14.0/
├── install.sh                            ← bash install.sh claude | nga | cac
├── uninstall.sh                          ← bash uninstall.sh claude | nga | cac
├── README.md                             ← 快速开始
├── secguardian-0.14.0-darwin-arm64.tar.gz ← 内含 4 个 extension + 正确二进制
├── secguardian-0.14.0-darwin-amd64.tar.gz
├── secguardian-0.14.0-linux-amd64.tar.gz
├── secguardian-0.14.0-linux-arm64.tar.gz
└── secguardian-0.14.0-windows-amd64.zip   ← Windows 用户用 .zip
```

### 2.2 安装器行为

```
bash install.sh                    → 自动检测平台 + 列出可用目标
bash install.sh claude             → 解压对应平台包 → 写入 ~/.claude/plugins/secguardian/
bash install.sh nga                → 解压 → 写入 ~/.config/opencode/extensions/secguardian/
bash install.sh cac                → 解压 → 写入 ~/.gemini/extensions/secguardian/
bash install.sh all                → 安装到全部三个平台
bash install.sh --help             → 查看用法

bash uninstall.sh claude           → 删除 ~/.claude/plugins/secguardian/
bash uninstall.sh nga              → 删除 ~/.config/opencode/extensions/secguardian/
bash uninstall.sh cac              → 删除 ~/.gemini/extensions/secguardian/
bash uninstall.sh all              → 全部卸载
```

### 2.3 每个平台包的内容

```
secguardian-0.14.0-darwin-arm64.tar.gz
├── secguard-secguardian/            ← /secguard 命令
├── secaudit-secguardian/            ← /secaudit 命令
├── secreview-secguardian/           ← /secreview 命令
├── secfix-secguardian/              ← /secfix 命令
├── scripts/bin/secguardian-index    ← 单一平台二进制（无平台后缀）
├── scripts/secguardian-index        ← shell wrapper
├── scripts/secguardian-index.ps1    ← powershell wrapper
├── scripts/record-finding.py        ← 辅助脚本
├── scripts/validate-index.py
├── scripts/validate-findings.py
├── scripts/opencode-plugin.js
├── .claude-plugin/plugin.json       ← 插件元数据（仅 Claude Code）
└── extension.json                   ← extension 元数据（OpenCode / Gemini）
```

**关键设计**：平台的 tar.gz 不是简单压缩 extension 目录，而是将 4 个 extension 合并为一个统一包。安装器复制文件而非解压到目标位置，避免目录嵌套问题。

### 2.4 否决的方案

| 方案 | 否决理由 |
|------|---------|
| 每个 extension 独立下载 | 用户需要下载 4 次，平台匹配靠自己 |
| 单一扁平目录（无平台包） | 同一包包含所有平台二进制，无端膨胀（3×3MB = 9MB 浪费） |
| npm/Pip/Homebrew 分发 | 需要注册包管理器和维护元数据，当前阶段过度重 |
| Docker 镜像 | 产品定位是 AI Agent extension，不是容器化服务 |

## 3. 成功标准

1. **单 URL 下载** — Release 页面只有一个 tar.gz 需要下载
2. **三行安装** — `tar xzf secguardian-*.tar.gz && cd secguardian-* && bash install.sh claude`
3. **跨平台一致体验** — macOS / Linux / Windows 都支持
4. **可校验** — SHA256SUMS 每个版本都有
5. **可卸载** — uninstall.sh 干净移除
6. **向后兼容** — `deploy.sh` 保持不变，`release.sh` 重构产物格式

## 4. 不纳入范围的

- 包管理器注册（Homebrew/npm/Pip）
- Docker 镜像构建
- CI/CD pipeline 自动发布
- MCP Server 的独立分发
- 版本升级时的增量迁移逻辑
