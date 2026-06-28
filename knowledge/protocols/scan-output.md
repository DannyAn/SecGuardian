---
category: protocol
version: "7.0"
---

# SecGuardian 扫描输出协议 7.0

所有 SecGuardian 命令（secguard、secaudit、secreview）的输出格式。v2.0 重新设计人读/机读分离架构。

## 设计原则

| 文件 | 受众 | 格式 | 用途 |
|------|------|------|------|
| `human/executive-summary.md` | 所有人（统一入口） | Markdown | 一页仪表盘：评分/发现分布/集中度/导航 |
| `report.md` | 安全工程师 | Markdown | 精简审计报告（5节） |
| `dashboard.html` | 管理层/审计 | HTML | 浏览器打开的精美报告 |
| `ai/remediation-pack.json` | AI Agent | JSON | 结构化修复包（含 finding 关联） |
| `results.sarif` | CI/CD | SARIF 2.1.0 | GitHub Code Scanning / GitLab SAST |
| `summary.json` | 仪表盘/程序 | JSON | 机读统计 |
| `status.json` | CI 门禁 | JSON | pass/fail 判定 |
| `delta.json` | 趋势分析 | JSON | 增量对比 |
| `manifest.json` | 元数据 | JSON | 扫描元数据 |
| `findings.json` | 轻量索引 | JSON | 检出索引 |

其余文件（index.json / dismissed.json / verification-audit.json）保持 v6.0 设计不变。

> **v7.0 变更 (2026-06-26)**: 消费者导向设计重构。新增 `human/executive-summary.md`（统一入口 + 发现分布交叉表）。新增 `ai/remediation-pack.json`（AI 修复包 + 关联发现）。新增 `dashboard.html`（自动生成 HTML）。`report.md` 精简到 5 节（移除管理层摘要/验证漏斗/合规表）。移除 developer/by-file/ 和 ai/attack-graph.json（概念验证后确认无真实消费者）。findings/<ns>/<detector>/ 目录树保持为工程师核心工作流，不变。
> **v5.0 变更 (2026-06-07)**: 单体 findings.json 重构为按 detector 组织的目录树。参见: [2026-06-07-findings-directory-tree-design.md](../../docs/superpowers/specs/2026-06-07-findings-directory-tree-design.md)
> **v4.0 变更 (2026-06-06)**: 引入 AI/Renderer 分离架构。
> **v3.0 变更 (2026-06-05)**: report.md §4 强制四段式结构。增加输出前质量门禁。


## 用户旅程

扫描输出的 15+ 文件对新用户不友好。按照这个顺序阅读：

### 工程师首次使用

```
Step 1: human/executive-summary.md
  → 看发现分布表："SQLi 影响 3 个文件，先修它"
Step 2: findings/web/sql-injection/
  → 集中修完一类问题
Step 3: findings/web/xss/
  → 再修下一类
Step 4: 重扫 → human/executive-summary.md 看评分变化
```

### 工程师第 N 次使用

```
Step 1: delta.json → 看新增/修复/持续存在
Step 2: findings/<type>/<detector>/ → 只修新增的
```

### AI 自动修复

```
Step 1: ai/remediation-pack.json
  → 丢给 Claude/Codex: "按 remediation-pack.json 修复"
```

### 管理层/采购评估

```
Step 1: human/executive-summary.md  → 一页看安全态势
Step 2: dashboard.html                 → 浏览器打开精美报告
```

---

## 目录结构 (v8.0 — 共享索引)

```
.codeagent/secguardian/
├── index.json                      # ★ 共享索引（所有命令复用）
├── secguard/<scan-id>/             # secguard 输出
│   ├── human/executive-summary.md
│   ├── findings/<ns>/<det>/<sha12>_<file>-<line>.json
│   ├── ai/remediation-pack.json
│   ├── report.md, dashboard.html, findings.json, results.sarif
│   ├── summary.json, manifest.json, status.json, delta.json
│   ├── dismissed.json, verification-audit.json
│   └── latest → <scan-id>/
├── secaudit/<scan-id>/             # secaudit 输出（同上结构）
└── secreview/<scan-id>/            # secreview 输出（同上结构）
```

索引文件（index.json）从每个 scan 目录移至 `secguardian/` 根级别，跨命令共享。
首次扫描自动生成，后续扫描自动复用。详见 commands/secguard.md Step 2a。

### 文件命名规范

文件名直接使用 finding ID（格式: `<SEVERITY>-<DETECTOR_ABBREV>-<FILE_SLUG>-L<LINE>`），利用其天然唯一性：

