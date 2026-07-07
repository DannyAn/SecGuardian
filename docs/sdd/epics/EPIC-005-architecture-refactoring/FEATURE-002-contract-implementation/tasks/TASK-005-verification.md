# TASK-005: Verification — Architecture Contract Implementation

> **Feature**: FEATURE-002 Contract Implementation
> **隶属 Task**: 5 / 5
> **依赖**: TASK-001~004 完成

## 验证清单

### L1: Section Header Check

```bash
# Commands: each must have Command Layer + Engine Layer
grep "^##.*Command Layer\|^##.*Engine Layer\|^##.*Output Layer" commands/*.md

# Skills: each must have correct partition headers
grep "Detector Selection\|Engine Instructions\|Review Focus\|Audit Domain Selection" skills/*/SKILL.md
```

### L2: Contract Reference Check

```bash
# All Engine Layer groups must reference engine_contract.md
grep -rl "engine_contract.md" commands/ skills/ | wc -l
# Expected: 15 (4 commands + 11 skills)
```

### L3: Self-Check

```bash
bash scripts/self-check.sh
# Expected: 120 passed, 0 failed
```

### L4: E2E Behavior Check

```bash
bash scripts/e2e-verify.sh --quick
# Expected: exit 0 (scanning behavior unchanged)
```

## 验收标准

| # | 检查 | 预期 |
|---|------|------|
| 1 | 4 commands 有分层标记 | >= 3 section headers per file |
| 2 | 11 skills 有分区标记 | >= 2 sections per file |
| 3 | 合约引用完整 | 15 个文件引用 engine_contract.md |
| 4 | self-check | 120/0 |
| 5 | e2e 行为 | exit 0 |
