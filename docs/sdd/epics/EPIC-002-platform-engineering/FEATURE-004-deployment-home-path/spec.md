# 部署根路径设计 — SECGUARDIAN_HOME

> **Feature**: FEATURE-004-deployment-home-path
> **Epic**: EPIC-002-platform-engineering
> **状态**: 📋 Spec
> **日期**: 2026-07-04

## 1. 问题陈述

### 1.1 多路径搜索的维护负担

commands/*.md 中搜索脚本/知识文件的函数使用多路径搜索。每处搜索 8 条路径（4 平台 × 2 base），共 5 种搜索 = 80 条硬编码路径。部署结构变更时必须同步修改。

### 1.2 根因

三平台部署树结构完全一致，只有根路径不同。已知部署根路径，却用穷举搜索去猜根在哪。

## 2. 方案

### 2.1 SECGUARDIAN_HOME 环境变量

deploy.sh 在部署时向各平台 settings.json 写入 SECGUARDIAN_HOME 环境变量。

### 2.2 命令中单路径引用

```bash
# 现状（8 行搜索循环）
for base in "." "$HOME"; do
    for path in \".claude/...\" \".opencode/...\" \".config/opencode/...\" \".gemini/...\"; do
        ...
    done
done

# 方案（1 行）
INDEXER="${SECGUARDIAN_HOME:-scripts}/secguardian-index"
```

### 2.3 适用场景

| 场景 | SECGUARDIAN_HOME 值 | 效果 |
|------|--------------------|------|
| Claude Code 部署 | ~/.claude/plugins/secguardian | 找到部署的脚本 |
| OpenCode 部署 | ~/.config/opencode/extensions/secguardian | 同上 |
| Gemini CLI 部署 | ~/.gemini/extensions/secguardian | 同上 |
| 开发模式（未设置） | 缺省 scripts/ | 从 repo root 相对路径运行 |
