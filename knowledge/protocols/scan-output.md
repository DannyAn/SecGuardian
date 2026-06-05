---
category: protocol
version: "3.0"
---

# SecGuardian 扫描输出协议 2.0

所有 SecGuardian 命令（secguard、secaudit、secreview）的输出格式。v2.0 重新设计人读/机读分离架构。

## 设计原则

| 文件 | 受众 | 格式 | 用途 |
|------|------|------|------|
| `report.md` | 工程师/审计师 | Markdown | 完整安全审计报告，含执行摘要、发现详情、修复建议 |
| `results.sarif` | CI/CD 系统 | SARIF 2.1.0 | GitHub Code Scanning / GitLab SAST / Azure DevOps |
| `summary.json` | 仪表盘/统计 | JSON | 轻量统计：按严重度/命名空间/语言的检出数 |
| `manifest.json` | 程序入口 | JSON | 扫描元数据 + 检出索引（引用 report.md 章节） |
| `status.json` | CI 门禁 | JSON | pass/fail 判定 + exit_code |
| `delta.json` | 趋势分析 | JSON | 与上一次扫描的增量对比 |

> **v3.0 变更 (2026-06-05)**: report.md §4 详细发现改为强制四段式结构（📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix）。增加输出前质量门禁（Step 4b）。SARIF 增加 `message.markdown` 和 `relatedLocations` 要求。

## 目录结构

```
.codeagent/<extension-name>/scans/<scan-id>/
├── report.md                # ★ 人读审计报告（主要输出）
├── results.sarif            # 机读 — SARIF 2.1.0（始终生成）
├── summary.json             # 仪表盘统计
├── manifest.json            # 扫描元数据 + 检出索引
├── status.json              # CI 门禁判定
├── delta.json               # 增量对比（vs 上一次扫描）
└── latest → <scan-id>/      # 符号链接 → 最新扫描
```

- `<extension-name>`: `secguard-secguardian` / `secaudit-secguardian` / `secreview-secguardian`
- `<scan-id>`: `YYYY-MM-DDTHH-mm-ss-<6-char-uuid>`

## 用户使用流程

工程师拿到扫描结果后的典型路径：

| 我想做什么 | 打开哪个文件 | 为什么 |
|-----------|------------|--------|
| **★ 看整体安全水位（商业决策）** | `report.md` §1-2 | 安全评分 A-F + 合规仪表盘 + 趋势，可直接发给 CTO/客户 |
| **快速看一眼有什么问题** | `report.md` §3 或 `manifest.json` | Markdown 表格 或 JSON 索引，检出 ID/严重度/文件/行号 |
| **深入了解某个漏洞 + 改代码** | `report.md` §4 | 证据链（代码上下文）+ before/after 修复方案 |
| **规划修复工作** | `report.md` §5 | 四阶段修复路线图，按风险 × 成本排序，预估工时 |
| **交给 AI Agent 批量修复** | `report.md` | 对 AI 说："读取 report.md §4，按每个修复方案修改代码" |
| **导出 PDF 交付客户** | `report.md` | `pandoc report.md -o report.pdf --pdf-engine=weasyprint` |
| **接入 CI/CD 流水线** | `results.sarif` | SARIF 2.1.0，GitHub/GitLab/Azure 原生消费，PR 内联注释 |
| **查看趋势** | `delta.json` | 与 `latest` 符号链接指向的上次扫描做增量对比 |

## report.md — 商业交付物（人读审计报告）

`report.md` 是 SecGuardian 的**核心商业交付物**。一份报告同时服务三个角色：

| 角色 | 阅读章节 | 关注点 |
|------|---------|--------|
| 决策者（CTO/客户） | §1 执行摘要 + §2 合规仪表盘 | 安全评分、合规状态、风险趋势 |
| 技术负责人 | §3 检出清单 + §5 修复路线图 | 优先级排序、预估工时 |
| 工程师 | §4 详细发现 | 证据链、修复代码、CWE 参考 |

### 安全评分算法

```
评分 = 100 - (Critical×25 + High×10 + Medium×3 + Low×1)
上限 100，下限 0

等级映射:
  90-100   A  优秀 — 可发布生产环境
  75-89    B  良好 — 建议修复 High+ 后发布
  60-74    C  及格 — 存在需关注的风险
  40-59    D  较差 — 禁止发布，必须修复所有 Critical
  0-39     F  危险 — 存在可远程利用的已知漏洞
```

### 完整模板

