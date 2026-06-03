# SecGuardian 设计决策日志

> 记录项目架构演进过程中的关键头脑风暴、设计权衡和最终方案。
> 按时间倒序排列，最新讨论在前。

---

## 2026-06-03 — 输出协议升级：商业交付物设计

### 背景

工程师提出灵魂问题：每一次扫描结果要能拿出来展示产品价值，`manifest.json` 只够给工程师看，缺少能给决策者/客户看的商业交付物。

### 讨论要点

- **业界参考**：研究了 Coverity、Snyk、SonarQube、CodeQL 的报告格式
- **核心洞察**：一份报告同时服务三个角色（决策者、技术负责人、工程师），不应该分散在多个文件中
- **差异化优势**：Markdown 格式天然支持人 + AI 双重消费，竞品的 HTML/PDF 报告不具备这一特性

### 最终方案

`report.md` 升级为六章结构的专业审计报告：

| 章节 | 受众 | 内容 |
|------|------|------|
| §1 执行摘要 | 决策者/客户 | 安全评分 A-F + 趋势 + 关键数字 |
| §2 合规仪表盘 | 决策者 | OWASP Top 10 + CWE Top 25 覆盖率矩阵 |
| §3 检出清单 | 技术负责人 | 可排序表格：ID/严重度/CWE/文件/标题 |
| §4 详细发现 | 工程师/AI | 证据链 + before/after 修复代码 + CWE 参考 |
| §5 修复路线图 | 技术负责人 | 四阶段优先级排序 + 预估工时 |
| §6 附录 | 所有人 | 方法论、工具信息、PDF 导出指南 |

**安全评分算法**：`100 - (Critical×25 + High×10 + Medium×3 + Low×1)`，A(90+)~F(0-39)

**与竞品对比**：SecGuardian 是唯一同时提供 A-F 评分 + OWASP/CWE 双覆盖 + AI 可执行 + 免费 PDF 导出的方案。

### 影响范围

- `knowledge/protocols/scan-output.md` — 完全重写 report.md 模板
- `commands/*.md` — 添加"如何使用扫描结果"指引

---

## 2026-06-03 — 输出协议重构：人读 Markdown + 机读 SARIF

### 背景

原先 Phase 5 叫"生成 Findings"，输出 `findings/<id>.json`。命名不专业，JSON 对人类不友好，缺少机读标准格式。

### 讨论要点

- **业界标准**：SARIF 2.1.0 是 OASIS 国际标准，GitHub Code Scanning / GitLab SAST / Azure DevOps 三家原生支持
- **人读 vs 机读分离**：Markdown 给人和 AI Agent 消费，SARIF 给 CI/CD 系统消费
- **GitHub 2025-07 强制要求**：每个 tool/category 独立上传 SARIF，禁止合并多工具结果

### 最终方案

```
.codeagent/<extension>/scans/<scan-id>/
├── report.md         ← 人读（Markdown，证据链 + before/after 修复）
├── results.sarif     ← 机读（SARIF 2.1.0 OASIS 标准）
├── manifest.json     ← 入口（元数据 + 检出索引）
├── summary.json      ← 仪表盘（按严重度/命名空间统计）
├── status.json       ← CI 门禁（pass/fail + 阈值）
└── delta.json        ← 增量对比（vs 上次扫描）
```

Phase 命名统一为"持久化输出"，所有 6 个命令和 12 个 skill 的 Output Phase 统一升级。

### 影响范围

- `knowledge/protocols/scan-output.md` — v2.0 协议定义
- `commands/*.md` + `commands/gemini/*.toml` — Step 4 全部升级
- `skills/*/*/SKILL.md` — Output Phase 统一引用 v2.0
- `skills/secguard/cpp/references/examples/output-schemas.md` — 重写为 Markdown + SARIF 示例

---

## 2026-06-03 — 项目瘦身：移除 CLI 死代码和 prompt-templates

### 背景

对项目做全面审视时发现：
- `internal/` 含 4 个死代码包（prompt, budget, reflection, scheduler），零 import
- `knowledge/prompt-templates/` 是独立 CLI 的 prompt 拼装，与 AI Agent 主流程无关
- `main.go` 含 scan/audit/review/detectors 等 CLI 子命令，被 AI Agent 命令完全取代

### 最终方案

**删除内容**：
- `internal/prompt/` (1 file)
- `internal/budget/` (1 file)
- `internal/reflection/` (4 files)
- `internal/scheduler/` (1 file)
- `knowledge/prompt-templates/` (4 files)
- `main.go` CLI 子命令 + 60-entry 检测器注册表