| 组成部分 | 说明 | 示例 |
|---------|------|------|
| `SEVERITY` | C/H/M/L/I | `H` |
| `DETECTOR_ABBREV` | 3-5 字符缩写 | `SQLI` |
| `FILE_SLUG` | 文件名去扩展名，特殊字符 → `_` | `webapp` |
| `L<LINE>` | 行号 | `L47` |
| 完整文件名 | — | `H-SQLI-webapp-L47.json` |

**不会碰撞**：同一行代码不会被同一 detector 重复报告。对齐 SARIF (partialFingerprints)、CodeQL (file-hash)、Semgrep (finding-hash) 的 ID-as-key 模式。

### v4.0 兼容模式（遗留）

v4.0 单体格式仍被支持（`--findings` flag），但不推荐用于新扫描：

```
findings.json               # v4.0: 单体文件（所有 finding 内联，生产环境会超大）
```

渲染器通过 `--findings` 读取 v4.0 格式，`--findings-dir` 读取 v5.0 目录树。

- `<extension-name>`: `secguardian`（索引共享） / `secguardian/secguard`（secguard 输出）
- `<scan-id>`: `YYYY-MM-DDTHH-mm-ss-<6-char-uuid>`

## 用户使用流程

按角色查找你需要的内容：

| 角色 | 第一步 | 第二步 |
|------|--------|--------|
| 👨‍💻 工程师（首次） | `human/executive-summary.md` 看发现分布 | `findings/<ns>/<detector>/` 集中修复 |
| 👨‍💻 工程师（第N次） | `delta.json` 看增量 | `findings/<ns>/<detector>/` 修新增的 |
| 🔐 安全工程师 | `report.md` 完整报告 | — |
| 🤖 AI Agent | `ai/remediation-pack.json` 修复包 | 自动修复 |
| 👔 管理层 | `human/executive-summary.md` 精要 | `dashboard.html` 精美报告 |
| 📊 CI/CD | `results.sarif` + `status.json` | — |




## human/executive-summary.md — 统一入口

所有角色的第一步。Renderer 从 summary.json + findings/ 目录树聚合生成。

### 内容模板

```markdown
# SecGuardian 安全扫描精要

> 扫描: <scan-id> | 项目: <path> | 语言: <lang>

## 安全态势

| 指标 | 值 |
|------|-----|
| 安全评分 | **<score>/100 — <grade>** |
| 扫描文件 | <files> |
| 总发现数 | <total> |

### 严重度分布

| 严重度 | 数量 |
|--------|------|
| 🔴 Critical | <n> |
| 🟠 High | <n> |
| 🟡 Medium | <n> |
| 🔵 Low | <n> |

### 发现分布（检测器 × 文件，Top-5）

| 检测器 | 发现数 | 涉及文件 |
|--------|--------|---------|
| memory.buffer-overflow | 3 | parser.c, network.c |
| web.sql-injection | 5 | webapp.py, auth.py |

### 风险集中度（文件 × 发现数，Top-5）

| 文件 | 发现数 | 占比 |
|------|--------|------|
| webapp.py | 8 | 35% |
| parser.c | 5 | 22% |

### Top 3 Critical 风险

| ID | 文件:行 | 标题 | CVSS |
|----|---------|------|------|

---

**下一步：**
- 👨‍💻 工程师 → `findings/<检测器>/` 集中修复一类问题
- 📋 查看完整报告 → `report.md`
- 🤖 AI 自动修复 → `ai/remediation-pack.json`
- 👔 管理层仪表盘 → `dashboard.html`
```

### 数据来源

| 字段 | 来源 |
|------|------|
| 扫描元数据 | findings.json（轻量索引） |
| 严重度分布 | summary.json findings_by_severity |
| 发现分布表 | 遍历 findings 列表，按 detector 聚合 |
| 风险集中度 | 遍历 findings 列表，按 file 聚合 |
| Top 3 Critical | findings 列表按 severity 排序 |

### 生成规则

1. 发现分布表只展示 Top-5 检测器（按涉及文件数排序）
2. 风险集中度表只展示 Top-5 文件（按发现数排序）
3. 如果扫描只有 1 个检测器命中，跳过发现分布表
4. 导航指向以相对路径给出，相对于 scan root

---

## report.md — 商业交付物（人读审计报告）

`report.md` 是 SecGuardian 的**核心商业交付物**。一份报告同时服务三个角色：

