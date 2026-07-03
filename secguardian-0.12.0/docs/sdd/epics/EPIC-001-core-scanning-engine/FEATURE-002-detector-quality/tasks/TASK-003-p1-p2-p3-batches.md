# TASK-003: P1+P2+P3 — 61 个检测器分批标准化

> **Feature**: FEATURE-002-detector-quality
> **状态**: ✅ Done
> **完成日期**: 2026-06-13 (P1) / 2026-06-14 (P2+P3)
> **原则**: Task 驱动编码 — 按质量分层，均衡推进

## Goal

剩余 61 个检测器按当前质量分三批推进，统一到 7 章节模板。

## Done

### P1: 13 个 content-light 检测器（<90 行）
- [x] concurrency: `data-race`, `deadlock`, `race-condition`, `thread-unsafe-signal`
- [x] error: `debug-mode-production`, `exception-swallow`, `log-sensitive-data`, `panic-to-client`, `stack-trace-leak`, `unified-error-format`
- [x] resource: `file-leak`
- [x] system: `insecure-temp-file`, `symlink-attack`

工作内容：补充 FP 排除 + 证据收集 + 检测逻辑丰富化

### P2: 28 个中等质量检测器
- [x] memory (13): `bad-cast`, `buffer-overflow`, `double-free`, `format-string`, `heap-buffer-overflow`, `integer-overflow`, `memory-leak`, `mismatched-free`, `null-dereference`, `off-by-one`, `oob-read`, `uninitialized-memory`, `use-after-free`
- [x] system (5): `command-injection`, `insecure-permissions`, `path-traversal`, `privilege-escalation`, `toctou`
- [x] crypto (5): `aes-ecb-mode`, `hardcoded-iv`, `insufficient-key-length`, `tls-version`, `weak-crypto-algorithm`
- [x] resource (3): `file-leak`, `lock-misuse`, `refcount-misuse`
- [x] web (2): `open-redirect`, `resource-exhaustion`

工作内容：格式标准化 + FP 排除补充 + 证据收集指引

### P3: 20 个已完善检测器
- [x] web (19): `auth-bypass`, `code-injection`, `csrf`, `deserialization`, `excessive-data-exposure`, `idor`, `input-validation`, `jwt-misuse`, `mass-assignment`, `missing-authentication`, `missing-authorization`, `nosql-injection`, `prototype-pollution`, `sql-injection`, `ssrf`, `ssti`, `unrestricted-upload`, `xss`, `xxe`
- [x] crypto (1): `password-storage`

工作内容：格式标准化 + 新增 precision/confidence 元数据（内容已完善）

## Verification

```bash
# 全量结构验证
bash scripts/self-check.sh
# Expected: 67/67 detectors pass structural checks

# L1 设计一致性
bash scripts/self-check.sh
# → detector ↔ index ↔ manifest 交叉校验全绿
```

## Files Changed

| 批次 | 文件数 | 平均增量 |
|------|--------|---------|
| P1 | 13 | +30 行/detector |
| P2 | 28 | +20 行/detector |
| P3 | 20 | +10 行/detector |
| **总计** | **61** | **+1,100 行** |
