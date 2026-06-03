# C/C++ 安全加固 — 输出 Schema 参考

## finding.json 格式

每个检测到的安全问题，按以下格式输出到 `findings/<id>.json`：

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
  "analysis": {
    "description": "用户输入通过 strcpy 直接拷贝到 64 字节栈缓冲区，未做长度检查。超长输入将覆盖返回地址。",
    "impact": "攻击者可构造超长输入实现任意代码执行 (RCE)。",
    "confidence": "high"
  },
  "remediation": {
    "description": "将 strcpy 替换为 strncpy，确保 null 终止。更佳方案使用 std::string。",
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

## manifest.json 格式

```json
{
  "protocol": "2.0",
  "scan": {
    "id": "2026-05-23T14-30-00-a1b2",
    "command": "secguard",
    "extension": "secguard-secguardian",
    "timestamp": "2026-05-23T14:30:00Z",
    "duration_ms": 2300,
    "status": "completed"
  },
  "scope": {
    "path": "./src",
    "mode": "git-diff",
    "ref": "HEAD~1",
    "language": "cpp",
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
    { "id": "C-001", "severity": "critical", "detector": "memory.buffer-overflow",
      "cwe": "CWE-120", "file": "src/parser.c", "line": 42,
      "title": "Buffer overflow via strcpy", "finding_file": "findings/C-001.json" }
  ]
}
```

## 严重度定义

| 严重度 | 定义 | 示例 |
|--------|------|------|
| critical | 可远程利用、导致 RCE/LPE、CVSS ≥ 9.0 | strcpy 栈溢出、system() 注入 |
| high | 可远程利用、导致信息泄露/DoS、CVSS 7.0-8.9 | 格式字符串漏洞、路径穿越写 |
| medium | 本地利用或需用户交互、CVSS 4.0-6.9 | TOCTOU 竞争、整数溢出 |
| low | 理论风险、CVSS 0.1-3.9 | 未初始化变量、信息泄露 |
| info | 加固建议、非直接漏洞 | 编译标志缺失、过时 API |