**保留核心**（indexer only）：
- `parser/` — 双模解析（tree-sitter + 正则回退）
- `indexer/` — 文件遍历、调用图、alloc/free、锁图
- `context/` — 分析上下文结构体

### 结果

`internal/`：13 files / 5 packages → 7 files / 3 packages。`main.go`：507 → 193 行 (-62%)

### 影响范围

- `internal/` 全部 Go 源文件
- `scripts/secguardian.sh` — 移除 prompt-template 引用

---

## 2026-06-03 — Skills 目录重构：27 平铺 → 3 命名空间

### 背景

`skills/` 下 27 个平铺目录（`secaudit-attack-surface-analysis/`），前缀表达归属。随着 skill 增多，维护困难。

### 讨论要点

- 每个 command（secaudit/secguard/secreview）天然对应一个 skills 子目录
- 目录层级即可表达归属，`SKILL.md` 的 `name` 不再需要前缀
- 打包脚本 `package.sh` 可以按 command 精准组装

### 最终方案

**源码结构**（干净）：
```
skills/
  secaudit/{17 skills}/
  secguard/{5 skills}/
  secreview/{5 skills}/
```

**部署结构**（防碰撞）：
```
.opencode/plugins/secguardian/skills/
  secaudit-attack-surface-analysis/   ← deploy.sh 自动加回前缀
  secguard-cpp/
  secreview-cpp/
```

### 关键设计

`deploy.sh` 在部署时从 dist 目录名提取 command 前缀（`secaudit-secguardian` → `secaudit`），加到 skill 目录名前面。源码干净，部署无碰撞。

### 影响范围

- `skills/` 全部 27 个目录重命名
- `scripts/package.sh` — path 拼接 `${cmd}/${name}`
- `scripts/deploy.sh` — copy 时加前缀
- `commands/*.md` + `commands/gemini/*.toml` — skill 引用路径更新

---

## 2026-06-03 — 删除 knowledge/cheatsheets

### 背景

上一轮重构新建了 `knowledge/cheatsheets/` 作为 detectors 和 skills 之间的速查层。经审视发现：

### 结论

**过度设计。** 4 个文件里 2 个是 detectors 的摘要复读，1 个分类错误，只有 1 个有增量价值。

| 文件 | 处置 |
|------|------|
| `crypto-algorithms.md` | 删除 — 9 个 crypto detectors 已逐个覆盖 |
| `injection-patterns.md` | 删除 — detectors 已含逐语言检测逻辑 |
| `secrets-detection.md` | 迁移 → `knowledge/detectors/` |
| `tls-config.md` | 迁移 → `skills/secaudit/secure-transport/references/` |

### 教训

不要在已有完备数据层（detectors）和流程层（skills）之间硬塞中间层。如果新增内容有价值，应该归入 detectors（执行原语）或 skill references（辅助资料）。

### 影响范围

- `knowledge/cheatsheets/` — 整个目录删除
- 15 个文件中的 cheatsheets 引用全部清理

---

## 2026-06-02 — 跨平台双模 Parser

### 背景

原 `secguardian-index` 依赖 tree-sitter CGO 绑定，只能本地编译（macOS arm64）。Linux/Windows 用户无法使用。

### 讨论要点

- **业界调研**：tree-sitter 纯 Go 实现（gotreesitter）、Python 绑定、Rust 绑定
- **方案 A**：换用 gotreesitter（纯 Go，零 CGO）— 改动最小
- **方案 B**：改用 Python tree-sitter — 需完全重写
- **方案 C**：改用 Rust — 需完全重写

### 最终方案

**方案 A-改**：不换库，而是双模编译：

```
parser_ts.go   //go:build cgo      → tree-sitter 完整 AST
parser_re.go   //go:build !cgo     → 纯 Go 正则回退
```

同一套公开 API（ParseFile、ParseResult 等），根据 CGO 是否可用自动选择。CGO 可用时享受完整 tree-sitter 解析，不可用时正则回退仍能提取函数/类型/变量。

### 结果

- 四平台全部可编译：darwin-arm64(tree-sitter)、darwin-amd64(regex)、linux-amd64(regex)、linux-arm64(regex)、windows-amd64(regex)
- 正则回退：60 functions vs 60 functions (tree-sitter)，功能等价
- 二进制大小：tree-sitter 8.4M vs regex 3.3M

### 影响范围

- `internal/parser/parser_ts.go` — CGO 版（原 parser.go）
- `internal/parser/parser_re.go` — 纯 Go 正则版（新增）
- `scripts/package.sh` — 五平台并行编译

---

## 2026-06-02 — 品牌扩展名设计：三平台统一

### 背景

