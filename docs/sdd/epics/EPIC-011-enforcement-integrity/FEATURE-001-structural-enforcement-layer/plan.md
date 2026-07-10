# Plan — FEATURE-001: Structural Enforcement Layer + Verification Oracle

> **隶属**: EPIC-011 / FEATURE-001
> **目标**: 把语义不变量下沉到编译 chokepoint，闭合 ground-truth 验证回路

---

## Goal
让"0 finding = PASSED"不可能、CI Critical 不可绕过、recall/precision 可度量——使"超越 SAST"可结构证明。

## Architecture
见 spec §4。新增两个 Python 编译层工件：`verification-gate.py`（Pillar A）+ `verify-recall.py`（Pillar B），接入现有 `record-finding.py` / `render-report.py` / `e2e-verify.sh`。

## File Structure
| 文件 | 改动 | 量 |
|------|------|----|
| `scripts/verification-gate.py` | 新增 | 大 |
| `scripts/verify-recall.py` | 新增 | 中 |
| `scripts/record-finding.py` | 接入 gate + severity 强校验 | 中 |
| `scripts/render-report.py` | --ci exit 1 + 渲染 bug(F12) + signature 校验 | 中 |
| `scripts/e2e-verify.sh` | §13 接 oracle，删伪造 | 中 |
| `scripts/verify-lang-pipeline.sh` | 删伪造逻辑 | 小 |
| `scripts/self-check.sh` | 新增 §15 mini-oracle + §12 失败计数修复 | 小 |
| `scripts/ci-check.sh` | exit 位置修复(F13) | 小 |
| `commands/claude/secguard.md` | 恢复 Steps 4-8(F1，阻塞修复) | 中 |
| `examples/*/expected-results.json` | 人工标注复核 | 中 |
| `knowledge/protocols/scan-output.md` | gate_signature 字段 + status BLOCKED | 小 |

## Tasks（按执行顺序，每 Task 一次 commit）

### TG-A: CI 速赢（立即可验证，解除最危险门禁绕过）
- [ ] **TASK-001** F2: `render-report.py --ci` 真退出码 + `_ensure_fields` severity 枚举强校验 + `record-finding.py --from-file` severity choices。验证：`e2e-verify.sh` §6 CI 门禁用例断言 exit 1
- [ ] **TASK-002** F12: `render-report.py:424-432` detail block 移入 `for f` 循环。验证：构造 3 条同 detector finding，断言 report.md 有 3 个完整 detail block
- [ ] **TASK-003** F13: `ci-check.sh` `exit $ERRORS` 移到 §6 之后。验证：§6 实际执行，故意制造命令不一致触发失败

### TG-B: Pillar A 强制层
- [ ] **TASK-004** 新增 `verification-gate.py`：anchor 真实性(REQ-001a) + severity 枚举(REQ-001d) + gate_signature 签发。验证：单测覆盖 pass/降级/audit log
- [ ] **TASK-005** `record-finding.py` 接入 gate：所有 finding 写入前委托 gate，无 signature 不落盘 confirmed。验证：绕过 recorder 直接写 JSON → 渲染器拒绝
- [ ] **TASK-006** gate 扩展 Q-matrix 一致性(REQ-001b) + 工件存在性(REQ-001c)。验证：缺 counter_evidence.json 的 finding 降级 needs_review（与 FEATURE-003 协同，先建 stub）
- [ ] **TASK-007** F8 信号覆盖下限(REQ-002)：scan 级 coverage 校验 + BLOCKED 状态 + dismissed reason 强制。验证：构造 signals=100/investigated=0 → BLOCKED + exit 1

### TG-C: Pillar B 验证回路
- [ ] **TASK-008** 新增 `verify-recall.py`：读 expected-results.json + 实际 findings，按 detector+anchor 匹配，输出 recall/precision/F1(REQ-004)。验证：对 python-vuln-demo 跑出 recall 数值
- [ ] **TASK-009** F4: 删 `verify-lang-pipeline.sh` 伪造，`e2e-verify.sh` §13 接 oracle(REQ-005)。验证：检测器失效（mock 0 finding）时 oracle 报 recall=0，e2e 失败
- [ ] **TASK-010** `self-check.sh` §15 mini-oracle + §12 失败计数修复(REQ-005c)。验证：self-check 仍 120+ 绿，且 mini-oracle 真跑

### TG-D: 死代码与协议
- [ ] **TASK-011** F1: 恢复 `commands/claude/secguard.md` Steps 4-8（从 opencode canonical 对齐，平台适配）。验证：行数对齐、Step 标题完整、bash 围栏闭合
- [ ] **TASK-012** F11: `diff_parser.go` 接入 `--diff-ref` CLI flag，或删除+清理文档（按 ADR-004 接入）。验证：`secguardian-index --diff-ref HEAD~1` 只索引变更文件
- [ ] **TASK-013** `scan-output.md` 协议补 gate_signature + BLOCKED 字段。验证：self-check §协议一致性

## Verification
- 每个 TASK：`bash scripts/self-check.sh` 必绿
- TG-B/C 完成后：`bash scripts/e2e-verify.sh --ci` 全绿，且 oracle 输出 recall > 0
- 全部完成：L1-L5 全跑，`--ci` 在 Critical 场景 exit 1

## Dependencies
- TASK-006 依赖 FEATURE-003 Q-matrix 极性定义（先建 stub 接口，FEATURE-003 落地后填充）
- TASK-008 依赖 expected-results.json 人工标注复核（可与实现并行）
- 与 FEATURE-002（CFG）正交：gate 可消费 CFG 事实但 不阻塞
