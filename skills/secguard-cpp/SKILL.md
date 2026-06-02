---
name: secguard-cpp
description: 对 C/C++ 代码进行安全加固项排查，支持全量/增量扫描、命名空间过滤，输出符合 Scan Output Protocol 1.0。当用户请求C/C++安全扫描、内存安全检测、缓冲区溢出、C++代码审计、指针安全时使用。
category: language-specific
language: cpp
topic: [memory, concurrency, system, crypto]
---

# C/C++ 安全加固排查

对 C/C++ 代码进行安全加固排查。编排 26 个检测器，支持全量/增量扫描和命名空间过滤。

## 输出协议

> **输出**: 遵循 `knowledge/protocols/scan-output.md`（报告格式：report.md + results.sarif + summary.json）。

## 执行流程

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`（含 `symbols.functions`、`call_graph.edges`、`files`）。排查时优先利用符号表定位检测目标，而非遍历文件。

### Phase 1: 解析输入 + 创建输出目录

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

### Phase 2: 使用索引器上下文

利用前置生成的 `index.json` 获取符号表和文件清单，定位检测目标。

**全量模式**: 基于 index.json 中的 `files` 和 `symbols` 确定扫描对象，**不要重新遍历文件系统。**

**增量模式**:
1. `git -C <path> diff <ref> --name-only` → 变更文件列表
2. `git -C <path> diff <ref>` → 解析 @@ 行号范围
3. 对照 index.json 中的 symbol 位置，仅分析变更行所在的函数。

### Phase 3: 解析 Filters + 加载检测器

1. 加载 `references/detector-index.md` 获取命名空间映射
2. 逗号分割 filter → 每个 filter 匹配命名空间 → 去重合并
3. 仅加载 `active` 状态的检测器 (跳过 `planned`)

### Phase 4: 按严重度排序执行

```
Critical detectors → High detectors → Medium detectors
```

每个 detector 读取 `knowledge/detectors/<name>.md`，利用 Phase 2 加载的 index.json 符号表定位检测目标，而非遍历文件。

### Phase 5: 生成 Findings

对每个检测到的安全问题，创建 `findings/<id>.json`。完整 JSON Schema 参见 [output-schemas.md](references/examples/output-schemas.md)。

核心字段：`id`、`severity` (critical/high/medium/low/info)、`detector.name`、`detector.cwe`、`location.file`、`location.line`、`analysis.description`、`analysis.confidence`、`remediation.description`、`remediation.code_before/after`。

### Phase 6: 生成 manifest.json

按 `knowledge/protocols/scan-output.md` 的 manifest 格式生成。包含 `protocol`、`scan`、`scope`、`filters`、`summary`、`findings` 段。完整 Schema 参见 [output-schemas.md](references/examples/output-schemas.md)。

### Phase 7: 输出扫描摘要

向用户输出 Markdown 格式的扫描摘要（见 commands/secguard.md 的输出格式示例），并告知输出目录路径。

## 错误处理

- 部分检测器执行失败 → `scan.status = "partial"`，在 manifest 中记录失败的 detector
- git diff 失败（非 git 仓库）→ 降级为 `mode: "full"`
- 没有 active 检测器 → 提前返回，无 findings

## 可用检测器

完整列表见 [detector-index.md](references/detector-index.md)，26 个（6 active + 20 planned）。