| 角色 | 阅读内容 | 关注点 |
|------|---------|--------|
| 决策者（CTO/客户） | human/executive-summary.md + dashboard.html | 安全评分、风险集中度、仪表盘 |
| 技术负责人 | §2 检出清单 + §4 修复路线图 | 优先级排序、预估工时 |
| 工程师 | §3 详细发现 | 证据链、修复代码、CWE 参考 |

### 安全评分算法

```
评分 = 100 × exp(-0.2×Crit - 0.1×High - 0.04×Med - 0.01×Low)
上限 100，下限 0

说明：使用指数衰减公式避免线性扣分快速归零。
线性扣分（旧公式）中 4 个 Critical 即归零，失去区分度。
指数衰减在 15 个 Critical 时仍能给出 ~5 分，
使"稍有防护"（80 分）和"完全无防护"（5 分）可见差异。

等级映射:
  80-100   A  优秀 — 可发布生产环境
  55-79    B  良好 — 建议修复 High+ 后发布
  35-54    C  及格 — 存在需关注的风险
  15-34    D  较差 — 禁止发布，必须修复所有 Critical
  0-14     F  危险 — 存在可远程利用的已知漏洞
```

### 完整模板

```markdown
# 🔐 SecGuardian 安全审计报告

> **Scan ID**: {{SCAN_ID}} | **命令**: /{{COMMAND}} | **日期**: {{DATE}}
> **扫描范围**: `{{PATH}}` | **语言**: {{LANGUAGE}} | **模式**: {{MODE}}
> **审计方**: SecGuardian XuanWu v{{VERSION}} | **60 检测器** | CWE Top 25 全覆盖

---

## 1. 扫描元数据

| 指标 | 值 |
|------|-----|
| 扫描命令 | /{{COMMAND}} {{PATH}} |
| 扫描语言 | {{LANGUAGE}} |
| 扫描文件 | {{SCANNED_FILES}} 个文件，{{SCANNED_LINES}} 行 |
| 检测器覆盖 | {{MATCHED}} matched, {{EXECUTED}} executed |
| 扫描耗时 | {{DURATION}}ms |
## 2. 检出清单

| ID | 严重度 | 置信度 | CWE | 文件:行 | 标题 |
|----|--------|--------|-----|---------|------|
| C-BOF-parser_c-42 | 🔴 Critical | high | CWE-120 | src/parser.c:42 | strcpy 缓冲区溢出 |
| H-NPD-network_c-305 | 🟠 High | high | CWE-476 | src/network.c:305 | malloc 返回值未检查 |
| H-CMD-executor_c-89 | 🟠 High | medium | CWE-77 | src/executor.c:89 | system() 命令注入 |

> **共 {{TOTAL}} 个检出** (C: {{C}} / H: {{H}} / M: {{M}} / L: {{L}})

---

## 3. 详细发现

### {{ID}}: {{TITLE}}

### 📍 1. Location — 问题位置

| 属性 | 值 |
|------|-----|
| **严重度** | {{SEVERITY_EMOJI}} {{SEVERITY_LABEL}} (CVSS {{CVSS}}) |
| **CWE** | [{{CWE_ID}}](https://cwe.mitre.org/data/definitions/{{CWE_NUM}}.html) |
| **文件** | `{{FILE}}:{{LINE}}` |
| **函数** | `{{FUNCTION}}()` |
| **代码** | `{{VULNERABLE_LINE}}` |
| **检测器** | `{{NAMESPACE}}.{{DETECTOR}}` |
| **置信度** | {{CONFIDENCE}} — {{CONFIDENCE_REASON}} |

### 📋 2. Evidence — 证据链

**判定依据**: {{WHY_THIS_IS_A_FINDING}}（引用 detector 的检测逻辑）

**代码上下文**:

```{{LANGUAGE}}
// {{FILE}}:{{CONTEXT_START}}-{{CONTEXT_END}}  {{FUNCTION}}()
... // 前 2-3 行上下文
{{VULNERABLE_LINE}}     // ← 漏洞点
... // 后 2-3 行上下文
```

**数据流路径** (如适用):

`{{SOURCE}}` → `{{PROPAGATION}}` → `{{SINK}}` → {{CONSEQUENCE}}

### ⚠️ 3. Impact — 影响评估

**攻击场景**: {{ATTACK_SCENARIO}}

**CVSS 3.1**: {{CVSS_SCORE}} — {{CVSS_VECTOR_STRING}}

**利用条件**: {{EXPLOITABILITY}}

### 🔧 4. Fix — 修复方案

```{{LANGUAGE}}
// ❌ Before
{{CODE_BEFORE}}

