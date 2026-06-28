# FEATURE-007: 共享索引 — 跨命令复用 index.json

> **隶属 Epic**: EPIC-001 Core Scanning Engine
> **版本**: v0.1 (Draft) | **日期**: 2026-06-28

## 1. Problem Statement

当前每次扫描都在 `scans/<scan-id>/` 下重新生成 `index.json`，
同一仓库的多次扫描产生 N 份完全相同的索引，浪费 token 和时间。
实测 225 文件 Java 项目 index.json 达 463KB，索引时间 30-120s。

## 2. Requirements

### REQ-001: 共享索引
三个命令（secguard/secaudit/secreview）共用 `.codeagent/secguardian/index.json`。
首次扫描自动创建，后续自动复用。

### REQ-002: 目录重组
`<cmd>-secguardian/scans/` → `secguardian/<cmd>/scans/`
旧目录（`secguard-secguardian/` 等）保持不动。

### REQ-003: 自动复用
AI 检查 `.codeagent/secguardian/index.json` 是否存在：
- 存在 → 跳过索引器，直接检测
- 不存在 → 先索引，再检测

### REQ-004: --force 刷新
`/secguard ./src java --force` 或 `-f` 强制重建索引。

### REQ-005: 索引来源透明
扫描摘要输出索引来源（新建/复用），帮助用户理解等待时间。

## 3. Design

```
.codeagent/secguardian/
├── index.json              # ★ 共享索引（所有命令复用）
├── secguard/scans/<id>/    # 输出同当前格式，只移 index.json 到公共位置
├── secaudit/scans/<id>/
└── secreview/scans/<id>/
```

索引生命周期:
```
第 1 次: index.json ?→ 不存在 → 索引器 → 写入共享路径 → 检测
第 2 次: index.json ?→ 存在   → 跳过索引 → 检测
--force:  强制重建索引 → 覆盖共享路径中的 index.json
```

CLI:
```
/secguard ./src java                  # 自动复用
/secguard ./src java --force          # 强制刷新
/secaudit ./src python -f
```

## 4. Out of Scope
- 旧扫描数据迁移
- 增量索引
- 自动过期 TTL