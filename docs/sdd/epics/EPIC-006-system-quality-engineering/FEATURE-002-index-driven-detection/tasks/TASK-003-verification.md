# TASK-003: 全量验证

> **Feature**: FEATURE-002-index-driven-detection
> **前置**: TASK-001, TASK-002

## 验证步骤

```bash
# ------- L1 设计一致性 -------
bash scripts/self-check.sh

# 预期: Section 13 三绿通过，总 147/147

# ------- L4 架构端到端 -------
bash scripts/e2e-verify.sh

# 预期: 56/56

# ------- L5 全量 -------
bash scripts/self-check.sh && bash scripts/ci-check.sh && bash scripts/dev-verify.sh && bash scripts/e2e-verify.sh

# ------- 手动扫描验证 -------
# 选择一个示例仓库，触发 /secguard 扫描
# 验证: 执行日志中 0 次 grep 调用
# 验证: .codeagent/secguardian/ 下没有 knowledge/ 目录
# 验证: 不匹配的检测器跳过并记录 Skipped 信息

# ------- 确认 scaf -------
git status
git diff --stat
```

## 通过标准

- L1: 全部通过
- L4: 全部通过
- 人工扫描验证: 执行日志 0 grep，无 knowledge 拷贝
