# FEATURE-001: Structural Enforcement Layer + Verification Oracle

> **隶属 Epic**: EPIC-011 Enforcement Integrity
> **支柱**: Pillar A（强制层）+ Pillar B（验证回路）
> **创建**: 2026-07-10
> **优先**: P0
> **修复致命项**: F1, F2, F3, F4, F8, F11, F12, F13

---

## 1. Problem Statement

### 1.1 强制力倒置（F3, F8）

当前架构唯一的 finding 写入口 `record-finding.py` 只校验**字段非空 + 文件锚定**，不校验任何语义不变量：
- 不检查 `counter_evidence.json` / `judge_verdict.json` / `hypotheses.json` 是否存在或合理
- 不检查 Q-matrix 答案与 verdict 的一致性
- 不检查信号覆盖率（signals_count vs findings_investigated）

所有"不可跳过"/"阻塞门"/"禁止"都是 Markdown 文本，LLM 可选择性忽略。后果：**0 finding → 100/100 PASSED** 路径畅通（F8），历史教训 batch-suppression（1358→0）可精确复现。

### 1.2 CI 门禁装饰性（F2）

- `render-report.py --ci` 永不 `sys.exit(1)`（失败分支只 `print`）
- severity 大小写/枚举可绕过门禁（`--from-file` 无 choices 校验，`by_sev.get("Critical")` 漏判非标准值）
- 真实 Critical 可被"降级"绕过门禁

### 1.3 验证剧场（F4）

L1-L5 无一项验证检测正确性：
- `verify-lang-pipeline.sh` 伪造 finding 冒充"全管线通过"，从不跑真实检测器
- `expected-results.json` ground truth 存在但无脚本读取比对（循环验证）
- self-check 120 项全是结构性检查，检测器失效（永远 0 finding）仍 100% PASS
- "191 findings / 0 FP"无自动化来源、不可复现

### 1.4 协议-实现漂移与死代码（F1, F11, F12, F13）

- F1: Claude 主平台 secguard.md Steps 4-8 截断，调查管线在主平台不存在
- F11: `diff_parser.go` 死代码却文档化增量扫描可用
- F12: `render-report.py` §3 detail block 落在 for 循环外，每检测器只渲染最后一条
- F13: `ci-check.sh` §6 跨命令一致性死代码（`exit $ERRORS` 在前）

### 1.5 对北极星的破坏

这些问题使"超越 SAST"的两根支柱均失效：recall 对等被破坏（LLM 可抑制信号），且不可证明（无 recall/precision 度量）。

---

## 2. Design Goals（可度量成功标准）

| ID | 目标 | 度量 |
|----|------|------|
| G1 | 0 finding 不再可能 PASSED | 信号覆盖下限门禁：`findings_investigated / signals_count < threshold` → gate 拒绝 |
| G2 | CI Critical 不可绕过 | `render-report.py --ci` 真退出码 + severity 枚举强校验，Critical≥1 → exit 1 |
| G3 | finding 写入必须通过语义门 | `record-finding.py` 委托 `verification-gate.py`，无 gate 签名的 finding 不被渲染 |
| G4 | recall/precision 可度量 | `verify-recall.py` 读 `expected-results.json` 与实际 finding diff，输出 recall/precision/F1 |
| G5 | 验证不再伪造 | 删除 `verify-lang-pipeline.sh` 伪造路径，e2e §13 接真实检测器输出 |
| G6 | 渲染正确 | report.md §3 每条 finding 都有完整证据/修复块（F12）；命令单源（F1/F10 见 FEATURE-005）|

---

## 3. Requirements

### REQ-001: verification-gate.py（Pillar A 核心）
新增 `scripts/verification-gate.py`，作为 `record-finding.py` 的前置语义门。对每条待写入 finding 校验：
- **REQ-001a** anchor 真实性：`file:line` 必须存在于 `index.json` 的 symbols/files
- **REQ-001b** Q-matrix 一致性：若该规则有 Q-matrix，Q1/Q2/Q3 答案与 verdict 必须满足判定矩阵（与 FEATURE-003 极性一致化协同）
- **REQ-001c** 工件存在性：P2-gated finding 必须有对应 `counter_evidence.json` + `judge_verdict.json`
- **REQ-001d** severity 枚举强校验：仅 `Critical/High/Medium/Low`，大小写归一化
- gate 通过则签发 `gate_signature`（HMAC 或 sha），写入 finding；失败则降级为 `needs_review` 并写 audit log，**不直接丢弃**（防误杀）

