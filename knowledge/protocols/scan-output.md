---
category: protocol
version: "1.0"
---

# SecGuardian 扫描输出协议 1.0

所有 SecGuardian 命令（secguard、secaudit、secreview）必须遵循本协议的输出格式。

## 目录结构

```
.codeagent/<extension-name>/scans/<scan-id>/
├── manifest.json            # 扫描元数据 + 结果摘要
└── findings/                # 检出问题详情
    ├── <severity>-<NNN>.json
    └── ...
```

- `<extension-name>`: 如 `secguard-secguardian`、`secaudit-secguardian`、`secreview-secguardian`
- `<scan-id>`: 格式 `YYYY-MM-DDTHH-mm-ss-<short-uuid>`，如 `2026-05-23T14-30-00-a1b2c3d4`

## manifest.json

### 完整 Schema

```json
{
  "protocol": "1.0",
  "scan": {
    "id": "2026-05-23T14-30-00-a1b2c3d4",
    "command": "secguard|secaudit|secreview",
    "extension": "secguard-secguardian",
    "timestamp": "2026-05-23T14:30:00Z",
    "duration_ms": 2300,
    "status": "completed|partial|failed"
  },
  "scope": {
    "path": "./src",
    "mode": "full|git-diff",
    "ref": "HEAD~1",
    "language": "cpp|java|python|go|auto",
    "changed_files": 12,
    "scanned_files": 12,
    "scanned_lines": 95
  },
  "filters": {
    "raw": "memory.*,system.*",
    "resolved": ["memory.*", "system.*"],
    "detectors_matched": 18,
    "detectors_executed": 8,
    "detectors_skipped": 10
  },
  "summary": {
    "findings": {
      "critical": 1,
      "high": 2,
      "medium": 0,
      "low": 0,
      "info": 0,
      "total": 3
    }
  },
  "findings": [
    {
      "id": "C-001",
      "severity": "critical",
      "detector": "memory.buffer-overflow",
      "cwe": "CWE-120",
      "file": "src/parser.c",
      "line": 42,
      "title": "Buffer overflow in parse_input()",
      "finding_file": "findings/C-001.json"
    }
  ]
}
```

### 字段说明

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `protocol` | string | ✓ | 协议版本号 |
| `scan.id` | string | ✓ | 唯一扫描 ID |
| `scan.command` | enum | ✓ | secguard / secaudit / secreview |
| `scan.extension` | string | ✓ | 所属 extension 完整名称 |
| `scan.timestamp` | ISO8601 | ✓ | 扫描开始时间 (UTC) |
| `scan.duration_ms` | int | ✓ | 扫描耗时 (毫秒) |
| `scan.status` | enum | ✓ | completed / partial (部分检测器失败) / failed |
| `scope.path` | string | ✓ | 扫描目标路径 |
| `scope.mode` | enum | ✓ | full (全量) / git-diff (增量) |
| `scope.ref` | string | - | git diff 引用 (增量模式时必填) |
| `scope.language` | string | ✓ | 目标语言 |
| `filters.raw` | string | - | 用户输入的原始 filter 字符串 |
| `filters.resolved` | string[] | - | 解析后的 filter 列表 |
| `filters.detectors_matched` | int | ✓ | 匹配到的检测器总数 |
| `filters.detectors_executed` | int | ✓ | 实际执行的检测器数 (仅 active) |
| `summary.findings` | object | ✓ | 按严重度分组的检出数量 |
| `findings` | array | ✓ | 检出摘要列表 (内联，详情在 findings/ 目录) |

## findings/<severity>-<NNN>.json

### 完整 Schema

