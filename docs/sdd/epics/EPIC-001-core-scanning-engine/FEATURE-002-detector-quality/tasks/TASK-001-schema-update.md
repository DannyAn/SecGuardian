# TASK-001: findings-schema.json 新增 evidence 子字段

> **Feature**: FEATURE-002-detector-quality
> **状态**: ✅ Done
> **完成日期**: 2026-06-11
> **原则**: Task 驱动编码

## Goal

在 `findings-schema.json` 的 `evidence` 对象中新增 3 个字段，支撑 MUST/SHOULD/MAY 三级证据体系。

## Done

- [x] 新增 `call_stack` — 调用链（入口函数到漏洞位置的完整调用栈）
  - [x] 字段: `function`, `file`, `line`, `depth`
- [x] 新增 `variable_state` — 关键变量快照（触发点的值/类型/约束）
  - [x] 字段: `variable_name`, `inferred_value`, `type`, `constraints`
- [x] 新增 `sanitizer_analysis` — 消毒函数分析
  - [x] 字段: `sanitizer_present`, `sanitizer_name`, `bypass_reason`, `verdict`
  - [x] `verdict` enum: `no_sanitizer` / `sanitizer_bypassed` / `sanitizer_insufficient` / `sanitizer_adequate`
- [x] JSON Schema 格式校验通过

## Verification

```bash
python3 -c "import json; json.load(open('knowledge/protocols/findings-schema.json')); print('VALID')"
# Expected: VALID
```

## Files Changed

| 文件 | 改动 |
|------|------|
| `knowledge/protocols/findings-schema.json` | +50 行（3 个新 evidence 子字段） |
