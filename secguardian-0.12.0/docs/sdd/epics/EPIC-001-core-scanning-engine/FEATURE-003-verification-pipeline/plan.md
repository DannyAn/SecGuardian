# Plan — Verification Pipeline Implementation

> **Feature**: FEATURE-003-verification-pipeline
> **日期**: 2026-06-17
> **状态**: 📐 Plan (v2 — 三轮设计)

---

## Goal

在 `/secguard` 扫描命令的 Detector 扫描和 Renderer 之间，插入三轮 AI Agent 验证管道，将 Finding[] 逐步认证，最大化降低误报。

---

## Architecture

```
                      (无变更)
  Tree-sitter Indexer → index.json
                            ↓
                      (无变更: Detector 输出格式不变)
  67 Detectors → findings.json + findings/
                            ↓
                      (新增: 三轮验证协议)
  ┌─────────────────────────────────────────┐
  │ P1: Semantic Verification               │
  │ P2: Counter-Evidence Hunt               │
  │ P3: Adjudication Court                  │
  └─────────────────────────────────────────┘
                            ↓
                      (新增输出文件)
  dismissed.json + verification-audit.json
                            ↓
                      (增强: 适配验证结果)
  render-report.py → report.md + SARIF + summary.json + status.json
```

---

## File Structure — 改动清单

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| `knowledge/protocols/verification-protocol.md` | 新增 | 三轮验证协议规范 — prompt 模板 + 裁决标准 |
| `knowledge/protocols/scan-output.md` | 修改 | 新增 v6.0 输出协议（dismissed + verification-audit） |
| `commands/secguard.md` | 修改 | 新增 Step 3.5 验证管道 |
| `commands/secaudit.md` | 修改 | 同步更新 |
| `commands/secreview.md` | 修改 | 同步更新 |
| `scripts/render-report.py` | 修改 | 适配 dismissed.json + 增加验证漏斗章节 |
| `scripts/e2e-verify.sh` | 修改 | 新增 dismissed.json + verification_chain 验证项 |

**不改动的文件**:

| 文件 | 原因 |
|------|------|
| `internal/` (Go 索引器) | ADR-004: index.json 保持不变 |
| `knowledge/guard-rules/*.md` (67 个) | ADR-001: Detector 输出格式不变 |
| `knowledge/protocols/findings-schema.json` | ADR-001: 不新增 Claim schema |

---

## Tasks

### Phase 1: 协议层 (TASK-001 ~ TASK-002)

- [ ] **TASK-001**: 三轮验证协议规范 (verification-protocol.md)
- [ ] **TASK-002**: 输出协议 v6.0 更新 (scan-output.md)

### Phase 2: 命令 + 渲染器 (TASK-003 ~ TASK-005)

- [ ] **TASK-003**: `/secguard` 命令适配 + Step 3.5 新增
- [ ] **TASK-004**: `render-report.py` 增强
- [ ] **TASK-005**: `secaudit.md` + `secreview.md` 同步更新

### Phase 3: 验证 (TASK-006 ~ TASK-007)

- [ ] **TASK-006**: `e2e-verify.sh` 新增验证项
- [ ] **TASK-007**: 端到端扫描测试 + 收敛数据采集

---

## Task 详情

### TASK-001: 三轮验证协议规范

**Goal**: 创建 `knowledge/protocols/verification-protocol.md`，定义三轮的 prompt 模板和裁决标准。

**Done**:
- [ ] P1 Semantic Verification prompt 模板（Project Security Profile 构建指引 + 裁决标准）
- [ ] P2 Counter-Evidence Hunt prompt 模板（按 Finding 类型定制搜索清单 + 裁决标准）
- [ ] P3 Adjudication Court prompt 模板（Prosecutor/Defender/Judge 三角色 + Court Record 格式 + Judge 禁止访问源码约束）
- [ ] 每轮 prompt 的"你只能使用以下数据"约束块

**Files Changed**:
- `knowledge/protocols/verification-protocol.md` (新文件, ~150 行)

**Verification**:
```bash
grep -c "只能使用" knowledge/protocols/verification-protocol.md  # 期望 ≥3
```

---

### TASK-002: 输出协议 v6.0 更新

**Goal**: 更新 `scan-output.md`，定义 v6.0 扫描输出结构（新增 dismissed.json + verification-audit.json）。

