# CHANGE-005: OpenCode Batch Delegation Enforcement

> **Date**: 2026-07-11
> **Status**: Implemented
> **驱动**: OpenCode 会话 `examples/cpp-vuln-demo-no-answers/session-ses_0af3-round3-Terra.md` 暴露 Phase 2 仍可被主模型合并批次执行，偏离 ADR-006 per-rule/per-batch 隔离。

## 一、测试暴露的事实

`ses_0af3` 中 Phase 1 行为正确：

| 阶段 | 事实 |
|------|------|
| 初始化 | `init-scan.sh` 正确建立 scan state |
| 索引 | `secguardian-index --lang cpp` 正确运行，产出 15 文件、74 call signals、Prescreener 过滤 8 条 |
| 分区 | `partition-signals.py` 正确产出 20 rules / 32 batches / 571 assignments |

失控点在 Phase 2：

| 现象 | 影响 |
|------|------|
| 主 dispatcher 读取完整 `partition-plan.json` | 父上下文装入大量 signal-rich JSON，违反 dispatch-protocol §5 |
| 第三个 Task prompt 写成 “Complete remaining batches” | 一个子代理处理 30 个 batch，违反 “one exact `(rule_id,batch_id)` per Agent” |
| 后续主会话直接读取 worker artifacts 并手工修补 | Gate 变成事后修补，而不是不可绕过的执行纪律 |
| `self-check.sh` 打印 secguard 模板缺陷但重置失败计数 | 破坏性模板漂移没有阻断开发 |

结论：这不是“完全没用索引器”，而是索引器和规则分区已经运行，但 OpenCode 模板仍允许模型把多个 batch 合并到一个子代理，并允许父上下文读入过量计划/工件后做自由裁剪。

## 二、根因

1. `commands/opencode/secguard.md` 仍复制了完整 Steps 4-8 调查说明，虽然文字提到隔离，但没有明确把 OpenCode `Task` 子代理作为唯一执行原语。
2. 模板没有禁止 “complete remaining batches” 这类批量委派 prompt。
3. 模板缺少 `@secguardian:non-skippable` 标记，已有 self-check 检出但未计入失败。
4. `scripts/self-check.sh` 在 §12 和 §13 中发现失败后没有递增最终 `FAIL`，导致输出 “Failed: 0”。

## 三、修复方案

1. OpenCode `/secguard` Phase 2 改为薄适配：共享 pipeline 只引用 `knowledge/protocols/dispatch-protocol.md`，平台执行原语固定为每个非空 batch 单独 `Task` 子代理。
2. 明确禁止把多个 rule/batch 合并给一个 Task，禁止 “all remaining batches” 合并式委派。
3. 增加 non-skippable markers：validate、pre-filter、rule-loading。
4. 修复 `self-check.sh`：模板静态分析和 security gate 的失败必须计入最终失败数。

## 四、验收

- `bash scripts/self-check.sh` 必须在模板缺陷存在时非零退出。
- OpenCode session 中 Phase 2 必须呈现每个 nonempty `(rule_id,batch_id)` 一个独立 Task 调用。
- 父 dispatcher 不读取完整源码、不读取完整 signal-rich plan，只读 compact schedule 和 gate/manifest 摘要。

## 五、跨平台设计收敛

本次修复不把 OpenCode 行为强行复制到 Claude/Gemini，也不再假设相同 prompt 在不同 Agent 中会产生相同执行效果。

| 平台 | 允许的执行原语 | 多 batch 策略 |
|------|----------------|---------------|
| Claude Code | Agent 子代理 | one batch = one Agent，可滚动并发 |
| OpenCode | Task 子代理 | one batch = one Task，串行启动 |
| Gemini CLI | 未验证独立上下文 | 多 batch fail-closed；单 batch 可内联 |

一致性来源是机器产物和 gate：`partition-plan.json`、worker 工件、`verification-gate.py`、`coverage-gate.py`。自然语言模板只作为平台适配层，不再作为执行一致性的信任根。
