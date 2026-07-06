# Release Artifact 标准化 — 进度追踪

> **Feature**: FEATURE-003-release-artifact-standardization
> **Epic**: EPIC-002-platform-engineering

## 当前状态

- [x] Spec 完成
- [x] ADR 完成
- [x] Plan 完成
- [x] Spec 已完成
- [x] ADR 已完成
- [x] Plan 已完成
- [x] Task 已完成
- [x] Install.sh 已实现
- [x] Uninstall.sh 已实现
- [x] Release.sh 已重写
- [x] 验证通过（平台包结构确认正确）
- [x] v0.14.0 已重新发布
- [x] macOS sha256sum 兼容性已修复

## CHANGE-002

- [x] 平台感知安装: install.sh 实现 per-platform 文件选择 + 正确 manifest + SECGUARDIAN_HOME
- [x] Skills 冲突修复: release.sh 使用命令名前缀合并 skill 目录
- [x] 平台 manifests 预建: .claude-plugin/plugin.json, codeagent-extension.json, gemini-extension.json
- [x] Gemini .toml 命令: 内包包含 TOML 格式命令
- [x] OpenCode plugin: plugins/secguardian.js 安装
- [x] Extension Manager 兼容: 每个内包可直接用于 claude plugin install
- [x] 参考文档: docs/platform-install-conventions.md 固化平台差异性