// ✅ After
{{CODE_AFTER}}
```

| 属性 | 值 |
|------|-----|
| **工作量** | {{EFFORT}} |
| **回滚风险** | {{RISK}} |
| **验证方法** | {{VERIFICATION}} |

**参考资料**:
- [{{CWE_ID}}](https://cwe.mitre.org/data/definitions/{{CWE_NUM}}.html)
- {{CERT_REF}} (如适用)
- {{OWASP_REF}} (如适用)

---

## 4. 修复路线图

按 `风险 × 可达性 ÷ 修复成本` 排序：

### 🔴 Phase 1 — 立即修复 ({{CRITICAL}} 项, 预计 {{CRITICAL_HOURS}}h)

| # | ID | 文件:行 | 标题 | 工作量 |
|---|-----|---------|------|--------|
| 1 | C-BOF-parser_c-42 | src/parser.c:42 | strcpy 缓冲区溢出 | ~5 min |

### 🟠 Phase 2 — 本次迭代 ({{HIGH}} 项, 预计 {{HIGH_HOURS}}h)

| # | ID | 文件:行 | 标题 | 工作量 |
|---|-----|---------|------|--------|
| 2 | H-NPD-network_c-305 | src/network.c:305 | malloc 返回值未检查 | ~2 min |
| 3 | H-CMD-executor_c-89 | src/executor.c:89 | system() 命令注入 | ~15 min |

### 🟡 Phase 3 — 下个迭代 ({{MEDIUM}} 项, 预计 {{MED_HOURS}}h)
### ⚪ Phase 4 — 技术债 ({{LOW}} 项, 预计 {{LOW_HOURS}}h)

> **预计总修复时间: {{TOTAL_HOURS}}h** | 修复后预估评分: {{FIXED_SCORE}}/100 ({{FIXED_GRADE}})

---

## 5. 附录

| 项目 | 值 |
|------|-----|
| 扫描工具 | SecGuardian XuanWu v{{VERSION}} |
| 扫描命令 | /{{COMMAND}} {{PATH}} |
| 检测器范围 | {{FILTERS}} ({{MATCHED}} matched, {{EXECUTED}} executed) |
| 扫描时间 | {{DURATION}}ms |
| 输出目录 | `.codeagent/secguardian/<cmd>/<scan-id>/` |
| SARIF | `results.sarif`（导入 GitHub Code Scanning / GitLab SAST / Azure DevOps） |
| 报表生成 | `pandoc report.md -o report.pdf --pdf-engine=weasyprint` |
```

### PDF 导出

`report.md` 可一键导出为专业 PDF 交付客户：

```bash
# 安装依赖 (macOS)
brew install pandoc weasyprint

# 导出 PDF
pandoc report.md -o report.pdf --pdf-engine=weasyprint \
  --metadata title="SecGuardian 安全审计报告" \
  --metadata author="SecGuardian XuanWu"
```

### 与商业竞品对比

| 能力 | Coverity | Snyk | SonarQube | **SecGuardian** |
|------|----------|------|-----------|----------------|
| 统一入口仪表盘 | ❌ | ❌ | ❌ | ✅ human/executive-summary.md |
| 安全评分 | ❌ | ✅ | ✅ | ✅ (A-F 等级) |
| AI 修复包 | ❌ | ❌ | ❌ | ✅ ai/remediation-pack.json |
| 工程师工作流（按检测器） | ❌ | ❌ | ❌ | ✅ findings/<ns>/<detector>/ |
| 仪表盘 | ❌ | ❌ | ❌ | ✅ dashboard.html 自动生成 |
| 合规映射 | ✅ CWE | ❌ | ✅ OWASP | ✅ OWASP + CWE |
| 修复路线图 | 部分 | ❌ | ❌ | ✅ 四阶段 + 预估工时 |
| AI 可执行 | ❌ | ❌ | ❌ | ✅ remediation-pack → AI Agent |

### 生成规则

1. **report.md 是主要输出** — 工程师打开目录首先阅读此文件
2. **每个检出必须包含完整四段式** — 📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix，内容来自 detector 的 `## 检测逻辑` 和 `## 修复指引` 节
3. **代码段包含上下文** — 前后各 2-3 行
4. **严重度用 emoji** — 🔴 Critical / 🟠 High / 🟡 Medium / 🔵 Low / ⚪ Info
5. **检出 ID 自我描述** — 格式 `<SEVERITY>-<DETECTOR_ABBREV>-<FILE_SLUG>-L<LINE>`，工程师一眼看懂
6. **质量门禁强制执行** — 写入报告前执行 Step 4b 检查清单，每个 finding 四段式完整性不达标则补充后重试（最多 3 次）

