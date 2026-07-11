# 统一调度协议 — Per-Rule Isolated Dispatch (EPIC-011 ADR-006)

> **状态**: ✅ Accepted (2026-07-10)
> **适用**: `/secguard`（及后续 `/secaudit`、`/secreview` 对齐）
> **平台**: Claude Code / OpenCode / Gemini CLI —— **三平台行为一致，差异隔离于调度原语**

> ⚠️ 本文件是 Investigation Pipeline 的**单一真理源**。三平台命令模板（`commands/{claude,opencode,gemini}/secguard.md`）**引用本文件**，不各自复制 pipeline 内容（避免 F10 漂移）。每平台只额外声明自己的**调度原语**（见 §5）。

---

## 1. 设计目标（回应用户三关切）

| 关切 | 本协议解法 |
|------|-----------|
| 一口气给所有 rule → LLM 不逐个跑、结果漂移 | **per-rule 隔离**：每个任务只处理一个精确 `(rule_id,batch_id)` |
| 海量信息淹没 | **有界 batch**（BATCH_SIZE，默认 20）+ 引擎预过滤 |
| 生产 30-skill 各跑任务 = 慢 | **引擎预过滤**：旧慢在每 skill 重扫全库；现引擎只解析一次，每 rule 任务只收其 `signal_source` 相关信号 |
| Claude vs OpenCode 调度差异踩坑 | **per-rule Agent 隔离**：三平台各按自己调度原语实现上下文隔离，差异见 §5 |

---

## 2. 统一调度契约（平台无关）

**基线模式：per-rule 上下文隔离**（三平台各按调度原语实现，差异见 §5）。

```
Step 2 索引就绪后:
  1. 引擎: partition-signals.py --index index.json --rules-dir <lang>/rules --batch-size 20
     → 产出 partition-plan.json: {rule: [batch1, batch2, ...]}   ← 平台无关产物
  2. 先执行信号最少的一个 pilot batch，并验证四类 canonical 工件
     - pilot 不合规 → 立即 BLOCKED，不启动剩余任务
  3. for each remaining (rule, batch) in partition-plan:
       a. 加载 rule.md（Read 工具）
       b. 对该 batch 的每个信号跑 Investigation Pipeline（§3 Steps 4-7）
       c. 命中 → record-finding.py 录入（anchor 强制）
       d. 未命中但需抑制 → 写 canonical Judge verdict；coverage gate 从完整 batch 工件确定性生成 suppression accounting
       e. 完成前运行 scoped verification-gate（带 partition plan）；四类工件必须覆盖 batch 的每个 signal_id
  4. 引擎强制:
       - verification-gate.py --index index.json --scan-dir <scan>  → gate-audit.json
       - coverage-gate.py --plan partition-plan.json --scan-dir <scan> → BLOCKED 若 assignment 未核销
  5. 两道 gate 均成功后才运行 render-report.py --ci
  6. verify-recall.py（可选、informational；仅在存在独立 ground truth 时运行）
```

**关键：per-rule 纪律由引擎强制，不靠 LLM 自觉。** partition 计划给结构，coverage-gate 核算（partitioned signals vs findings+dismissed），漏跑 rule → signals 未 investigated → BLOCKED。

---

## 3. Investigation Pipeline（共享 Steps 4-8，三平台相同）

### Step 4: Hypothesis Generator `[不可跳过]`
- **产出**: `workers/<rule_id>/<batch_id>/hypotheses.json`
- **输入**: partition 计划中该 rule 的 batch 信号 + index.json 上下文 + rule.md
- **动作**: 每个 Signal 生成 3-5 个彼此不同的假设（缺陷、上下文变体、缓解、替代风险、实际安全），防止过早锁定单一漏洞方向。
- **禁止**: 直接判定漏洞类型。Signal 是调查起点，非结论。