```json
{
  "id": "C-001",
  "severity": "critical",
  "title": "Buffer overflow via strcpy in parse_input()",
  "detector": {
    "name": "memory.buffer-overflow",
    "namespace": "memory",
    "cwe": "CWE-120",
    "cvss": 9.8
  },
  "location": {
    "file": "src/parser.c",
    "line": 42,
    "column": 10,
    "function": "parse_input",
    "symbol": "strcpy"
  },
  "code": {
    "snippet": "strcpy(buf, user_input);",
    "context": {
      "before": [
        {"line": 40, "content": "char buf[64];"},
        {"line": 41, "content": "if (input) {"}
      ],
      "vulnerable": {"line": 42, "content": "    strcpy(buf, user_input);"},
      "after": [
        {"line": 43, "content": "    process(buf);"},
        {"line": 44, "content": "}"}
      ]
    }
  },
  "diff_status": {
    "in_diff": true,
    "diff_line": "+42",
    "is_new_code": true
  },
  "confidence": {
    "level": "high",
    "score": 90,
    "evidence": ["path_verified", "symbol_verified", "chain_complete", "actionable_remediation"]
  },
  "reflection": {
    "validators_passed": ["path", "symbol"],
    "deduplicated_from": []
  },
  "analysis": {
    "description": "用户输入 user_input 通过 strcpy 直接拷贝到 64 字节的栈缓冲区 buf 中，未做长度检查。如果 user_input 超过 64 字节，将覆盖栈上的返回地址和其他局部变量。",
    "impact": "攻击者可构造超长输入，覆盖函数返回地址实现任意代码执行 (RCE)。",
    "confidence": "high"
  },
  "remediation": {
    "description": "将 strcpy 替换为 strncpy，并确保目标缓冲区以 null 结尾。更好的方案是使用 std::string 替代 C 风格字符串。",
    "code_before": "strcpy(buf, user_input);",
    "code_after": "strncpy(buf, user_input, sizeof(buf) - 1);\nbuf[sizeof(buf) - 1] = '\\0';",
    "effort": "low",
    "risk_of_fix": "none"
  },
  "references": [
    {"type": "cwe", "id": "CWE-120", "url": "https://cwe.mitre.org/data/definitions/120.html"},
    {"type": "cert", "id": "STR31-C", "url": "https://wiki.sei.cmu.edu/confluence/x/1dUxBQ"}
  ]
}
```

### 字段说明

| 字段 | 类型 | 必需 | 说明 |
|------|------|------|------|
| `id` | string | ✓ | 唯一 ID (C-001, H-001, M-001, L-001, I-001) |
| `severity` | enum | ✓ | critical / high / medium / low / info |
| `title` | string | ✓ | 一行标题 |
| `detector.name` | string | ✓ | 检测器全名 (namespace.detector 或 analysis-skill-name) |
| `detector.namespace` | string | - | 所属命名空间 |
| `detector.cwe` | string | - | CWE 编号 |
| `detector.cvss` | float | - | CVSS 3.1 评分 |
| `location` | object | ✓ | 文件/行号/函数/符号 |
| `code` | object | - | 代码片段和上下文 |
| `diff_status` | object | - | 增量模式下的 diff 状态 |
| `analysis` | object | ✓ | 问题描述、影响评估、置信度 |
| `remediation` | object | ✓ | 修复建议、代码对比、工作量评估 |
| `references` | array | - | CWE/CERT/OWASP 参考链接 |

## 严重度前缀

| 前缀 | Severity | 说明 |
|------|----------|------|
| `C-` | critical | 可直接导致代码执行或数据泄露 |
| `H-` | high | 可被利用但需要一定条件 |
| `M-` | medium | 降低系统安全强度 |
| `L-` | low | 最佳实践违反，暂无直接利用路径 |
| `I-` | info | 信息性发现，无直接安全影响 |

## 跨命令兼容性

三个命令共享相同的输出格式，差异仅在 `manifest.json` 的部分字段：

| 字段 | secguard | secaudit | secreview |
|------|----------|----------|-----------|
| `filters` | ✓ (detector namespaces) | - | ✓ (language) |
| `scope.mode` | full / git-diff | full | full / git-diff |
| `findings[].detector.namespace` | ✓ (memory/system/...) | - | - |
| `findings[].detector.cwe` | ✓ | ✓ | ✓ |
| `findings[].detector.cvss` | ✓ | ✓ | - |

## SARIF 输出

当命令执行时附加 `--sarif` 参数，将在扫描输出目录同时生成 `results.sarif`（SARIF 2.1.0 标准格式）。

详见 [SARIF 输出协议](sarif-output.md)。

```
.codeagent/<extension-name>/scans/<scan-id>/
├── manifest.json
├── results.sarif          # ← SARIF 2.1.0 (--sarif 时生成)
└── findings/
```

### SARIF 集成

SARIF 文件可直接上传到：
- **GitHub Code Scanning**: `github/codeql-action/upload-sarif@v3`
- **GitLab SAST**: `artifacts:reports:sast`
- **Azure DevOps**: SARIF SAST Scans 标签

### 置信度字段

SARIF 输出的每个 result 包含 `properties.confidence` 字段：

| 置信度 | 含义 | 建议处理 |
|--------|------|---------|
| `high` | AI 确认存在可验证利用路径 | 立即修复 |
| `medium` | 存在风险模式但缺乏完整利用链证据 | 人工复查 |
| `low` | 安全最佳实践违反，无可直接利用路径 | 按优先级排期 |

用户可在 GitHub Security 标签中按置信度过滤，有效降低误报噪声。

## 协议版本演进

- **1.1** (当前): 新增 `--sarif` 支持、`confidence` 置信度字段
- **1.0**: 初始版本，覆盖所有三个命令的核心输出格式
- 后续版本通过 `protocol` 字段区分，向下兼容
