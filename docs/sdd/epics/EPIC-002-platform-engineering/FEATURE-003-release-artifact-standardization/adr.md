# ADR-001: Release Artifact 标准化设计决策

> **Feature**: FEATURE-003-release-artifact-standardization
> **ADR 编号**: ADR-001
> **日期**: 2026-07-06
> **状态**: 已接受

## 背景

v0.14.0 发布时发现构建产物格式不统一、无安装指引、产物形态由开发者随意决定。需要为后续所有版本确立标准。

## 决策 1: 单包分发

**决定**: 每个版本只在 Release 提供一个 tar.gz 下载入口，包含所有平台的所有扩展。

**理由**:
- 用户只需关心"下载最新版本"，不关心"选哪个平台哪个扩展"
- 安装器自动检测平台，消除用户决策负担
- 目前总包 ~35MB（含 5 平台二进制 + 知识文件），远小于常见项目的发布包

**否决方案**: 多包分发（每个 extension × 每个平台独立下载）— 用户需自己组合匹配，Release 页面混乱。

## 决策 2: 平台内包 + 安装器模式

**决定**: 顶层包内含各平台独立子包（tar.gz/zip）和 install.sh。安装器不是简单解压，而是读取子包、复制到目标路径。

**理由**:
- 平台独立子包 = 安装器无需在目标机上过滤文件，减少出错
- 安装器不依赖 `rsync`/`stow` 等非标准工具，只使用 bash + tar
- uninstall.sh 可精确知道哪些文件属于安装，干净移除

**否决方案**: 安装器直接解压顶层包并过滤文件 — 需额外逻辑判断哪些文件属于当前平台，Windows 更难处理。

## 决策 3: `<platform>` 缩写约定

**决定**: install.sh 接受 `claude`、`nga`、`cac` 三个缩写作为平台参数。

**理由**:
- `claude` = `--claude-code` 的合理缩写（Claude Code 普遍简称）
- `nga` = OpenCode 别名（已用于 deploy.sh `nga` 参数，保持统一）
- `cac` = `cac` from `Gemini CLI` 的已有缩写传统（已用于 deploy.sh `cac` 参数）
- 三个音节/2-3 字母，可快速输入

**否决方案**:
- `--claude-code` / `--opencode` / `--gemini-cli` — 太长，频繁输入不友好
- 长 flag 作为补充（已在 `--help` 中说明全称）

## 决策 4: Windows 用 .zip

**决定**: Windows 平台的内包使用 .zip 而非 tar.gz，其他平台全部使用 tar.gz。

**理由**:
- Windows 默认不支持 tar.gz（Windows 10 2018 后才内建 tar）
- .zip 是所有 Windows 版本都能处理的格式
- Darwin/Linux 内包用 tar.gz 保持 POSIX 权限和符号链接
- 安装器在检测到当前系统为 Windows 时自动寻找 .zip

## 决策 5: 保留 deploy.sh 作为开发部署入口，release.sh 作为发布部署入口

**决定**: 两条部署路径并存，各自有明确的使用场景。

| 路径 | 入口 | 目标用户 | 用途 |
|------|------|---------|------|
| **开发部署** | `bash scripts/deploy.sh all` | 开发者 | 开发循环中快速部署到本地 |
| **发布部署** | `bash scripts/release.sh v0.x.y` + install.sh | 用户 | 从 GitHub Release 安装 |

**理由**: 开发部署需要从 repo root 相对路径运行，读到的是未打包的文件；发布部署从 self-contained tarball 运行。两条路径使用不同的源代码路径解析逻辑，合并为一条会导致其中一方出现路径引用 bug。

## 影响

- `scripts/release.sh` — 重写产物构建逻辑
- `scripts/install.sh` — 新增文件
- `scripts/uninstall.sh` — 新增文件
- `SECURITY.md` — 可能需要更新安装指引
- `README.md` — 更新安装章节
- `docs/sdd/epics/EPIC-002-platform-engineering/FEATURE-003-release-artifact-standardization/` — 完整 SDD 包
