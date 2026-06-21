# TASK-001: 创建 sync-manifest.sh 核心同步脚本

> **Feature**: FEATURE-001-manifest-driven-tokens
> **状态**: ✅ Done
> **完成日期**: 2026-06-07
> **原则**: Task 驱动编码

## Goal

创建 `scripts/sync-manifest.sh`——从 `manifest.json` 读取权威值，更新所有文件中的 token 标记。

## Done

- [x] 脚本骨架：`set -euo pipefail` + PROJECT_ROOT 定位
- [x] `read_manifest()` — 从 manifest.json 提取所有权威值
  - [x] `detector_count` — 67
  - [x] `namespace_count` — 7
  - [x] 各 namespace 计数（memory:13, web:21, crypto:9, system:8, error:6, resource:6, concurrency:4）
- [x] `update_token()` — 核心替换逻辑
  - [x] 更新模式：`sed -i` 替换 `NNN<!-- @secguardian:name -->` 中的 NNN
  - [x] `--check` CI 模式：`grep -oP` 对比，不一致 → exit 1
- [x] Token 注册表 — 哪些文件用哪些 token
- [x] 集成到构建流程：
  - [x] `package.sh` → 构建时调用 `sync-manifest.sh`
  - [x] `self-check.sh` §7.6 → 调用 `sync-manifest.sh --check`

## Verification

```bash
# 单元验证：修改 manifest.json count → 运行脚本 → 所有文件更新
python3 -c "
import json
m = json.load(open('manifest.json'))
m['knowledge']['detectors']['count'] = 99
json.dump(m, open('manifest.json', 'w'), indent=2)
"
bash scripts/sync-manifest.sh
grep -r "99<!-- @secguardian:detector_count" . --include="*.md" | wc -l
# Expected: >= 5 files contain updated token

# CI 模式验证
bash scripts/sync-manifest.sh --check
# Expected: exit 0（全部一致）
```

## Files Changed

| 文件 | 改动 |
|------|------|
| `scripts/sync-manifest.sh` | Create (~120 行) |
| `scripts/package.sh` | +2 行（调用 sync-manifest.sh） |
| `scripts/self-check.sh` | +3 行（§7.6 --check 集成） |