### 检出 ID 格式

```
C-BOF-parser_c-L36    ← Critical, BufferOverFlow, parser.c:36
H-NPD-network_c-L305  ← High, NullPointerDeref, network.c:305  
M-DLK-concurrency_c-L43 ← Medium, DeadLock, concurrency.c:43
```

60 个 detector 的 3-5 字符大写缩写见 [threat-catalog.md](../../threat-catalog.md)。

## manifest.json — 扫描元数据

精简版，不再内联完整 finding 内容：

```json
{
  "protocol": "2.0",
  "scan": {
    "id": "2026-05-31T14-30-00-a1b2c3",
    "command": "secguard",
    "extension": "secguardian",
    "timestamp": "2026-05-31T14:30:00Z",
    "duration_ms": 2300,
    "status": "completed"
  },
  "scope": {
    "path": "./src",
    "mode": "full",
    "language": "cpp",
    "scanned_files": 8,
    "scanned_lines": 450
  },
  "filters": {
    "raw": "*",
    "namespaces": ["memory", "concurrency", "system", "crypto", "web", "error"],
    "detectors_matched": 60,
    "detectors_executed": 23
  },
  "summary": {
    "critical": 1,
    "high": 2,
    "medium": 3,
    "low": 0,
    "info": 0,
    "total": 6,
    "score": 55
  },
  "report": "report.md",
  "sarif": "results.sarif"
}
```

## summary.json — 仪表盘摘要

超轻量，适合快速解析和累积统计：

```json
{
  "scan_id": "2026-05-31T14-30-00-a1b2c3",
  "score": 55,
  "findings": {
    "critical": 1,
    "high": 2,
    "medium": 3,
    "low": 0,
    "total": 6
  },
  "by_namespace": {
    "memory": 2,
    "system": 1,
    "crypto": 1,
    "error": 2
  },
  "by_language": {
    "c": 4,
    "cpp": 2
  }
}
```

## results.sarif — 机读

**始终生成**，不再需要 `--sarif` flag。SARIF 2.1.0 是 GitHub/GitLab/Azure 的原生 SAST 输入格式。

详见 [SARIF 输出协议](sarif-output.md)。

## status.json — CI 门禁

```json
{
  "passed": false,
  "exit_code": 1,
  "threshold": {
    "critical_max": 0,
    "high_max": 5,
    "breached": true,
    "breached_at": "critical"
  }
}
```

## 协议演进

- **7.0** (当前): 消费者导向设计。新增 `human/executive-summary.md` 统一入口。新增 `ai/remediation-pack.json` AI 修复包。新增 `dashboard.html`。report.md 精简到 5 节。移除 developer/by-file/ 和 ai/attack-graph.json。
- **6.0**: 三轮验证管道（`dismissed.json` + `verification-audit.json`）。
- **5.0**: 目录树架构。单体 findings.json → 轻量索引 + findings/ 目录树。
- **4.0**: AI/Renderer 分离架构。
- **3.0**: 四段式结构 + 质量门禁。
- **2.0**: 人读/机读分离。
- **1.x**: findings/*.json + manifest.json + --sarif 可选

---

## dismissed.json — 验证抑制记录 (v6.0)

```json
{
  "scan_id": "scan-20260605-173324-2434534",
  "dismissed": [
    {
      "finding_id": "H-BOF-parser_c-L36",
      "dismissed_at_round": "P1",
      "dismiss_reason": "Project SafeCopy wrapper guarantees bounds check at parser.c:30",
      "original_severity": "High",
      "original_detector": "memory.buffer-overflow"
    }
  ],
  "summary": {
    "total_findings": 74,
    "dismissed_by_p1": 22,
    "dismissed_by_p2": 17,
    "dismissed_by_p3": 10,
    "certified": 25
  }
}
```

## verification-audit.json — 验证审计追踪 (v6.0)

```json
{
  "scan_id": "scan-20260605-173324-2434534",
  "pipeline_version": "1.0",
  "rounds": {
    "p1_semantic": {"input_count": 74, "exempted": 18, "no_exemption": 52, "uncertain": 4},
    "p2_counter_evidence": {"input_count": 56, "counter_evidence_found": 17, "counter_evidence_not_found": 39},
    "p3_court": {"input_count": 39, "confirmed": 18, "suspected": 10, "dismissed": 11}
  },
  "certified_count": 28,
  "dismissed_count": 46
}
```
