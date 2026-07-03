# GEMINI.md — SecGuardian for Gemini CLI

> **核心认知**: SecGuardian 不是传统 SAST。只有 Go 索引器是编译代码，其余全部是 Markdown 知识文件，由 AI Agent 在扫描时动态加载。修改任何 `.md` → `bash scripts/deploy.sh all --build` → AI 重启即可生效。

## 开发守则第一条：SDD 规格驱动开发

> ⚠️ **禁止收到开发需求后直接编码**。SecGuardian 采用 Spec-Driven Development (SDD) 方法论。所有非 trivial 变更必须按七环顺序执行，不允许跳过环节。

### SDD 七环流程

```
🧠 Brainstorm → 📋 Spec → 📝 ADR → 📐 Plan → 🔨 Task → 📊 Progress → 🔄 Change
```

| # | 环节 | 产出物（Feature Package 内） | 回答的问题 |
|---|------|---------------------------|-----------|
| 1 | 🧠 Brainstorm | `docs/sdd/brainstorm-log.md` | 为什么做？考虑过哪些方案？否决了哪些？ |
| 2 | 📋 Spec | `FEATURE-XXX/spec.md` | 做什么？（WHAT）做到什么程度？ |
| 3 | 📝 ADR | `FEATURE-XXX/adr.md` | 关键架构决策 + 否决方案（最有长期价值） |
| 4 | 📐 Plan | `FEATURE-XXX/plan.md` | 怎么实现？（HOW）改哪些文件？ |
| 5 | 🔨 Task | `FEATURE-XXX/tasks/TASK-NNN.md` | 每一步的详细执行指令 + 验证命令 |
| 6 | 📊 Progress | `FEATURE-XXX/progress.md` | 做到哪了？中断后 30 秒内恢复上下文 |
| 7 | 🔄 Change | `FEATURE-XXX/changes/CHANGE-NNN.md` | 需求为什么和最初设计不同？ |

### AI Agent 执行流程

1. **收到开发需求 → 先打开** [`docs/sdd/README.md`](docs/sdd/README.md)
2. **检查** [`docs/sdd/epics/`](docs/sdd/epics/) 是否已有对应 Feature Package
3. **有 Feature** → 加载 spec/adr/plan → 按 Task 执行 → 更新 progress
4. **无 Feature** → 走完整 SDD 流程：Brainstorm → Spec → ADR → Plan → Task
5. **Task 完成 → commit → 更新 progress.md**

### 跳过条件（缺一不可）

- 仅限：拼写/格式修复、单行 bug fix、过期注释更新
- 不涉及：新增功能、行为变更、架构修改、数据模型变更

> 完整方法论见 [`docs/sdd/README.md`](docs/sdd/README.md)

## 构建与部署

| 你做了什么 | 执行命令 | 耗时 |
|-----------|---------|------|
| 修改 skills/knowledge/commands | `bash scripts/deploy.sh all --build` | ~30s |
| 修改 internal/ (Go 索引器) | `bash scripts/deploy.sh all --build --verify` | ~35s |
| 怀疑部署状态异常 | `bash scripts/dev-verify.sh` | ~5s |
| 彻底清理重来 | `bash scripts/deploy.sh all --uninstall --build --verify` | ~60s |

```bash
bash scripts/deploy.sh all --uninstall                   # 卸载部署
bash scripts/deploy.sh all --uninstall --clean-scans    # 完全抹除
```

部署后 Gemini CLI 扩展位于 `.gemini/extensions/secguardian/`。

## 命令使用

```
/secguard ./src cpp          # 安全加固扫描（支持 cpp/go/java/python/js）
/secguard ./src *            # 全量扫描，自动检测语言
/secaudit taint-analysis     # 深度安全审计（17 项分析 skill）
/secreview ./src java        # 安全编码规范检视
```

首次使用需执行 `/skills reload` 让 Gemini CLI 扫描 skills 目录。

