---
name: secguard-cpp
description: 对 C/C++ 代码进行安全加固项排查，支持全量/增量扫描、命名空间过滤，输出符合 Scan Output Protocol 1.0
category: language-specific
language: cpp
---

# secguard-cpp

对 C/C++ 代码进行安全加固排查。编排 26 个检测器，支持全量/增量扫描和命名空间过滤。

## 输出协议

**必须遵循 `knowledge/protocols/scan-output.md` (Scan Output Protocol 1.0)**。

## 执行流程

### Step 1: 解析输入 + 创建输出目录

```
输入: /secguard ./src git diff HEAD~1 memory.*,system.*

解析:
  path = ./src
  mode = git-diff, ref = HEAD~1
  filters = memory.*, system.*

创建输出目录:
  scan_id = 2026-05-23T14-30-00-a1b2 (当前时间 + 8位短UUID)
  output_dir = .codeagent/secguard-secguardian/scans/<scan_id>/
  mkdir -p <output_dir>/findings/
```

### Step 2: 使用索引器上下文

> 索引器已在 Command 层面执行完毕，`index.json` 已生成在当前扫描的 `<output_dir>/` 下。
>
> 你需要读取 `../<output_dir>/index.json`（Command 中 Step 2c 的路径）获取以下结构化上下文，并在后续所有检测步骤中使用：
>
> - `files` — 完整的源码文件清单（确定扫描对象）
> - `symbols.functions` — 函数名→文件:行号映射（精确定位检测目标，无需遍历文件）
> - `call_graph.edges` — caller→callee 关系（追踪数据流和影响范围）
> - `alloc_free.pairs` — malloc/free 配对（内存管理分析）

**全量模式**: 基于 index.json 中的 `files` 和 `symbols` 确定扫描对象，**不要重新遍历文件系统。**

**增量模式**:
1. `git -C <path> diff <ref> --name-only` → 变更文件列表
2. `git -C <path> diff <ref>` → 解析 @@ 行号范围
3. 对照 index.json 中的 symbol 位置，仅分析变更行所在的函数。

### Step 3: 解析 Filters + 加载检测器

1. 加载 `references/detector-index.md` 获取命名空间映射
2. 逗号分割 filter → 每个 filter 匹配命名空间 → 去重合并
3. 仅加载 `active` 状态的检测器 (跳过 `planned`)

### Step 4: 按严重度排序执行

```
Critical detectors → High detectors → Medium detectors
```

每个 detector 读取 `knowledge/detectors/<name>.md`，利用 Step 2 加载的 index.json 符号表定位检测目标，而非遍历文件。

### Step 5: 生成 Findings

对每个检测到的安全问题，创建 `findings/<id>.json`：

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

### Step 6: 生成 manifest.json

```json
{
  "protocol": "1.0",
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
    { "id": "C-001", "severity": "critical", "detector": "memory.buffer-overflow", "cwe": "CWE-120", "file": "src/parser.c", "line": 42, "title": "Buffer overflow via strcpy", "finding_file": "findings/C-001.json" },
    { "id": "H-001", "severity": "high", "detector": "memory.null-dereference", "cwe": "CWE-476", "file": "src/network.c", "line": 305, "title": "malloc return not checked", "finding_file": "findings/H-001.json" },
    { "id": "H-002", "severity": "high", "detector": "system.command-injection", "cwe": "CWE-77", "file": "src/executor.c", "line": 89, "title": "system() with user input", "finding_file": "findings/H-002.json" }
  ]
}
```

### Step 7: 输出扫描摘要

向用户输出 Markdown 格式的扫描摘要（见 commands/secguard.md 的输出格式示例），并告知输出目录路径。

## 错误处理

- 部分检测器执行失败 → `scan.status = "partial"`，在 manifest 中记录失败的 detector
- git diff 失败（非 git 仓库）→ 降级为 `mode: "full"`
- 没有 active 检测器 → 提前返回，无 findings

## 可用检测器

完整列表见 [detector-index.md](references/detector-index.md)，26 个（6 active + 20 planned）。
