---
category: protocol
version: "2.0"
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

## report.md — 人读审计报告

### 结构

```markdown
# SecGuardian 安全扫描报告

> Scan ID: {{SCAN_ID}} | Command: /{{COMMAND}} | Date: {{DATE}}
> Path: {{PATH}} | Language: {{LANGUAGE}} | Mode: {{MODE}}

---

## 执行摘要

- 扫描文件: {{SCANNED_FILES}}
- 启用检测器: {{DETECTORS_EXECUTED}} / {{DETECTORS_MATCHED}}
- 检出总数: **{{TOTAL}}** (C: {{CRITICAL}} / H: {{HIGH}} / M: {{MEDIUM}} / L: {{LOW}})
- 安全评分: {{SCORE}}/100

---

## 检出清单

| ID | 严重度 | 置信度 | 检测器 | 文件:行 | 标题 |
|----|--------|--------|--------|---------|------|
| C-001 | 🔴 Critical | high | memory.buffer-overflow | src/parser.c:42 | strcpy 缓冲区溢出 |
| H-001 | 🟠 High | high | memory.null-dereference | src/network.c:305 | malloc 返回值未检查 |

---

## 详细发现

### C-001: strcpy 缓冲区溢出 [Critical]

| 属性 | 值 |
|------|-----|
| **文件** | `src/parser.c:42` |
| **检测器** | `memory.buffer-overflow` |
| **CWE** | [CWE-120](https://cwe.mitre.org/data/definitions/120.html) |
| **置信度** | high — 存在完整利用路径 |
| **函数** | `parse_input()` |

**问题描述**: ...

**代码段**:
\`\`\`c
  40: char buf[64];
  41: if (input) {
> 42:     strcpy(buf, user_input);   // ← 高危
  43:     process(buf);
  44: }
\`\`\`

**影响**: ...

**修复方案**:
\`\`\`c
// 替换为
strncpy(buf, user_input, sizeof(buf) - 1);
buf[sizeof(buf) - 1] = '\0';
\`\`\`

**修复工作量**: low | **修复风险**: none

---

## 修复优先级

### 🔴 立即修复 (Critical)
1. C-001: 使用 strncpy 替代 strcpy (src/parser.c:42)

### 🟠 本次迭代 (High)
2. H-001: malloc 后添加 NULL 检查 (src/network.c:305)

---

## 附录

- 扫描命令: /secguard ./src
- 检测器: memory.*, system.*
- 输出目录: .codeagent/secguard-secguardian/scans/{{SCAN_ID}}/
- SARIF: results.sarif (可导入 GitHub Code Scanning)
```

### 生成规则

1. **report.md 是主要输出** — 工程师打开目录首先阅读此文件
2. **每个检出包含完整修复建议** — 来自 detector 的 `## 修复指引` 节
3. **代码段包含上下文** — 前后各 2-3 行
4. **严重度用 emoji** — 🔴 Critical / 🟠 High / 🟡 Medium / 🔵 Low / ⚪ Info
5. **检出 ID 自我描述** — 格式 `<SEVERITY>-<DETECTOR_ABBREV>-<FILE_SLUG>-L<LINE>`，工程师一眼看懂

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

- **2.0** (当前): 人读/机读分离。`findings/*.json` 废弃。`report.md` 为主要人读输出。SARIF 始终生成。
- **1.x**: findings/*.json + manifest.json + --sarif 可选