OpenCode 项目级部署将 27 个 skill 平铺在 `.opencode/skills/` 下，没有品牌命名空间。用户研究发现 OpenCode 的 `skills/` 和 `commands/` 顶层目录是给项目手写文件用的，扩展应该放在 `plugins/<brand>/` 下。

### 最终方案

三平台统一品牌命名空间：

| 平台 | 路径 |
|------|------|
| Claude Code | `.claude/plugins/secguardian/` |
| OpenCode | `.opencode/plugins/secguardian/` |
| Gemini CLI | `.gemini/extensions/secguardian/` |

每个平台都包含 `commands/` + `skills/` + `knowledge/` + `scripts/` + plugin manifest。

### 关键设计

- `deploy.sh` 的 `deploy_opencode()` 完全重写
- 二进制在 zip 内统一命名为 `secguardian-index`（无平台后缀）
- Shell wrapper 优先查 canonical 名，回退到平台特定名
- 旧平铺部署自动检测并清理

### 影响范围

- `scripts/deploy.sh` — deploy_opencode 重写, deploy_claude 补全 knowledge+scripts
- 6 个命令文件 — indexer 搜索路径更新

---

## 2026-06-02 — Knowledge cheatsheets 架构

### 背景（已废弃）

原先 `knowledge/` 下只有 detectors（执行原语）和 languages（语言画像）。审计 skill 的大段检查清单内联在 SKILL.md 中，导致文件过长（150-200 行）。

### 当时方案（后于 2026-06-03 删除）

新建 `knowledge/cheatsheets/` 作为跨 skill 共享速查层，包含 4 个领域聚合表。

### 删除原因

2026-06-03 经审视认定该层为过度设计，所有内容已迁移或删除。详见上方"删除 knowledge/cheatsheets"条目。

### 教训

知识库的层次应该尽量扁平。如果 detectors 已经完备，不要为了"好看"而创建中间层。新增的参考内容如果是对单个 skill 的辅助，放入 `skills/<name>/references/`；如果是对多个 skill 都有价值，应该设计为正规 detector。

---

## 2026-06-02 — Bug 修复：Parser slice bounds panic

### 背景

`secguardian-index` 解析 `crypto.c` 时 panic：`slice bounds out of range [:1382] with capacity 1024`

### 根因

`safeUtf8Text()` 使用固定 1024 字节 buffer 调用 `node.Utf8Text(buf)`。tree-sitter 要求 buffer >= 节点字节数，crypto.c 中某节点 1382 字节超出限制。

### 修复

- 删除 `safeUtf8Text()`
- `extractTypeName()` 改用 `safeText(content, start, end)` 直接从源文件读取
- `safeText()` 增加 `start >= len(content)` 和 `start > end` 边界检查

### 影响范围

- `internal/parser/parser.go` — 1 function deleted, 1 hardened

---

## 2026-06-02 — 27 Skills 规范化

### 背景

27 个 `SKILL.md` 存在 frontmatter 不一致、描述缺乏触发引导、secguard-* 缺少 topic 字段、Phase/Step 命名不统一等问题。

### 最终方案

| 改动 | Before | After |
|------|--------|-------|
| topic 字段 | 单值/缺失/数组混用 | 统一 YAML 数组 |
| description | 仅"做什么" | 增加"当用户请求...时使用"触发短语 |
| H1 标题 | 含英文括号 | 纯中文描述 |
| Phase 命名 | secguard 用 Step | 统一 Phase |
| 前置声明 | 格式不统一 | 统一 blockquote |
| 输出协议 | 仅 secguard 引用 | 23/27 明确引用 |

Secreview 5 个 skill 从 ~45 行扩展到 ~100 行，增加结构化 Phase 1-5 + 检测表 + 代码示例。

### 影响范围

- 全部 27 个 SKILL.md

---

## 设计原则总结

通过本轮（2026-06-02 ~ 2026-06-03）密集重构，沉淀出以下原则：

1. **源码干净，部署隔离** — skills 按 command 分目录，deploy 时自动加前缀
2. **知识扁平，不做过度抽象** — detectors + languages 两层足够，不要再塞中间层
3. **核心做小，不要 CLI 包袱** — internal/ 只保留 indexer，AI agent 命令覆盖全部交互
4. **输出即交付物** — report.md 是一个人+AI 通读的商业报告，不是 JSON dump
5. **人读/机读分离** — Markdown 给人 + AI，SARIF 给 CI/CD，各司其职
6. **命名即文档** — Phase 持久化输出 > Phase 生成 Findings
7. **平台感知，用户无感** — 双模 parser + 五平台二进制 + 品牌扩展名，用户只管下载解压
