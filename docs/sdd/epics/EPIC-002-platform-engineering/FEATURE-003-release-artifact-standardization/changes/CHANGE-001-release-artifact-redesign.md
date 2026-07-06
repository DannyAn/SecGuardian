# CHANGE-001: 从多包模式迁移到单包分发模式

> **Feature**: FEATURE-003-release-artifact-standardization
> **日期**: 2026-07-06
> **关联 ADR**: ADR-001

## 变更描述

Release 产物格式从"多包独立下载"改为"单包 + 平台内包 + 安装器"模式。

## 变更原因

原 release.sh 产物格式未经过设计评审，直接上传了 4 个 extension tar.gz + 单独二进制，用户下载后无法直接使用。缺失安装脚本指导安装。

## Before

```
GitHub Release Assets:
  secguard-secguardian-0.14.0.tar.gz    ← ext 独立包
  secaudit-secguardian-0.14.0.tar.gz    ← ext 独立包
  secreview-secguardian-0.14.0.tar.gz   ← ext 独立包
  secfix-secguardian-0.14.0.tar.gz      ← ext 独立包
  bin/secguardian-index-darwin-arm64    ← 二进制单独放
  bin/secguardian-index-darwin-amd64    ← 二进制单独放
  ...                                    ← 用户不知如何组合使用
```

## After

```
GitHub Release Assets:
  secguardian-0.14.0.tar.gz             ← ★ 唯一需要下载的包
    ├── install.sh                      ← bash install.sh claude|nga|cac
    ├── uninstall.sh                    ← bash uninstall.sh claude|nga|cac
    ├── secguardian-0.14.0-darwin-arm64.tar.gz
    ├── secguardian-0.14.0-darwin-amd64.tar.gz
    ├── secguardian-0.14.0-linux-amd64.tar.gz
    ├── secguardian-0.14.0-linux-arm64.tar.gz
    └── secguardian-0.14.0-windows-amd64.zip
  SHA256SUMS                            ← 外层校验文件
```

## 迁移影响

- 无向前兼容问题（旧 releases 已全部清理）
- deploy.sh 开发部署路径不变化
- install.sh 新增，不影响任何现有工具链
