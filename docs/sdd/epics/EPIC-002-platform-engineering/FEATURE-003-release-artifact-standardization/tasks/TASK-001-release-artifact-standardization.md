# TASK-001: Release Artifact 标准化实现

> **Feature**: FEATURE-003-release-artifact-standardization
> **状态**: 🔨 Task
> **日期**: 2026-07-06

## 步骤

### Step 1: 重写 scripts/release.sh

- 打包逻辑改为：各 ext 平台独立包 → 聚合到单层平台包 → 顶层 tar.gz
- 不再输出 4 个独立 ext tar.gz，输出 5 个平台包 + 1 个顶层包
- 保留 SHA256SUMS 生成

### Step 2: 新增 scripts/install.sh

- `install.sh claude|nga|cac|all`
- 自动检测平台（darwin-arm64/darwin-amd64/linux-amd64/linux-arm64/windows）
- 从同目录找到对应平台的包并解压到目标路径
- 包含 `--help` 和 `--version` 参数

### Step 3: 新增 scripts/uninstall.sh

- `uninstall.sh claude|nga|cac|all`
- 删除目标路径下的所有 SecGuardian 文件

### Step 4: 验证

- 运行 `bash scripts/release.sh v0.14.0`，检查产物结构
- 解压顶层包，运行 `bash install.sh claude` 验证
- 运行 `bash uninstall.sh claude` 验证卸载

### Step 5: 推送 Release

- 删除旧 v0.14.0 Release
- 重新创建 v0.14.0 Release + tag（或直接使用新包重新上传）
- 上传新产物到 GitHub Releases
