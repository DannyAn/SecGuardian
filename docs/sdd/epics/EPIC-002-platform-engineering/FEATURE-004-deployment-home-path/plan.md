# 部署根路径设计 — 实施计划

> **Feature**: FEATURE-004-deployment-home-path
> **Epic**: EPIC-002-platform-engineering
> **状态**: 📐 Plan

**Architecture:** deploy.sh → settings.json env → commands/*.md $VAR

### TASK-001: deploy.sh 三平台注入 SECGUARDIAN_HOME
**Files:** scripts/deploy.sh (3 deploy 函数各加一行)
```python
data.setdefault('env', {})['SECGUARDIAN_HOME'] = '<ext_dir>'
```

### TASK-002: commands/*.md 替换多路径搜索
**Files:** commands/secguard.md, secaudit.md, secreview.md
**搜索函数:** find_indexer, RECORDER, RENDERER, find_protocol, LANG_INDEX
**替换为:** `${SECGUARDIAN_HOME:-scripts}/name`

### TASK-003: 重新生成 TOML + 部署 + 验证
```bash
bash scripts/gen-toml.sh && bash scripts/deploy.sh all
```
