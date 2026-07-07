# Release Artifact 标准化 — 实现计划

> **Feature**: FEATURE-003-release-artifact-standardization
> **Epic**: EPIC-002-platform-engineering
> **状态**: 📐 Plan
> **日期**: 2026-07-06

## 改动清单

| # | 文件 | 操作 | 说明 |
|---|------|------|------|
| 1 | `scripts/release.sh` | 重写 | 改为单包 + 平台内包结构 |
| 2 | `scripts/install.sh` | 新增 | 统一安装器 |
| 3 | `scripts/uninstall.sh` | 新增 | 统一卸载器 |
| 4 | `scripts/package.sh` | 微调 | 确保`dist/` 结构满足新 release 需求 |
| 5 | `docs/sdd/epics/EPIC-002-platform-engineering/epic.md` | 更新 | 添加 FEATURE-003 状态 |

## 不修改的文件

- `scripts/deploy.sh` — 开发部署路径保持不变
- `commands/*.md` — 安装方式不改变运行时行为
- `SECURITY.md` — 后续 PR 再更新

## implement.sh / uninstall.sh 设计

### install.sh

```bash
#!/bin/bash
# SecGuardian — 统一安装器
# 用法: bash install.sh [claude|nga|cac|all]
# 自动检测当前平台（darwin-arm64/darwin-amd64/linux-amd64/linux-arm64/windows-amd64）
# 从同目录下读取对应平台的压缩包，复制到目标路径

DETECTED_PLATFORM=$(detect_platform)   # uname -s + uname -m
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 找到匹配当前平台的包
# darwin-arm64 → secguardian-*-darwin-arm64.tar.gz
# windows-amd64 → secguardian-*-windows-amd64.zip

# 安装到目标:
# claude → $HOME/.claude/plugins/secguardian/
# nga → $HOME/.config/opencode/extensions/secguardian/
# cac → $HOME/.gemini/extensions/secguardian/
```

### uninstall.sh

```bash
bash uninstall.sh claude   # rm -rf ~/.claude/plugins/secguardian/
bash uninstall.sh cac      # rm -rf ~/.gemini/extensions/secguardian/
bash uninstall.sh all      # 全部删除
```

## 执行顺序

1. 重写 `scripts/release.sh` — 改为新产物结构
2. 新增 `scripts/install.sh`
3. 新增 `scripts/uninstall.sh`
4. 微调 `scripts/package.sh`（如有需要）
5. 运行 `bash scripts/release.sh v0.14.0` 验证
6. 本地测试 install.sh / uninstall.sh
7. 更新 epic.md 状态