### Step 5: Investigator `[不可跳过]`
- **产出**: `workers/<rule_id>/<batch_id>/evidence.json`
- **门禁**: hypotheses.json 存在且 ≥3 假设
- **动作**: 针对每假设收集三段式证据链（Source→Propagation→Sink），每项保留 `signal_id` 并锚定 `file:line+function+variable`。只使用 index 中真实存在的引擎事实；CFG `IsReachable`/`Dominates` 仅在当前 index 明确提供时可引用，否则不得伪装为引擎事实。

### Step 6: Counter Evidence (P2) `[强制性阻塞门]`
- **产出**: `workers/<rule_id>/<batch_id>/counter_evidence.json`
- **门禁**: evidence.json 存在
- **动作**: 对每条假设尝试**推翻自己**——找缓解、找安全变体、找不可达。即使全部安全也必须产出（记录"为何安全"）。
- **阻塞**: counter_evidence.json 不存在 → **禁止** record-finding（verification-gate 强制）

### Step 7: Judge + Fact-Anchor Reflection `[不可跳过]`
- **产出**: `workers/<rule_id>/<batch_id>/judge_verdict.json`
- **动作**: 读 evidence + counter_evidence（**不重新调查**），按 rule.md 的 Q-matrix 判决：
  - Q1 缺陷真实？Q2 可利用？Q3 缓解存在？（Q1/Q2 Yes=危险，Q3 Yes=安全）
  - 判决: `CONFIRMED | SUPPRESS | NEEDS_REVIEW`
- **锚定**: 判决必须引用证据行号 + Q-matrix 答案

#### Canonical Q-matrix 极性（F7 修复，自洽，所有 rule 必须遵循）
> ⚠️ **极性统一**：Q1/Q2 `true`=危险（缺陷/可利用），Q3 `true`=安全（缓解存在）。旧"三绿灯(Q1=Q2=Q3=Yes)→SUPPRESS"措辞错误（把 Q1/Q2 Yes 误当安全），已废止。

| Q1 缺陷真实 | Q2 可利用 | Q3 缓解存在 | conclusion |
|------------|----------|----------|-----------|
| No (false) | — | — | SUPPRESS（无缺陷）|
| Yes (true) | — | Yes (true) | SUPPRESS（已缓解）|
| Yes (true) | Yes (true) | No (false) | **CONFIRMED**（High/Critical）|
| Yes (true) | No (false) | No (false) | CONFIRMED（Medium，潜在缺陷）|

**verification-gate 引擎校验**（Step 8.5）：CONCLUSION 与 Q1/Q3 不一致 → needs_review。例：verdict=CONFIRMED 但 Q1=false（无缺陷）或 Q3=true（已缓解）→ 矛盾 → needs_review。这把 Judge 的"自我汇报"变成引擎可校验。

### Step 8: Record Findings `[条件执行]`
- **门禁**: judge_verdict.json 存在且 verdict=CONFIRMED
- **动作**: `record-finding.py` 录入；必须携带 `rule_id + batch_id + signal_id + index_json`。
- **抑制项**: Judge 写 `SUPPRESS` 并携带 signal provenance；coverage gate 从四类完整 batch 工件汇总。`dismissed.json` 是 gate 生成/汇总产物，不允许并发 Agent 直接维护共享文件。
- **不确定项**: `NEEDS_REVIEW` 不计入 confirmed，也不得伪装为安全 dismissal。

---

## 4. 引擎强制链（平台无关，bash 调用）

| 阶段 | 工具 | 作用 |
|------|------|------|
| 分区 | `scripts/partition-signals.py` | per-rule 信号分组 + 有界 batch |
| 录入 | `scripts/record-finding.py` | anchor + severity + function 回填 |
| 验证 | `scripts/verification-gate.py` | gate-audit.json（confirmed/needs_review）|
| 覆盖 | `scripts/coverage-gate.py --plan partition-plan.json` | 逐 `(rule_id, signal_id)` assignment 核销（BLOCKED）|
| 渲染 | `scripts/render-report.py --ci` | confirmed 才计入 CI，真退出码 |
| 度量 | `scripts/verify-recall.py` | 可选 recall/precision（需独立 ground truth，不阻塞生产扫描）|

