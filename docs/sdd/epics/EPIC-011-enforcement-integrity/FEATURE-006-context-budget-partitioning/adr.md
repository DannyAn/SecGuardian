# ADR — FEATURE-006: Dispatch Architecture — Per-rule Isolation + Engine Pre-filtering

> **隶属**: EPIC-011 / FEATURE-006
> **日期**: 2026-07-10
> **状态**: ✅ Accepted
> **背景**: 用户三关切——(1) 一口气给所有 rule，LLM 不逐个跑、结果不稳；(2) secaudit 扁平 rule 一锅端；(3) 生产 30-skill 各跑任务极慢。

---

## ADR-006: per-rule 隔离任务 + 引擎预过滤 + 有界 batch

### Decision
secguard 调度模型：**每条 rule（每有界 batch）一个隔离 LLM 任务**，每个任务只接收**引擎预过滤后与该 rule 相关的信号**（按 rule frontmatter `signal_source` 匹配）+ 该信号的 CFG/源码上下文，按 `BATCH_SIZE` 分批。partition 计划由引擎工具产出（平台无关），调度机制随平台适配。

```
引擎（一次）: 索引 → 信号 S1-S11 + CFG + symbols（全打 rule 相关标签）
引擎（M3）  : partition-signals.py → {rule: [batch1, batch2, ...]}  ← 平台无关产物
调度（适配）: per (rule, batch) 一个隔离任务
              Claude Code: Agent 子代理 / batch（可滚动并发）
              OpenCode   : Task 子代理 / batch（串行启动，上下文隔离）
              Gemini CLI : 未验证隔离原语；多 batch fail-closed
强制（引擎）: record-finding → verification-gate → render-report → coverage-gate
```

### Reason
1. **per-rule 隔离 = 质量**（关切 #1）：LLM 聚焦一条 rule 的 danger/safe/FP 模式，判断一致、可复现、低干扰。全 rule 批量喂会让 LLM 注意力分散、不逐个跑、结果漂移——正是旧版不可信之源。
2. **引擎预过滤 = 可负担**（关切 #3）：旧 30-skill 慢在"每 skill 从头重扫全代码库" O(N×库)。现在引擎只解析一次 O(库)，每 rule 任务只处理其 `signal_source` 相关信号 O(相关信号)。N rule × O(相关信号) ≪ N × O(库)。叠加 prescreener 降噪 + oracle 可调 batch，per-rule 隔离变可负担。
3. **有界 batch = 不淹没**（关切 #1）：一条 rule 有 50 信号时，按 `BATCH_SIZE`（如 20）分批，每批有界上下文，防 LLM 面对海量信息失真；coverage-gate 强制按批核算，堵 batch-suppression。
4. **平台无关 partition + 平台能力适配调度**（关切 #1 跨平台痛）：partition 计划是引擎 JSON 产物，平台无关；调度机制随平台能力适配。跨平台一致性来自机器产物和 gate，不来自相同自然语言 prompt。无可靠隔离原语的平台不得声称等价，必须 fail-closed 或降级到单 batch。

### Rejected Alternatives
| 方案 | 否决原因 |
|------|---------|
| 全 rule 一锅端（旧 secaudit 模式）| 快但 LLM 不逐个跑、结果漂移（关切 #1）；secaudit 扁平 rule 无法 per-rule 隔离（关切 #2）|
| per-signal 任务（一信号一任务）| 隔离最强但 N 信号 × 调度开销过慢；信号需 rule 上下文，单独跑缺锚 |
| per-rule 无引擎预过滤（旧 30-skill）| 每 rule 重扫全库 → 慢（关切 #3）|
| 全程序 LLM 推理（无分区）| 生产规模必然 batch-suppression（v0.18.0 实证 1358→0）|

### Consequences
- 好：per-rule 隔离给质量；引擎预过滤给可负担；有界 batch 给生产可用；平台无关 partition 给跨平台一致
- 好：oracle 可度量 batch_size 对 recall/precision 的影响，经验调参而非拍脑袋
- 不好：N rule × M batch 个任务，绝对数量仍多——靠引擎预过滤（每任务轻量）+ prescreener（减信号）+ 平台并行（Claude Agent 可并发）缓解
- 不好：partition 工具需维护 rule→signal_source 映射（从 rule frontmatter 解析），rule 增删需同步

### secaudit 对齐（关切 #2，留后续）
secaudit 的扁平 rule（一个 .md 捆一域多 rule）无法 per-rule 隔离。**结论**：secguard 的文件夹模型（`rules/{detector}/rule.md`，自包含 + signal_source）是参考架构；secaudit 后续迁移到同模型。本次只做 secguard，secaudit 留专门 Feature。

### 平台调度契约
```
dispatch(rule_md_path, signal_batch, context_bundle) → findings[]
```
- Claude Code: `Agent` 工具，每个 (rule, batch) 启子代理，上下文隔离，可滚动并发
- OpenCode: `Task` 子代理，每个 (rule, batch) 一个任务，串行启动但上下文隔离
- Gemini: 当前未验证隔离原语；多 batch 必须 BLOCKED，直到实现独立上下文 runner
命令模板只负责"生成 partition 计划 → 按平台能力 dispatch → 收工件摘要 → 走强制层"。模板不得复制完整 pipeline，不得让父上下文执行调查。
