# ADR — FEATURE-001: Structural Enforcement Layer + Verification Oracle

> **隶属**: EPIC-011 / FEATURE-001
> **日期**: 2026-07-10

---

## ADR-001: 语义不变量下沉到编译 chokepoint，而非增加 Markdown 协议

**状态**: ✅ Accepted

### Decision
把 P2/Judge/Q-matrix/信号覆盖等语义不变量，从 Markdown 协议文本下沉到 `verification-gate.py` 编译层，作为 `record-finding.py` 的强制前置门。LLM 无法绕过——无 `gate_signature` 的 finding 不被渲染。

### Reason
1. Markdown 是 LLM 可选择性忽略的文本，5-Why 根因分析表明"加更多协议文字"正是历史教训复发的根因
2. `record-finding.py` 是唯一 finding 写入口，是天然的 chokepoint；在此校验，覆盖率达 100%
3. 编译层校验是确定性的，可测试、可审计，与 LLM 行为解耦

### Rejected Alternatives
| 方案 | 否决原因 |
|------|---------|
| 给现有协议加更多"不可跳过"措辞 + Q&A | 反模式本身——扩大 LLM 可忽略表面积，复发根因 |
| 用独立 Agent 进程做 Judge/Counter-Evidence（进程隔离）| 仍是 LLM 自评，无 ground truth 回路；token 成本暴涨；治标 |
| 把 finding 写入移到 Go 索引器 | 索引器是只读分析层，不应承担 finding 持久化；且 AI 产出 finding 必须经 Python 工具链 |

### Consequences
- 好：recall 下限可结构保证；CI 门禁可信任；验证可自动化
- 不好：gate 成为单点，需保降级路径（needs_review）防误杀；扫描时延略增（O(1)，可接受）

---

## ADR-002: 引入 ground-truth oracle 作为唯一 recall/precision 真理源

**状态**: ✅ Accepted

### Decision
新增 `verify-recall.py`，以 `examples/*/expected-results.json` 为 ground truth，与实际 finding diff，输出 recall/precision/F1，作为"超越 SAST"可证明性的唯一来源。

### Reason
1. 当前所有"0 FP / 191 findings"宣称无自动化来源、不可复现（F4 验证剧场）
2. recall 对等是北极星支柱 1，必须可度量才可证明
3. oracle 把"检测器是否真的能检"从"AI 自评"转为"数据对照"

### Rejected Alternatives
| 方案 | 否决原因 |
|------|---------|
| 用 AI 生成的答案卡当 ground truth | 循环验证——AI 验证 AI 自己，无独立真理源（正是 F4 病根）|
| 不做 recall 度量，只做结构验证 | 无法证明"超越 SAST"，退回验证剧场 |
| 依赖外部 SAST 工具输出做对照 | 引入外部依赖与许可证问题；且 SecGuardian 检测项 ≠ 任何单一 SAST |

### Consequences
- 好：recall/precision 可度量、可回归、可对比基线
- 不好：ground truth 需人工标注，维护成本高；oracle 的 expected-results 本身可能有误（双人复核缓解）

---

## ADR-003: 信号覆盖下限作为 batch-suppression 的结构性防线

**状态**: ✅ Accepted

### Decision
在 scan 级别校验 `(findings + dismissed_with_reason) / signals_count ≥ investigation_floor`，低于则 `gate_result = BLOCKED`、CI exit 1。`dismissed.json` 必须为每条被抑制 signal 给出 reason。

### Reason
1. batch-suppression（1358→0）的精确复现路径是"0 finding → 100/100 PASSED"，仅靠 Markdown"不要全抑制"无效
2. 覆盖下限把"调查充分性"变成可计算的门禁，LLM 不能再"一句话全抑制"
3. 强制 dismissed reason 使抑制可审计、可复核

### Rejected Alternatives
| 方案 | 否决原因 |
|------|---------|
| 固定 findings 数量下限（如 ≥1）| 易被 LLM 凑数报 1 条无意义 finding 绕过；不反映调查充分性 |
| 仅靠 Judge 拒绝全抑制 | Judge 是 LLM，可被绕过（F3）；非结构性 |
| 不设下限 | batch-suppression 路径不修复，支柱 1 失效 |

### Consequences
- 好：batch-suppression 路径结构性关闭；抑制可审计
- 不好：阈值需调参；初始需宽松（floor=0 但强制 dismissed reason）以避免阻塞正常扫描

---

## ADR-004: diff_parser.go 接入 CLI 而非删除

**状态**: ✅ Accepted

### Decision
将 `diff_parser.go` 的 `ParseGitDiff` 接入 `secguardian-index --diff-ref <ref>` flag，使增量扫描真正生效；删除命令模板中"已支持 git diff"的虚假文档直到接入完成。

### Reason
1. 增量扫描是 PR 场景（secreview）的核心能力，删除会损失功能
2. 实现已存在（死代码），接入成本低
3. 保留虚假文档比删除更危险（用户误以为生效）

### Rejected Alternatives
| 方案 | 否决原因 |
|------|---------|
| 删除 diff_parser.go + 清理文档 | 损失增量扫描能力，secreview 退化 |
| 保持死代码现状 | F11 致命项未修，用户误信 |

### Consequences
- 好：增量扫描可用，F11 修复
- 不好：需测试 diff 路径与全量路径的一致性（diff 子集应与全量对应子集一致）
