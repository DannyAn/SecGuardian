# Output Schemas — Protocol v2.0

本文件仅提供历史示例。当前输出格式以 `$SECGUARDIAN_HOME/knowledge/protocols/scan-output.md` 的 Scan Output Protocol 8.0 为准。

## report.md — 人读（Markdown 报告）

每个检出以 Markdown 子章节形式嵌入 `report.md`，包含位置、证据链和修复方案：

```markdown
### C-BOF-parse_input-42: Buffer overflow via strcpy

| 属性 | 值 |
|------|-----|
| 严重度 | 🔴 Critical (CVSS 9.8) |
| 检测器 | `memory.buffer-overflow` (CWE-120) |
| 位置 | `src/parser.c:42` → `parse_input()` |
| 置信度 | High |

#### 证据链

```c
// src/parser.c:40-44
char buf[64];                          // 40: 64 字节栈缓冲区
if (input) {                           // 41: 来自用户输入
    strcpy(buf, user_input);           // 42: ← 漏洞点：无长度检查
    process(buf);                      // 43: 处理后继续使用
}                                      // 44
```

#### 修复方案

将 `strcpy` 替换为 `strncpy`，确保 null 终止。更佳方案使用 `std::string`。

```c
// Before
strcpy(buf, user_input);

// After
strncpy(buf, user_input, sizeof(buf) - 1);
buf[sizeof(buf) - 1] = '\0';
```

**修复工作量**: Low | **回滚风险**: None

#### 参考

- [CWE-120: Buffer Copy without Checking Size of Input](https://cwe.mitre.org/data/definitions/120.html)
- [SEI CERT STR31-C](https://wiki.sei.cmu.edu/confluence/x/1dUxBQ)
```

## results.sarif — 机读（SARIF 2.1.0）

[OASIS SARIF 2.1.0](https://docs.oasis-open.org/sarif/sarif/v2.1.0/) 标准格式，始终生成。GitHub Code Scanning / GitLab SAST / Azure DevOps 原生消费。

关键要求（[GitHub 2025-07 起强制](https://github.blog/changelog/2025-07-22-code-scanning-per-tool-category/)）：
- `partialFingerprints` 去重
- 每个 tool/category 独立上传，禁止合并多工具结果
- Gzip 压缩后 ≤ 10 MB

SARIF result 核心字段映射：

| SARIF 字段 | SecGuardian 来源 |
|-----------|-----------------|
| `ruleId` | `detector.name` |
| `level` | `severity` → `error`/`warning`/`note` |
| `message.text` | `title` |
| `locations[].physicalLocation` | `file` + `line` + `column` |
| `partialFingerprints` | `id` 的 SHA-256 |
| `properties.cwe` | `detector.cwe` |
| `properties.cvss` | 按严重度映射 |

## manifest.json — 入口（元数据 + 索引）

```json
{
  "protocol": "2.0",
  "scan": {
    "id": "sc-20260603-143000-a1b2",
    "command": "secguard",
    "extension": "secguard",
    "timestamp": "2026-06-03T14:30:00Z",
    "duration_ms": 2300,
    "status": "completed"
  },
  "scope": {
    "path": "./src",
    "mode": "full",
    "language": "cpp",
    "scanned_files": 12,
    "scanned_lines": 450
  },
  "summary": {
    "findings": {
      "critical": 1, "high": 2, "medium": 0, "low": 0, "info": 0,
      "total": 3
    }
  },
  "findings": [
    {
      "id": "C-BOF-parse_input-42",
      "severity": "critical",
      "detector": "memory.buffer-overflow",
      "cwe": "CWE-120",
      "file": "src/parser.c",
      "line": 42,
      "title": "Buffer overflow via strcpy",
      "report_section": "#c-bof-parse_input-42-buffer-overflow-via-strcpy"
    }
  ]
}
```

## summary.json — 仪表盘

```json
{
  "scan_id": "sc-20260603-143000-a1b2",
  "timestamp": "2026-06-03T14:30:00Z",
  "by_severity": {"critical": 1, "high": 2, "medium": 0, "low": 0, "info": 0},
  "by_namespace": {"memory": 2, "system": 1},
  "by_language": {"c": 3},
  "security_score": 45
}
```

## status.json — CI 门禁

```json
{
  "pass": false,
  "exit_code": 2,
  "reason": "1 critical finding(s) exceed threshold (max: 0)",
  "thresholds": {"critical": 0, "high": 5, "medium": 10}
}
```