```markdown
# 🔐 SecGuardian 安全审计报告

> **Scan ID**: {{SCAN_ID}} | **命令**: /{{COMMAND}} | **日期**: {{DATE}}
> **扫描范围**: `{{PATH}}` | **语言**: {{LANGUAGE}} | **模式**: {{MODE}}
> **审计方**: SecGuardian XuanWu v{{VERSION}} | **60 检测器** | CWE Top 25 全覆盖

---

## 1. 执行摘要

| 指标 | 本次 | 上次 | 趋势 |
|------|------|------|------|
| 安全评分 | **{{SCORE}}/100 — {{GRADE}}** | {{LAST_SCORE}} | {{TREND}} |
| 扫描文件 | {{SCANNED_FILES}} | — | — |
| 代码行数 | {{SCANNED_LINES}} | — | — |
| Critical | {{CRITICAL}} | {{LAST_CRITICAL}} | {{CRITICAL_TREND}} |
| High | {{HIGH}} | {{LAST_HIGH}} | {{HIGH_TREND}} |
| Medium | {{MEDIUM}} | {{LAST_MEDIUM}} | {{MED_TREND}} |
| Low | {{LOW}} | {{LAST_LOW}} | {{LOW_TREND}} |

> **评级**: {{GRADE_DESC}}
> {{RECOMMENDATION}}

---

## 2. 合规仪表盘

### OWASP Top 10 (2021)

| 类别 | 覆盖率 | 检出数 |
|------|--------|--------|
| A01:2021 访问控制失效 | ✅ 覆盖 | {{A01_COUNT}} |
| A02:2021 加密失败 | ✅ 覆盖 | {{A02_COUNT}} |
| A03:2021 注入 | ✅ 覆盖 | {{A03_COUNT}} |
| A04:2021 不安全设计 | ⚠️ 部分 | 0 |
| A05:2021 安全配置错误 | ✅ 覆盖 | {{A05_COUNT}} |
| A06:2021 脆弱组件 | ✅ 覆盖 | {{A06_COUNT}} |
| A07:2021 认证失效 | ✅ 覆盖 | {{A07_COUNT}} |
| A08:2021 软件和数据完整性 | ⚠️ 部分 | 0 |
| A09:2021 日志和监控 | ✅ 覆盖 | {{A09_COUNT}} |
| A10:2021 SSRF | ✅ 覆盖 | {{A10_COUNT}} |

### CWE Top 25 (2024)

**覆盖率: 25/25 (100%)**

| CWE | 名称 | 检出数 |
|-----|------|--------|
| CWE-79 | XSS | {{XSS_COUNT}} |
| CWE-89 | SQL 注入 | {{SQLI_COUNT}} |
| CWE-120 | 缓冲区溢出 | {{BOF_COUNT}} |
| ... | ... | ... |

---

## 3. 检出清单

| ID | 严重度 | 置信度 | CWE | 文件:行 | 标题 |
|----|--------|--------|-----|---------|------|
| C-BOF-parser_c-42 | 🔴 Critical | high | CWE-120 | src/parser.c:42 | strcpy 缓冲区溢出 |
| H-NPD-network_c-305 | 🟠 High | high | CWE-476 | src/network.c:305 | malloc 返回值未检查 |
| H-CMD-executor_c-89 | 🟠 High | medium | CWE-77 | src/executor.c:89 | system() 命令注入 |

> **共 {{TOTAL}} 个检出** (C: {{C}} / H: {{H}} / M: {{M}} / L: {{L}})

---

## 4. 详细发现

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

## 5. 修复路线图

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

## 6. 附录

| 项目 | 值 |
|------|-----|
| 扫描工具 | SecGuardian XuanWu v{{VERSION}} |
| 扫描命令 | /{{COMMAND}} {{PATH}} |
| 检测器范围 | {{FILTERS}} ({{MATCHED}} matched, {{EXECUTED}} executed) |
| 扫描时间 | {{DURATION}}ms |
| 输出目录 | `.codeagent/{{EXTENSION}}/scans/{{SCAN_ID}}/` |
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
| 执行摘要 | ✅ | ✅ | ✅ | ✅ |
| 安全评分 | ❌ | ✅ | ✅ | ✅ (A-F 等级) |
| 合规映射 | ✅ CWE | ❌ | ✅ OWASP | ✅ OWASP + CWE |
| 修复路线图 | 部分 | ❌ | ❌ | ✅ 四阶段 + 预估工时 |
| AI 可执行 | ❌ | ❌ | ❌ | ✅ report.md → AI Agent |
| 免费导出 PDF | ❌ | ❌ | ❌ | ✅ pandoc 开源工具 |
| 单文件交付 | ❌ (需 Web) | ❌ | ❌ (PDF) | ✅ Markdown (人 + AI 通读) |

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
    "extension": "secguard-secguardian",
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

- **3.0** (当前): report.md §4 强制四段式结构（📍 Location → 📋 Evidence → ⚠️ Impact → 🔧 Fix）。增加质量门禁（Step 4b）。SARIF 要求 `message.markdown` + `relatedLocations`。
- **2.0**: 人读/机读分离。`findings/*.json` 废弃。`report.md` 为主要人读输出。SARIF 始终生成。
- **1.x**: findings/*.json + manifest.json + --sarif 可选
