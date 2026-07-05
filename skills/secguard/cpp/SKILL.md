---
name: secguard-cpp
description: 对 C/C++ 代码进行安全加固项排查，支持全量/增量扫描、命名空间过滤，输出符合 Scan Output Protocol 2.0。当用户请求C/C++安全扫描、内存安全检测、缓冲区溢出、C++代码审计、指针安全时使用。
category: language-specific
language: cpp
topic: [memory, concurrency, system, crypto]
---

# C/C++ 安全加固排查

对 C/C++ 代码进行安全加固排查。编排 26 个检测器，支持全量/增量扫描和命名空间过滤。

## 📄 Output Protocol

> 以下输出格式遵循 `internal/output/output_contract.md`。

## 输出协议

> **输出**: 遵循 `knowledge/protocols/scan-output.md`（报告格式：report.md + results.sarif + summary.json）。

## ⚙️ Engine Instructions
### Engine Instructions

> 以下执行指令属于 Engine 职责（参见 `internal/engine/engine_contract.md`）。当前由 LLM prompt 代行。未来 Engine 实现后将被 Engine 取代。

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
  output_dir = .codeagent/secguardian/secguard/scans/scans/<scan_id>/
  mkdir -p <output_dir>/findings/
```

### Phase 2: 使用索引器上下文

> **核心原则：index.json 是唯一的数据源。禁止绕过它直接遍历文件系统或启动外部工具。**

从 Command 层面生成的 `index.json` 中提取以下结构化数据。后续每个检测器执行前，先查对应数据再精准读取目标函数。

#### 2.1 文件清单

从 `files` 数组获取完整扫描文件列表。**不要用 `find`/`ls`/glob 重新遍历文件系统。**

#### 2.2 符号定位表

从 `symbols.functions` 构建查找表：

```
函数名 → {文件路径, 起始行, 结束行}
```

**使用方式**：检测器需要找特定 API（如 `pthread_mutex_lock`、`fclose`、`socket`）时，先遍历 symbols.functions 按函数名匹配，得到 `文件:行号` 后精准读取该函数代码。**不要在无关文件中搜索。**

#### 2.3 调用图

读取 `call_graph.edges`（caller → callee 列表），构建反向索引：

```
被调用函数 → [调用它的函数列表]
```

**使用方式**：需要跨函数追踪时（如检查 `handle(fd)` 内部是否 close fd），查调用图找到 handle 的实现位置后精准读取。

#### 2.4 分配/释放对

直接读取 `alloc_free.pairs`，每条记录包含：
- `alloc_func`, `alloc_file`, `alloc_line` — 分配点
- `free_sites[]` — 所有释放点（file + line）

**使用方式**：内存类检测器（double-free、UAF、memory-leak、mismatched-free）直接从此数据出发，不再手工搜索 malloc/free。

#### 2.5 锁图

直接读取 `lock_graph.mutexes`，每条记录包含：
- `file`, `lock_line`, `unlock_line` — lock/unlock 位置

**使用方式**：lock-misuse 检测器直接遍历此数据，检查每个 lock 所在函数的所有退出路径。

#### 2.6 禁止事项

- ❌ **不要启动 clangd 或任何 LSP server** — indexer (tree-sitter) 已提供所有代码结构数据
- ❌ **不要使用 compile_commands.json、bear 或任何编译数据库**
- ❌ **不要逐文件全文读取** — 始终从 indexer 数据出发，精准定位后按需读取
- ❌ **不要重新遍历文件系统** — index.json 的 `files` 数组是唯一的文件清单

### Phase 3: 解析 Filters + 加载检测器

1. 加载 `../../../knowledge/language-index.md` 获取命名空间映射
2. 逗号分割 filter → 每个 filter 匹配命名空间 → 去重合并
3. 先通过 index.json 符号表匹配过滤（跳过不包含相关符号的检测器）后，仅加载匹配到的 `active` 状态检测器详情

### Phase 4: 按严重度排序执行

```
Critical detectors → High detectors → Medium detectors
```

对每个匹配到的检测器，加载 `knowledge/guard-rules/<name>.md` 详情，用于分析。注意：匹配到的检测器指经过 Phase 3 语言过滤+符号过滤后的子集，不是全部 67 个。
注意：匹配到的检测器指经过 Phase 3 语言过滤+符号过滤后的子集，不是全部 67 个。，利用 Phase 2 加载的 index.json 符号表定位检测目标，而非遍历文件。

### Phase 5: 持久化输出

> 遵循 `knowledge/protocols/scan-output.md` (v2.0，人读/机读分离)。
>
> **每个检出必须满足四段式完整性**（Command 层 Step 4b 质量门禁强制检查）：
> 1. **📍 Location** — 文件路径 + 行号 + 函数名 + 代码行内容
> 2. **📋 Evidence** — 代码上下文（前后 3 行）+ 判定依据（引用 detector 的检测逻辑）+ 数据流路径
> 3. **⚠️ Impact** — 攻击场景描述 + CVSS 3.1 评分 + 利用条件
> 4. **🔧 Fix** — Before/After 代码 + 工作量 + 验证方法 + CWE 参考链接
>
> SARIF 结果同样要求：`message.markdown` 包含完整四段式，`relatedLocations` 标注 Source → Sink 路径，`fixes` 包含 before/after 替换。

按以下结构写入 `.codeagent/secguardian/secguard/scans/scans/<scan-id>/`：

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




## 执行指令（I/O 优化版）

> 以下执行方式遵循 `engine_contract.md` 和 `output_contract.md` 的性能要求。

### 源文件读取（index 驱动）

1. 从 `index.json` -> `symbols.functions` / `call_graph.edges` / `alloc_free.pairs` 获取符号定位
2. **禁止逐文件阅读全文**。只能通过 index.json 符号表定位目标函数后，按需读取该行及其前后 10 行作为上下文。不得读取未出现在符号表中的文件。

### 检测器加载（批量 + 按需）

1. 先加载 `knowledge/language-index.md`（57 行）获取全量检测器清单
2. 按符号匹配过滤（快速排除不匹配的检测器）
3. 仅对匹配的检测器加载详情

### Finding 输出（批量）

1. 所有 findings 收集到临时结构
2. 用 `python3 render-report.py --findings <dir>/findings.json --output <dir>` 批量输出

## 错误处理

- 部分检测器执行失败 → `scan.status = "partial"`，在 manifest 中记录失败的 detector
- git diff 失败（非 git 仓库）→ 降级为 `mode: "full"`
- 没有 active 检测器 → 提前返回，无 findings

## 🎯 Detector Selection (Skill Layer)

> 以下检测器选择规则属于 Skill 层职责。Skill 决定 WHICH detectors 运行，不决定 HOW 运行。

## 可用检测器

完整列表见 [language-index.md](../../../knowledge/language-index.md)，26 个（6 active + 20 planned）。