## 扫描输出

扫描结果在 `.codeagent/<extension-name>/scans/<scan-id>/`:

```
├── findings/          # ★ v5.0: 按 detector 分类的 finding 目录树
├── findings.json      # 轻量索引（同名升级，不含四段式详情）
├── report.md          # 人读审计报告（六章）
├── results.sarif      # SARIF 2.1.0 (CI/CD 集成)
├── summary.json       # 仪表盘统计
├── manifest.json      # 扫描元数据
├── status.json        # CI 门禁
└── delta.json         # 增量对比
```

## 验证流程 — L1-L5 分层验证体系

> **设计原则**: 这是一个可推广的 AI Agent Native 项目验证方法。每层有独立的验证脚本，
> 按"修改了什么 → 跑哪层"的对应关系执行，从快到慢、从局部到全局。

### 五层验证

| 层 | 命令 | 覆盖范围 | 耗时 | 何时运行 |
|----|------|---------|------|---------|
| **L1 设计一致性** | `bash scripts/self-check.sh` | detector ↔ index ↔ manifest 交叉校验、stale references、Go 编译 | ~5s | 每次 commit 前 |
| **L2 结构完整性** | `bash scripts/ci-check.sh` | JSON 格式、版本一致性、skill 目录完整性、Go 编译+冒烟 | ~15s | push 前 |
| **L3 部署环境** | `bash scripts/dev-verify.sh` | 二进制文件、indexer health、平台部署结构 | ~10s | 部署后 |
| **L4 架构端到端** | `bash scripts/e2e-verify.sh` | findings schema、渲染器 6 文件、SARIF 合规、4-segment 质量门禁、安全评分、CI gate、delta、3 命令、5 语言 | ~15s | 修改架构层后 (**必须**) |
| **L5 全量发布** | L1 + L2 + L3 + L4 全部按顺序 | 全覆盖 | ~45s | 发布前 |

### 按修改范围选择验证层

```bash
# 日常修改 (skills/knowledge/commands) — L1
bash scripts/self-check.sh

# 修改了 deploy.sh 或 extension 结构 — L1 + L2
bash scripts/self-check.sh && bash scripts/ci-check.sh

# 修改了 render-report.py 或 findings-schema.json — L1 + L4
bash scripts/self-check.sh && bash scripts/e2e-verify.sh

# 修改了 internal/ (Go 索引器) — L1 + L2 + L3 + L4
bash scripts/self-check.sh && bash scripts/ci-check.sh && bash scripts/dev-verify.sh && bash scripts/e2e-verify.sh

# 发布前全量 — L5
bash scripts/self-check.sh && bash scripts/ci-check.sh && bash scripts/dev-verify.sh && bash scripts/e2e-verify.sh
```

### 每层验证的具体内容

**L1 — self-check.sh (设计一致性)**
- detector 文件名 ↔ manifest.json ↔ 目录一致性 (82 项检查)
- stale reference 检测
- Go 源码编译验证

**L2 — ci-check.sh (结构完整性)**
- JSON 格式有效性
- 版本号一致性
- skill 目录结构完整性
- Go 编译 + 索引器冒烟测试（对示例代码建索引并验证输出）

**L3 — dev-verify.sh (部署环境)**
- 5 平台二进制文件存在性
- indexer health check (HEALTH:OK)
- indexer 功能验证（对 cpp-vuln-demo 建索引）
- 三平台（Claude Code / OpenCode / Gemini CLI）部署结构验证

**L4 — e2e-verify.sh (架构端到端, 37 项检查)**
- Findings Schema 合规 (4 项)
- Renderer 输出 (9 项)
- SARIF 2.1.0 结构合规
- 4-Segment 质量门禁 (2 项)
- 安全评分计算验证
- CI 门禁 exit code 验证 (2 项)
- Delta 增量对比 (new/fixed/still_open)
- 3 命令类型覆盖 (6 项)
- 多语言索引器覆盖 (C/C++, Java, Python, Go, JavaScript)
- 渲染器性能 (< 5s)