### REQ-002: 信号覆盖下限（F8 结构性防线）
- **REQ-002a** `verification-gate.py` 在 scan 级别校验 `findings_investigated / signals_count` 比率（`signals_count` 来自 index.json，`findings_investigated` 来自 scan artifacts）
- **REQ-002b** 比率低于阈值（初始 `investigation_floor = 0.0`，可配置，生产建议 ≥0.1）→ status.json `gate_result = BLOCKED`，CI exit 1
- **REQ-002c** 阈值为 0 时仍要求：若 `signals_count > 0` 且 `findings_investigated == 0`，必须有人工 `dismissed.json` 解释每条 signal（否则 BLOCKED）

### REQ-003: CI gate 修复（F2）
- **REQ-003a** `render-report.py --ci` 在 `status["exit_code"] != 0` 时 `sys.exit(1)`
- **REQ-003b** `record-finding.py --from-file` 路径强制 severity choices 校验
- **REQ-003c** `render-report.py._ensure_fields` 校验 severity 枚举并归一化

### REQ-004: Verification Oracle（Pillar B 核心）
新增 `scripts/verify-recall.py`：
- **REQ-004a** 读取 `examples/*/expected-results.json`（ground truth，需独立人工标注，见风险）
- **REQ-004b** 读取该 demo 的实际 findings.json
- **REQ-004c** 按 `detector + anchor` 匹配，输出 per-rule 与全局 `recall / precision / F1`，写入 `recall-report.json`
- **REQ-004d** 接入 `e2e-verify.sh` 作为新 §13，替换 `verify-lang-pipeline.sh` 伪造路径

### REQ-005: 杀验证剧场（F4）
- **REQ-005a** 删除 `verify-lang-pipeline.sh` 伪造 finding 逻辑，改为调用真实 secguard 扫描（或标记为 skip-until-oracle）
- **REQ-005b** `e2e-verify.sh` §11/§12 的自造数据自验证段落，替换为对真实扫描产物的结构断言
- **REQ-005c** `self-check.sh` 新增 §15：对 1 个语言跑 mini-oracle，断言 recall > 0

### REQ-006: 渲染与死代码修复（F12, F13, F11）
- **REQ-006a** `render-report.py:424-432` detail block 移入 `for f` 循环
- **REQ-006b** `ci-check.sh` 将 `exit $ERRORS` 移到 §6 之后
- **REQ-006c** `diff_parser.go`：接入 CLI（`--diff-ref` flag）或删除并清理文档（决策见 ADR）

---

## 4. Design

### 4.1 数据流（升级后）

```
AI 产出 candidate finding
  ↓
record-finding.py --from-file / 直接写
  ↓
verification-gate.py 校验（anchor/Q-matrix/工件/枚举）→ 签发 gate_signature
  ↓ 通过 / 失败降级 needs_review
findings/<sha>.json（含 gate_signature 字段）
  ↓
render-report.py 渲染（拒渲染无 signature 的 finding；--ci 真退出码）
  ↓
verify-recall.py 对照 expected-results.json → recall/precision
```

### 4.2 gate_signature 设计

```json
{
  "gate_signature": {
    "version": 1,
    "checks": {"anchor": "pass", "qmatrix": "pass", "artifacts": "pass", "severity": "pass"},
    "verdict": "confirmed" | "needs_review",
    "audit_path": ".codeagent/.../gate-audit/<sha>.json"
  }
}
```
- 渲染器只渲染 `verdict == confirmed` 的 finding；`needs_review` 单列"需人工复核"区
- audit log 记录每条 gate 决策的输入与依据，可追溯

### 4.3 信号覆盖下限算法

```
signals_count = len(index.json signals)
investigated  = count(findings) + count(dismissed.json entries with reason)
coverage      = investigated / max(signals_count, 1)
if signals_count > 0 and coverage < investigation_floor:
    gate = BLOCKED
```
`dismissed.json` 必须为每条被抑制 signal 给出 reason（counter-evidence 摘要），LLM 不能再"一句话全抑制"。

---

## 5. Risks & Constraints

| 风险 | 缓解 |
|------|------|
| gate 过严误杀合法 finding | 失败降级 `needs_review` 而非丢弃；audit log 可追溯；初始阈值宽松 |
| expected-results.json 本身有误 | 独立人工标注 + 双人复核；oracle 报 mismatch 时人工仲裁并回写 |
| gate 增加扫描时延 | 仅 O(1) 结构校验 + index.json 查表，不重解析 AST |
| 现有扫描产物无 gate_signature | 渲染器对无 signature 的旧产物给 deprecation 警告，过渡期不拒绝 |

## 6. Out of Scope

- Q-matrix 极性修复与 60 规则部署 → FEATURE-003
- 命令单源生成 → FEATURE-005（本 Feature 仅修 F1 截断为阻塞修复，恢复 Steps 4-8）
- CFG 构建 → FEATURE-002（gate 消费 CFG 事实，但 CFG 落地独立）
- Finding 身份键 v2 → FEATURE-004（gate 用现有 sha，identity 升级独立）
