# Plan: Scan Performance Optimization

> **Feature**: FEATURE-004 Scan Performance Optimization
> **Epic**: EPIC-005 Architecture Refactoring
> **目标**: 8 文件扫描耗时 16m47s → ≤3min

## Phases

### Phase 1: SDD Setup (已完成)

### Phase 2: Commands Optimization

| # | Task | 改动 | 预期提升 |
|---|------|------|---------|
| 1 | TASK-001: 前置检查 9→2 | 删除9项独立check，替换为--health + 路径检查 | 27s→3s |
| 2 | TASK-002: Finding 批量写入 | 删除逐条写入指令，替换为 findings.json 单次输出 | 19s→2s |

### Phase 3: Skills Optimization

| # | Task | 改动 | 预期提升 |
|---|------|------|---------|
| 3 | TASK-003: 源文件 index 驱动 + 检测器批量加载 | 5 个 secguard skill 文件 | 29s→5s |

### Phase 4: Renderer Fix

| # | Task | 改动 | 预期提升 |
|---|------|------|---------|
| 4 | TASK-004: renderer import 补齐 | Counter import 后运行时无需修补 | 15s→1s |

### Phase 5: Verification

| # | 验证 | 命令 |
|---|------|------|
| 1 | deploy | bash scripts/deploy.sh all |
| 2 | self-check | bash scripts/self-check.sh |
| 3 | e2e | bash scripts/e2e-verify.sh --quick |

## 预期效果

| 项目 | 当前 | 优化后 | 提升 |
|------|------|--------|------|
| 前置检查 | 27s | 3s | 90% |
| 源文件读取 | 19s | 4s | 79% |
| 检测器加载 | 10s | 3s | 70% |
| Finding 写入 | 19s | 3s | 84% |
| 渲染器 | 15s | 3s | 80% |
| **总计** | **~100s** | **~16s** | **84%** |