**Done**:
- [ ] 目录结构新增 2 个文件
- [ ] 每个文件的 schema 定义
- [ ] 向后兼容说明（findings.json + findings/ 不变）

**Files Changed**:
- `knowledge/protocols/scan-output.md` (~+30 行)

**Verification**:
```bash
grep "v6.0" knowledge/protocols/scan-output.md
```

---

### TASK-003: `/secguard` 命令适配

**Goal**: 修改 `commands/secguard.md`，新增 Step 3.5 三轮验证管道。

**Done**:
- [ ] Step 3.5: 新增三轮验证执行指令（加载 verification-protocol.md，按序执行 P1-P3）
- [ ] Step 4: render-report.py 适配 dismissed.json
- [ ] 保留 `--no-verify` flag 用于快速扫描

**Files Changed**:
- `commands/secguard.md` (~+30 行)

**Verification**:
```bash
grep "Step 3.5" commands/secguard.md
grep "verification-protocol" commands/secguard.md
```

---

### TASK-004: render-report.py 增强

**Goal**: 渲染器适配验证结果，增加验证漏斗可视化。

**Done**:
- [ ] 读取 `dismissed.json` 和 `verification-audit.json`
- [ ] `report.md` 增加 "## 验证漏斗" 章节
- [ ] `summary.json` 增加 `findings_total`, `dismissed_by_round` 字段
- [ ] `results.sarif` 增加 `suppressions` 节点
- [ ] `status.json` 增加 `confidence_weighted` 评分选项

**Files Changed**:
- `scripts/render-report.py` (~+60 行)

**Verification**:
```bash
bash scripts/e2e-verify.sh --quick
```

---

### TASK-005: secaudit + secreview 同步更新

**Goal**: 保持三个命令的 Step 流程一致。

**Done**:
- [ ] `commands/secaudit.md` Step 流程同步
- [ ] `commands/secreview.md` Step 流程同步

**Files Changed**:
- `commands/secaudit.md`
- `commands/secreview.md`

**Verification**:
```bash
bash scripts/e2e-verify.sh --ci  # §8 三命令覆盖验证
```

---

### TASK-006: e2e-verify.sh 新增验证项

**Goal**: 确保新输出文件的合规性被自动化验证覆盖。

**Done**:
- [ ] dismissed.json 格式验证
- [ ] verification-audit.json 每轮统计完整性验证

**Files Changed**:
- `scripts/e2e-verify.sh` (~+30 行)

**Verification**:
```bash
bash scripts/e2e-verify.sh --ci
```

---

### TASK-007: 端到端扫描测试 + 收敛数据采集

**Goal**: 在 cpp-vuln-demo 和 python-vuln-demo 上运行完整三轮验证，采集真实收敛数据。

**Done**:
- [ ] cpp-vuln-demo (8 文件) 三轮扫描
- [ ] python-vuln-demo (9 文件) 三轮扫描
- [ ] 记录: 初始 Finding 数 → P1→P2→P3 每轮收敛数据
- [ ] 验证: dismissed.json 中每条有明确的 dismiss_reason
- [ ] 验证: 无真阳性被误抑制（人工抽查 confirmed Finding）

**Files Changed**:
- `.codeagent/` 扫描输出（测试 artifact）

**Verification**:
```bash
ls .codeagent/secguard-secguardian/scans/<scan-id>/
cat .codeagent/secguard-secguardian/scans/<scan-id>/verification-audit.json | python3 -m json.tool
cat .codeagent/secguard-secguardian/scans/<scan-id>/dismissed.json | python3 -m json.tool
```

---

## 执行顺序

```
Phase 1 (协议层): TASK-001 → TASK-002
                       ↓
Phase 2 (命令+渲染器): TASK-003 → TASK-004 → TASK-005
                       ↓
Phase 3 (验证):        TASK-006 → TASK-007
```

---

## 验证矩阵

| Task | L2 ci-check | L4 e2e-verify | 人工 |
|------|:---:|:---:|:---:|
| TASK-001 | — | — | ✅ |
| TASK-002 | — | — | ✅ |
| TASK-003 | — | ✅ | — |
| TASK-004 | ✅ | ✅ | — |
| TASK-005 | — | ✅ | — |
| TASK-006 | ✅ | ✅ | — |
| TASK-007 | — | — | ✅ |