### CI 模式

```bash
bash scripts/e2e-verify.sh --ci     # 失败时 exit 1，适合 CI pipeline
bash scripts/e2e-verify.sh --quick  # 跳过第 9 节 (多语言索引)，快速反馈
```

## 可推广模式：AI Agent Native 项目分层验证方法论

这套 L1-L5 验证体系可用于任何 AI Agent Native 项目（即核心逻辑由 Markdown/Skill 定义、AI 在运行时加载的项目）：

1. **每个 AI 入口文件**（CLAUDE.md / AGENTS.md / GEMINI.md）必须包含验证流程章节
2. **分层命名**：L1(设计) → L2(结构) → L3(部署) → L4(架构) → L5(全量)
3. **每层一个脚本**，独立可运行、非零退出码
4. **"改了什么 → 跑哪层"映射表**，新工程师/AI Agent 无需猜测
5. **CI 模式**（`--ci` flag）确保 pipeline 可集成
6. **覆盖矩阵**文档化，每个检查项对应一个可验证的断言

## 核心架构：Tree-sitter 索引器 + AI Agent 扫描

SecGuardian 的架构基础是两层管线：**Tree-sitter 语义索引器**（Go 编译原生代码）→ **AI Agent 安全扫描**（Markdown 知识文件）。理解索引器的能力和边界是理解整个项目的前提。

### 整体数据流

```
项目源码 (C/C++/Go/Java/Python/JS)
    ↓
secguardian-index (Go 二进制, 调用 Tree-sitter CGO 解析)
    ↓
index.json (AnalysisContext: symbols + call_graph + alloc_free + lock_graph)
    ↓
AI Agent (加载 67 个 detector Markdown → 语义分析 → 输出 findings)
    ↓
render-report.py (渲染 report.md + SARIF 2.1.0 + CI 门禁)
```

### Go 索引器 (internal/) — 六阶段管线

`internal/` 是 Go module (`go 1.25.3`)，产出唯一的原生二进制 `secguardian-index`。

```
阶段 1: Parse All Files   → parser.ParseFile() 遍历 AST，提取函数/变量/类型
阶段 2: Build Symbol Index → indexer.ExtractSymbols() 聚合全局符号表
阶段 3: Build Call Graph   → indexer.BuildCallGraph() 文本近似调用图
阶段 4: Match Alloc/Free   → indexer.MatchAllocFree() malloc/free 配对
阶段 5: Build Lock Graph   → indexer.BuildLockGraph() 互斥锁使用记录
阶段 6: Write Context      → context.AnalysisContext 序列化为 JSON
```

### 双解析器架构 (编译期二选一)

| 解析器 | 文件 | Build Tag | 解析方式 | 平台 |
|--------|------|-----------|---------|------|
| Tree-sitter | `parser_ts.go` | `cgo` | Tree-sitter CGO 绑定，真实 AST | 仅 darwin-arm64 原生构建 |
| Regex Fallback | `parser_re.go` | `!cgo` | 纯 Go 正则近似匹配 | 所有跨平台构建 |

两个文件定义完全相同的类型（`ParseResult`, `FunctionInfo`, `VariableInfo`, `TypeInfo`），Go build tag 在编译期二选一，对外接口一致。

### Tree-sitter 语法覆盖 (5 语言 + JS 正则)

`parser_ts.go` 通过 CGO 链接以下 Tree-sitter 语法库：