---

## 5. 平台调度原语（差异隔离于此）

三平台共享的是**逻辑契约**（§2 分区、§3 pipeline、§4 强制链），不是同一段自然语言话术。每个平台必须声明自己的隔离能力，并用该平台的最强隔离原语实现 `one nonempty (rule_id,batch_id) = one bounded investigation context`。

禁止把“相同 prompt 文案”当成跨平台一致性保证。跨平台一致性只由以下机器可验证产物定义：`partition-plan.json`、`workers/<rule_id>/<batch_id>/` 四类工件、`verification-gate.py`、`coverage-gate.py`、`render-report.py --ci`。

### Dispatcher context budget
- Dispatcher 只读取 compact partition schedule、任务完成状态和 gate/manifest 摘要。
- 禁止在父上下文预读全部 rule.md、全部源码或完整 signal-rich partition plan。
- 每个任务自行读取唯一 rule.md 和该 batch 锚点附近的源码窗口。
- 禁止把多个 rule 或多个 batch 合并进一个 Agent。
- 禁止轮询后台 Agent；使用完成事件。统计只从 artifacts 计算，不在自然语言中维护 running total。

### Claude Code
- **基线**: Agent 子代理真上下文隔离（ADR-006）。每个 (rule, batch) 一个隔离 Agent——Agent 启动时上下文干净，不携带其他 rule 的调查内容或完整源文件。禁止在主上下文串行内联（CHANGE-004：串行内联被测试证伪，LLM 因上下文压力自行丢弃规则）。
- **调度**: pilot batch 串行验证 gate 后，剩余 batch Agent 滚动并发（上限 4）。一个完成才补一个。
- **工具**: `Read`（rule.md/知识/信号坐标源码窗口）、`Bash`（引擎脚本）。禁止 `bash cat` 读取知识文本。禁止不带 offset/limit 的完整源文件 Read。

### OpenCode
- **基线**: 串行 Task/Agent 隔离（CHANGE-004/005）。每个 nonempty (rule, batch) 一个 `Task` 子代理，串行启动但上下文独立。禁止在主上下文直接串行内联完整 Steps 4-8，禁止一个 Task 处理多个 batch。
- **调度**: pilot batch 一个 Task；pilot gate 通过后，剩余 batch 逐个启动 Task。不得使用 “complete remaining batches” 类合并式委派。
- 工具: `read`/`bash`（平台等价物）。禁止不带 offset/limit 的完整源文件 Read。

### Gemini CLI
- **能力状态**: 当前未验证有可靠的子代理/独立上下文原语。不得声称与 Claude/OpenCode 等价。
- **安全基线**: 只允许 `total_nonempty_batches <= 1` 的单 batch 扫描内联执行；若分区计划产生多个 nonempty batch，必须 fail-closed，输出 BLOCKED 诊断并提示使用 Claude/OpenCode 或后续 Gemini 隔离执行器。
- **后续落地**: 若 Gemini 后续接入独立上下文原语或外部 batch runner，可升级为 `one batch = one isolated execution`，但必须先通过 CHANGE-004 的 V1-V5 验收。

> **一致性保证**: 三平台只共享 §2 契约 + §3 pipeline + §4 强制链。平台差异必须收敛在 §5 的执行原语和能力限制里。命令模板只声明原语 + 引用本协议，不复制 pipeline。

---

## 6. 与旧版的区别

| 维度 | 旧版 | 本协议 |
|------|------|--------|
| 调度 | 全 rule 一锅端 / 平台各异踩坑 | per-batch 隔离上下文 + 引擎强制；无隔离能力的平台 fail-closed |
| 信号 | LLM 自行从源码找 | 引擎预过滤 partition 计划 |
| 纪律 | Markdown "不可跳过"（LLM 可忽略）| 引擎强制（coverage/verification-gate）|
| 平台 | 各拷一份 pipeline（漂移）| 单一真理源（本文件）+ 薄平台适配 |
