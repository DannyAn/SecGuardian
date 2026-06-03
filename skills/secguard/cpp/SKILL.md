---
name: cpp
description: 对 C/C++ 代码进行安全加固项排查，支持全量/增量扫描、命名空间过滤，输出符合 Scan Output Protocol 2.0。当用户请求C/C++安全扫描、内存安全检测、缓冲区溢出、C++代码审计、指针安全时使用。
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

### Phase 5: 持久化输出

> 遵循 `knowledge/protocols/scan-output.md` (v2.0，人读/机读分离)。

按以下结构写入 `.codeagent/secguard-secguardian/scans/<scan-id>/`：

**人读**：
- `report.md` — 完整安全扫描报告（Markdown）。每个检出包含：位置、证据链（上下文代码片段）、检测器判定依据、具体修复建议（含 before/after 代码）。
- `manifest.json` — 扫描元数据 + 检出索引（引用 report.md 章节锚点）。

**机读**（CI/CD 系统消费）：
- `results.sarif` — SARIF 2.1.0（[OASIS 标准](https://docs.oasis-open.org/sarif/sarif/v2.1.0/)，GitHub Code Scanning / GitLab SAST / Azure DevOps 原生支持）。
- `summary.json` — 轻量仪表盘统计（按严重度/命名空间分组）。
- `status.json` — CI 门禁判定（pass/fail + exit_code）。
- `delta.json` — 与上次扫描的增量对比（新增/修复/仍存在）。

SARIF 格式要求（[GitHub 2025-07 起强制](https://github.blog/changelog/2025-07-22-code-scanning-per-tool-category/)）：
- `partialFingerprints` 去重（基于 `id` + `detector.name` + `location.file` + `location.line`）
- 每个 tool/category 独立上传，禁止合并多个工具结果

向用户输出扫描摘要并告知输出目录路径。

## 错误处理

- 部分检测器执行失败 → `scan.status = "partial"`，在 manifest 中记录失败的 detector
- git diff 失败（非 git 仓库）→ 降级为 `mode: "full"`
- 没有 active 检测器 → 提前返回，无 findings

## 可用检测器

完整列表见 [detector-index.md](references/detector-index.md)，26 个（6 active + 20 planned）。
