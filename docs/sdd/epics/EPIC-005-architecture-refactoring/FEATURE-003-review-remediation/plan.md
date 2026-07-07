# Plan: Review Remediation

> **Feature**: FEATURE-003 Review Remediation
> **目标**: 修复 DeepSeek 全仓检视剩余可立即处理的问题

## Phase 1: SDD Setup (已完成)

## Phase 2: Low-Code-Risk Fixes

| # | Task | 文件 | 难度 | 风险 |
|---|------|------|------|------|
| 1 | TASK-005 H-3 | secfix.py | 低 | 无 |
| 2 | TASK-006 H-8 | render-report.py | 低 | 低 |
| 3 | TASK-004 H-2 | package.sh | 低 | 低 |

## Phase 3: Medium-Code-Risk Fixes

| # | Task | 文件 | 难度 | 风险 |
|---|------|------|------|------|
| 4 | TASK-002 A-2 | parser_re.go | 低 | 低 |
| 5 | TASK-001 C-5 | indexer.go | 中 | 中（有回退） |
| 6 | TASK-003 A-4 | secguardian-index | 中 | 低 |

## Phase 4: Verification

- self-check 通过
- 示例项目索引正常