| 语言 | Tree-sitter 包 | AST 节点识别 |
|------|---------------|-------------|
| C | `github.com/tree-sitter/tree-sitter-c` | `function_definition`, `struct_specifier`, `enum_specifier`, `declaration` |
| C++ | `github.com/tree-sitter/tree-sitter-cpp` | 同 C + `class_specifier`, `type_definition` |
| Go | `github.com/tree-sitter/tree-sitter-go` | `function_declaration`, `method_declaration`, `type_declaration` |
| Java | `github.com/tree-sitter/tree-sitter-java` | `class_declaration`, `method_declaration` (walk into `class_body`) |
| Python | `github.com/tree-sitter/tree-sitter-python` | `function_definition`, `class_definition` (递归 walk 提取方法) |

JavaScript/TypeScript **始终使用正则解析器**（`parser_javascript.go`），不经过 Tree-sitter（JS 语法未编译进二进制）。

### index.json 数据结构 (AnalysisContext)

```json
{
  "path": "./src",
  "files": ["src/main.c", ...],
  "symbols": {
    "functions": [{"name": "handle_request", "file": "...", "start_line": 42, "end_line": 98}],
    "variables": [{"name": "g_conn_pool", "file": "...", "line": 15}],
    "types": [{"name": "RequestCtx", "kind": "struct", "file": "...", "start_line": 7}]
  },
  "call_graph": {
    "edges": [{"caller": "main", "callee": "handle_request", "file": "...", "line": 120}]
  },
  "alloc_free": {
    "pairs": [{"alloc_func": "malloc", "alloc_file": "...", "alloc_line": 88, "free_sites": [...]}]
  },
  "lock_graph": {
    "mutexes": [{"mutex_name": "", "lock_line": 45, "unlock_line": 67, "file": "..."}]
  }
}
```

### 当前索引器能力边界

| 能力 | 状态 | 说明 |
|------|------|------|
| Tree-sitter AST 解析 | ✅ 5 语言 | C/C++/Go/Java/Python 用真实 AST，JS 用正则 |
| 符号表 (函数/变量/类型) | ✅ | 名称 + 文件 + 行号，无类型层次结构 |
| 调用图 | ✅ 文本近似 | 字符串匹配 `callee_name(`，非 AST 推导，已过滤注释 |
| Alloc/Free 配对 | ✅ 文本近似 | 同文件内匹配 `malloc`/`free`，不跨文件追踪 |
| 锁使用记录 | ✅ 文本扫描 | 仅记录 mutex lock/unlock 行号，不构建锁序图 |
| **控制流图 (CFG)** | ❌ | 未构建，无可达性分析 |
| **数据流图 (DFG)** | ❌ | 无 Source → Sink 追踪，无污点传播 |
| **SSA/IR** | ❌ | 无中间表示，无约束求解能力 |
| **类型继承/接口实现** | ❌ | 仅记录类型名，不构建类型层次 |
| **精确作用域分析** | ❌ | 不区分全局/局部/块级变量 |

### parser_ts.go nil 守卫约定

Tree-sitter partial parse 时 `node.Child(i)` 即使 `i < node.ChildCount()` 也可能返回 nil。**每个 `node.Child(i)` 调用后必须 nil 检查**，否则调用 `.Kind()` 会 panic。

```go
child := node.Child(i)
if child == nil {
    continue
}
kind := child.Kind()
```

## Go 索引器 (仅有的原生代码)

## Skill 与 Knowledge 组织结构

| 源码 | 部署后 (Gemini CLI) |
|------|-------------------|
| `skills/secguard/cpp/SKILL.md` | `.gemini/extensions/secguardian/skills/` |
| `knowledge/guard-rules/*.md` | `.gemini/extensions/secguardian/knowledge/guard-rules/` |
| `knowledge/protocols/scan-output.md` | `.gemini/extensions/secguardian/knowledge/protocols/` |

## Manifest-Driven Tokens（散弹式修改终结者）

修改 detector 数量时，只需改 `manifest.json`。构建时 `scripts/sync-manifest.sh` 自动更新所有文件中的 `NNN<!-- @secguardian:xxx -->` 标记。
CI 验证：`bash scripts/sync-manifest.sh --check`（已集成到 self-check.sh §7.6）。
