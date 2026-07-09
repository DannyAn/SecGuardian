# AGENTS.md — SecGuardian 运维须知 (规范来源)

> ⚠️ **本文件是全部 AI Agent（Claude Code / OpenCode / Gemini CLI）的规范来源。**
>
> - `CLAUDE.md` 和 `GEMINI.md` 是薄引用层，只包含平台特有的注册和用法信息
> - **架构/SDD/构建/部署/验证/发布 等共享内容，以本文件为准**
> - 修改任何共享内容 → 改本文件 → 无需同步其他两文件（它们只是引用本文件）

## 项目解剖

```
secguardian/                # v0.19.0, Go 1.25.3, parser + indexer 有 go test 覆盖
│
├── internal/               # ★ 唯一原生代码: Go 索引器 → 产出 secguardian-index 二进制
│   ├── parser/             #   双解析器: parser_ts.go(cgo) + parser_re.go(!cgo), 编译期二选一
│   ├── indexer/            #   符号表/调用图/alloc-free配对/锁图 + prescreener
│   ├── context/            #   共享数据模型 AnalysisContext
│   └── main.go             #   入口: --path, --output, --health, --version
│
├── commands/               # 4 个 slash command × 3 平台
│   ├── opencode/           #   OpenCode 平台: secguard/secaudit/secreview/secfix
│   ├── claude/             #   Claude Code 平台: 同上
│   └── gemini/             #   Gemini CLI 平台: 同上 (TOML 格式)
│
├── skills/                 # AI Agent 的扫描说明书 (Markdown)
│   ├── secguard/           #   60 个 API 级检测器 (cpp 15 / java 10 / python 11 / go 10 / js 13)
│   │   ├── cpp/            #     15 rules: buffer_overflow, null_dereference, ...
│   │   ├── java/           #     10 rules: command_injection, deserialization, ...
│   │   ├── python/         #     11 rules: code_injection, sql_injection, ...
│   │   ├── go/             #     10 rules: command_injection, cgo_memory, ...
│   │   ├── js/             #     13 rules: prototype_pollution, ssrf, ...
│   │   └── *各语言含 SKILL.md + references/ + rules/{detector}/rule.md
│   ├── secaudit/           #   13 个审计域规则 (OWASP ASVS 映射)
│   │   ├── SKILL.md
│   │   └── rules/          #     input-validation.md, cryptography.md, ...
│   └── secreview/          #   5 语言 code review 规则
│       ├── cpp/, java/, python/, go/, js/
│       └── *各语言含 SKILL.md + rules/{lang}.md + references/
│
├── knowledge/              # 可复用知识库 (全部 Markdown)
│   ├── protocols/          #   扫描输出协议 (scan-output.md, sarif-output.md, verification-protocol.md)
│   ├── standards/          #   SEI CERT C/C++/Java + OWASP Cheat Sheet 映射
│   └── threat-catalog.md   #   威胁目录索引
│
├── examples/               # 故意含漏洞的测试代码
│   ├── cpp-vuln-demo/      #   生产规模 C/C++ 含漏洞示例
│   ├── java-vuln-demo/     #   Java/Spring 漏洞示例
│   ├── python-vuln-demo/   #   Python Web 漏洞示例
│   ├── go-vuln-demo/       #   Go 漏洞示例
│   ├── js-vuln-demo/       #   JS/Node 漏洞示例
│   └── *no-answers 变体: 剥离了答案标注的干净版本
│
├── scripts/                # 构建/部署/验证 脚本
│   ├── deploy.sh all        #   ★ 日常唯一入口
│   ├── dev-verify.sh       #   25 项部署健康检查
│   ├── self-check.sh       #   L1 设计一致性验证
│   ├── e2e-verify.sh       #   L4/L5 端到端验证
│   ├── package.sh          #   跨平台编译 + 组装 extension 包 → dist/
│   ├── deploy.sh           #   部署 dist/ → 三平台插件目录
│   ├── secguardian-index   #   索引器 shell wrapper
│   ├── init-scan.sh        #   扫描初始化 (自动发现 + 健康检查 + 建目录)
│   ├── record-finding.py   #   finding 录制器
│   ├── render-report.py    #   报告渲染器
│   ├── validate-index.py   #   索引验证器
│   ├── validate-findings.py #   finding 校验器
│   └── bin/                #   5 平台预编译二进制
│
├── docs/                   # 架构文档 + SDD 决策记录
│   ├── sdd/                 #   Spec-Driven Development 完整体系
│   │   ├── README.md        #   方法论总纲
│   │   ├── brainstorm-log.md#   Brainstorm 决策日志
│   │   └── epics/           #   Epic 到 Task 的完整闭环
│   ├── LLM-Investigation-Architecture-Guide.md  # 本回合架构指导
│   └── ...                  # 其他架构/设计文档
│
├── extensions/             # 每个产品的 extension.json 清单
├── dist/                   # 构建输出 → 被 deploy.sh 部署
├── manifest.json           # 项目注册表: 版本/产品/技能/检测器/覆盖率
├── AGENTS.md               # ★ 规范来源 (本文件)
├── CLAUDE.md               # 薄引用层 (平台特有注册/命名空间)
├── GEMINI.md               # 薄引用层 (平台特有命令用法)
└── .codeagent/             # 扫描输出归档: secguard/scans/<scan-id>/
```

> **核心认知**: 这不是传统 SAST。只有 Go 索引器是编译代码，其余全部是 Markdown 知识文件，由 AI Agent 在扫描时动态加载。
> - **检测器**不在 `knowledge/`，在 `skills/secguard/{lang}/rules/{detector}/rule.md`
> - **语言画像**不在 `knowledge/`，在 `skills/secguard/{lang}/references/language-features.md`
> - 修改任何 `.md` → `deploy.sh all` → AI 重启即可生效。

> **核心认知**: 这不是传统 SAST。只有 Go 索引器是编译代码，其余全部是 Markdown 知识文件，由 AI Agent 在扫描时动态加载。修改任何 `.md` → `deploy.sh all` → AI 重启即可生效。

## 开发守则第一条：SDD 规格驱动开发

> ⚠️ **禁止收到开发需求后直接编码**。SecGuardian 采用 Spec-Driven Development (SDD) 方法论。**日常开发不只是跑 `deploy.sh all`**——在跑部署命令之前，必须先走 SDD 流程。

### SDD 七环流程

```
🧠 Brainstorm → 📋 Spec → 📝 ADR → 📐 Plan → 🔨 Task → 📊 Progress → 🔄 Change
```

| # | 环节 | 产出物（Feature Package 内） | 回答的问题 |
|---|------|---------------------------|-----------|
| 1 | 🧠 Brainstorm | `docs/sdd/brainstorm-log.md` | 为什么做？考虑过哪些方案？否决了哪些？ |
| 2 | 📋 Spec | `FEATURE-XXX/spec.md` | 做什么？做到什么程度？ |
| 3 | 📝 ADR | `FEATURE-XXX/adr.md` | 关键架构决策是什么？为什么不用方案 B？ |
| 4 | 📐 Plan | `FEATURE-XXX/plan.md` | 怎么实现？改哪些文件？分几步？ |
| 5 | 🔨 Task | `FEATURE-XXX/tasks/TASK-NNN.md` | 这一步具体怎么做？验证命令是什么？ |
| 6 | 📊 Progress | `FEATURE-XXX/progress.md` | 做到哪了？被什么阻塞了？下一步？ |
| 7 | 🔄 Change | `FEATURE-XXX/changes/CHANGE-NNN.md` | 需求发生了什么变化？为什么和最初设计不同？ |

### AI Agent / 工程师操作守则

1. **收到开发需求 → 先打开** [`docs/sdd/README.md`](docs/sdd/README.md)
2. **检查** [`docs/sdd/epics/`](docs/sdd/epics/) 是否已有对应 Feature Package
3. **有 Feature Package → 加载 spec/adr/plan → 执行 Task → 更新 progress**
4. **无 Feature Package → 先建完整闭环（Brainstorm → Spec → ADR → Plan），再编码**
5. **七环顺序不可跳过**：不能没有 Spec 就写 Plan，不能没有 ADR 就开始编码
6. **一个 Task 一次 commit**，粒度细到可独立验证

### 跳过 SDD 的例外

- 拼写/格式修复
- 单行 bug fix（非设计变更）
- 过期注释/文档更新

凡涉及新增功能、变更行为、修改架构，**必须先建 Feature Package**。

> 完整方法论见 [`docs/sdd/README.md`](docs/sdd/README.md)

## 构建与部署

> **日常开发只需要记一条**: `bash scripts/deploy.sh all` — 改了什么文件都这个命令重建 + 部署。

| 你做了什么 | 执行命令 | 耗时 |
|-----------|---------|------|
| 修改 skills/knowledge/commands | `bash scripts/deploy.sh all` | ~30s |
| 修改 internal/ (Go 索引器) | `bash scripts/deploy.sh all --verify` | ~35s (含冒烟) |
| 怀疑部署状态异常 | `bash scripts/dev-verify.sh` | ~5s |
| 彻底清理重来 | `bash scripts/deploy.sh all --uninstall --verify` | ~60s (含验证) |

```bash
bash scripts/deploy.sh all --uninstall                   # 卸载部署（保留 .codeagent/ 扫描）
bash scripts/deploy.sh all --uninstall --clean-scans    # 完全抹除
```

内部步骤（一般不需要单独调）:
```bash
bash scripts/package.sh           # 仅构建 dist/
bash scripts/deploy.sh all        # 仅部署（前置: dist/ 已存在）
```

**部署目标 (实际路径，并非 CLAUDE.md 中描述的 extensions/)**:
- Claude Code → `.claude/plugins/secguardian/`
- OpenCode   → `.opencode/plugins/secguardian/`
- Gemini CLI → `.gemini/extensions/secguardian/`

部署后每个平台的 `scripts/bin/` 下有 `secguardian-index-{os}-{arch}` 二进制，`scripts/` 下有 wrapper 脚本（shell + PowerShell）。

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

**CLI 接口:**

```bash
secguardian-index --path ./src --output .codeagent/secguardian/index.json   # 完整索引
secguardian-index --health                                       # 冒烟测试
secguardian-index --version                                      # 打印版本号
secguardian-index --lang cpp --path ./src                        # 语言过滤
```

### 双解析器架构 (编译期二选一)

| 解析器 | 文件 | Build Tag | 解析方式 | 平台 |
|--------|------|-----------|---------|------|
| Tree-sitter | `parser_ts.go` | `cgo` | Tree-sitter CGO 绑定，真实 AST | 仅 darwin-arm64 原生构建 |
| Regex Fallback | `parser_re.go` | `!cgo` | 纯 Go 正则近似匹配 | 所有跨平台构建 |

两个文件定义完全相同的类型（`ParseResult`, `FunctionInfo`, `VariableInfo`, `TypeInfo`），Go build tag 在编译期二选一，对外接口一致。

**package.sh 构建策略**:
- 本地平台: `go build`（CGO 启用，tree-sitter 解析器）
- 跨平台 (linux/windows/amd64): `CGO_ENABLED=0 go build`（纯 Go regex 回退）

### Tree-sitter 语法覆盖 (5 语言 + JS 正则)

`parser_ts.go` 通过 CGO 链接以下 Tree-sitter 语法库：

| 语言 | Tree-sitter 包 | AST 节点识别 |
|------|---------------|-------------|
| C | `github.com/tree-sitter/tree-sitter-c` | `function_definition`, `struct_specifier`, `enum_specifier`, `declaration` |
| C++ | `github.com/tree-sitter/tree-sitter-cpp` | 同 C + `class_specifier`, `type_definition` |
| Go | `github.com/tree-sitter/tree-sitter-go` | `function_declaration`, `method_declaration`, `type_declaration` |
| Java | `github.com/tree-sitter/tree-sitter-java` | `class_declaration`, `method_declaration` (walk into `class_body`) |
| Python | `github.com/tree-sitter/tree-sitter-python` | `function_definition`, `class_definition` (递归 walk 提取方法) |

JavaScript/TypeScript **始终使用正则解析器**（`parser_javascript.go`），不经过 Tree-sitter（JS 语法未编译进二进制，在 `parser_ts.go:37` 中显式 fallback）。

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

Tree-sitter partial parse 时 `node.Child(i)` 即使 `i < node.ChildCount()` 也可能返回 nil。**每个 `node.Child(i)` 调用后必须 nil 检查**，否则调用 `.Kind()` 会 panic。参照 `safeText` 已有的边界检查形式。

```go
child := node.Child(i)
if child == nil {
    continue
}
kind := child.Kind()
```

**二元性检查点**: 修改 `parser_ts.go` 后必须重建本地平台**和**跨平台路径，确保两个 parser 的逻辑等价。`package.sh` 会并行构建全部平台。

## 扫描执行与输出

`/secguard` 命令的执行流:
1. `secguardian-index --health` → HEALTH:OK/WARN
2. `secguardian-index --path <path> --output .codeagent/.../index.json`
3. AI Agent 读取 `index.json` → 加载 `skills/secguard/<lang>/SKILL.md` → 按 detector 执行
4. 输出到 `.codeagent/secguardian/secguard/scans/scans/<scan-id>/`

输出协议 v5.0 在 `knowledge/protocols/scan-output.md`（CLAUDE.md 中写的是 1.0，已过时）。

## Skill 源码 vs 部署位置

| 源码 | 部署后 (OpenCode) |
|------|------------------|
| `skills/secguard/cpp/SKILL.md` | `.opencode/plugins/secguardian/skills/` |
| `knowledge/guard-rules/*.md` | `.opencode/plugins/secguardian/knowledge/guard-rules/` |
| `knowledge/protocols/scan-output.md` | `.opencode/plugins/secguardian/knowledge/protocols/` |

Skill 加载路径歧义: 系统提示中写的是 `.opencode/skills/secguardian/`，但部署到 `.opencode/plugins/secguardian/`。如果 skill 加载 404，检查部署目标。

## 验证流程 (Verification)

对项目做任何修改后，**必须**按以下顺序运行验证，确保没有破坏已有功能。

| 层次 | 命令 | 覆盖范围 | 耗时 | 何时运行 |
|------|------|---------|------|---------|
| **L1 设计一致性** | `bash scripts/self-check.sh` | detector ↔ index ↔ manifest 交叉校验、stale references、Go 编译 | ~5s | 每次 commit 前 |
| **L2 结构完整性** | `bash scripts/ci-check.sh` | JSON 格式、版本一致性、skill 目录完整性、Go 编译+冒烟 | ~15s | push 前 |
| **L3 部署环境** | `bash scripts/dev-verify.sh` | 二进制文件、indexer health、平台部署结构、扫描输出 | ~10s | 部署后 |
| **L4/L5 端到端** | `bash scripts/e2e-verify.sh` | findings schema 合规、渲染器 6 文件生成、SARIF 2.1.0 结构、4-segment 质量门禁、安全评分计算、CI 门禁 exit code、delta 增量对比、3 命令类型、5 语言索引器、**L5 构建→包→执行管线** | ~20s | 修改架构层代码后 (**必须**) |
| **L5 全量** | 以上全部按顺序 | 全覆盖 | ~45s | 发布前 |

### 快速验证 (日常)

```bash
# 日常修改 (skills/knowledge/commands) — 只跑 L1
bash scripts/self-check.sh

# 修改了 deploy.sh 或 extension 结构 — L1 + L2
bash scripts/self-check.sh && bash scripts/ci-check.sh

# 修改了 render-report.py 或 findings-schema.json — L1 + L4
bash scripts/self-check.sh && bash scripts/e2e-verify.sh

# 修改了 internal/ (Go 索引器) — L1 + L2 + L3 + L4
bash scripts/self-check.sh && bash scripts/ci-check.sh && bash scripts/dev-verify.sh && bash scripts/e2e-verify.sh
```

### CI 模式 (非零退出码)

```bash
bash scripts/e2e-verify.sh --ci   # 失败时 exit 1，适合 CI pipeline
bash scripts/e2e-verify.sh --quick  # 跳过第 9 节 (多语言索引)，快速反馈
```

### E2E 验证覆盖矩阵

| # | 验证项 | 验证什么 | 失败意味着 |
|---|--------|---------|-----------|
| 1 | Findings Schema | JSON 结构、required 字段、ID pattern | AI 输出的 findings.json 可能无效 |
| 2 | Renderer 基础 | 6 文件生成、单格式、空 findings | 渲染器核心功能损坏 |
| 3 | SARIF 2.1.0 | version/driver/rules/results/fingerprints/fixes | CI/CD 集成失效 |
| 4 | 4-Segment 质量门禁 | 完整/不完整 finding 的差异处理 | secaudit Step 4b 质量检查不可靠 |
| 5 | 安全评分 | 100 - 25×Crit - 10×High - 3×Med 公式 | summary.json 和 status.json 评分错误 |
| 6 | CI 门禁 | Critical → FAILED+exit 1; Clean → PASSED+exit 0 | CI pipeline 门禁失效 |
| 7 | Delta 对比 | new/fixed/still_open 计数 vs 上次扫描 | 趋势分析错误 |
| 8 | 命令类型 | secguard/secaudit/secreview 分别生成正确标题 | 报告类型混淆 |
| 9 | 多语言 | 5 语言示例仓库 indexer 解析通过 | 索引器对某语言失效 |
| 10 | 渲染器性能 | < 5s 完成 1 个 finding 的渲染 | 性能退化 |
| 11 | L5 构建→包→执行 | package.sh 编译 + dist 结构 + indexer 扫描 | 构建/部署管线损坏 |

## 版本发布流程

> **改版说明 (2026-07-07):** 原来是 3 个发布脚本（`release.sh`, `github-release.sh`, `gitee-release.sh`），现统一为单入口。`github-release.sh` 已删除。

唯一入口 `scripts/release.sh`，不需要多脚本、不需要临时补丁：

```bash
bash scripts/release.sh v0.15.0               # 构建 + GitHub (默认)
bash scripts/release.sh v0.15.0 --gitee        # 构建 + GitHub + Gitee 双发
bash scripts/release.sh v0.15.0 --only-gitee   # 构建 + 仅 Gitee
bash scripts/release.sh --help                 # 查看完整帮助
```

设计原则：
1. **单入口** — 所有发布走 `release.sh`，不拆分、不包装
2. **构建在前** — 发布前必重新构建，不信任旧产物
3. **先快后慢** — 先做轻量检查（gh CLI / tag / 重复发布）再构建，失败不浪费构建时间

Gitee 发布（`scripts/gitee-release.sh`）保留了独立调用能力，但正常应通过 `release.sh --gitee` 间接使用。

### 前置条件

- `gh` CLI 已登录（`gh auth status`）— GitHub 发布需要
- `GITEE_TOKEN` 环境变量已设置 — Gitee 发布需要
- Git tag `v0.x.y` 已存在（`git tag v0.x.y && git push origin v0.x.y`）

### 产物

`dist/release/secguardian-<ver>.tar.gz`（顶层 bundle，含 install.sh + uninstall.sh + README.md）
`dist/release/secguardian-<ver>-<platform>.tar.gz`（5 平台内包）
`dist/release/SHA256SUMS`

AI Agent 注意：收到"发布版本"请求时，直接执行 `bash scripts/release.sh vX.Y.Z`，不要重新阅读脚本代码理解流程。需要 Gitee 就加 `--gitee`。

## 注意事项

- `git diff` 中 `HEAD~1` 和 `HEAD~1 --name-only` 的行为不同，增量扫描时注意解析
- `scripts/secguardian-index` wrapper 查找顺序: canonical name → 平台匹配 → dev fallback，任一找不到就 `exit 1`
- 扫描后必须创建 `latest → <scan-id>/` 符号链接供 delta.json 增量对比
- `internal/` 下有 `go test ./...` 可运行单元测试，`health` 子命令用于冒烟测试
- `CLAUDE.md` 中部署路径描述与实际不一致，以 `deploy.sh` 源码为准
- `scripts/` 下的 `secguardian-index` 是源码文件（git 跟踪），卸载操作不应删除它
- AI Agent 进入项目后应该 **先跑 `bash scripts/self-check.sh`** 确认环境完整性，再开始工作

### Codex 工作守则（2026-07-04 定稿）

> 以下守则基于项目历史教训总结，Codex 每次执行开发任务必须遵守。

#### 原则：不临时起意，不丢三落四

1. **查设计再动手** — 任何改动前先查 SDD 是否有相关 Feature/CHANGE/ADR。有则沿用，无则建档。
2. **改完先展示** — 代码改完后不提交，先给用户看 diff，确认后再继续。
3. **改完必须验证** — 至少跑 `bash scripts/self-check.sh` + 受影响功能的手动测试。不验证不提交。
4. **部署全链路检查** — 新增脚本/文件时，检查 `package.sh` 和 `deploy.sh` 是否覆盖，确认部署包完整。
5. **不堆commit** — 一次改动一个 commit，粒度小到可独立回退。
6. **不跳过 SDD** — Bug fix 和拼写修正可直接改。涉及架构、行为、新功能，必须先走 SDD。

#### 每次 commit 前自检清单

```
□ 查过 SDD 了？（无冲突设计 / 有记录可循）
□ diff 给用户看了？（用户确认过）
□ self-check 跑过了？（120 checks 全绿）
□ 受影响功能测过了？（索引构建 / 扫描输出 / 缓存命中）
□ 部署检查了？（package.sh 覆盖 / deploy.sh 覆盖）
□ 提交说明清晰了？（原因 + 改了啥 + 验证结果）
```

## Manifest-Driven Tokens（散弹式修改终结者）

修改 detector 数量时，只需改 `manifest.json`。构建时 `scripts/sync-manifest.sh` 自动更新所有文件中的 `NNN<!-- @secguardian:xxx -->` 标记。
CI 验证：`bash scripts/sync-manifest.sh --check`（已集成到 self-check.sh §7.6）。

### GitHub Token

 存储在 macOS 钥匙串中，读取方式同 Gitee token：

 ```bash
 # 首次设置
 security add-generic-password -a "DannyAn" -s "github-token" -w "your-token-here"

 # AI Agent 读取
 TOKEN=$(security find-generic-password -a "DannyAn" -s "github-token" -w)

 # 使用示例：创建 PR
 curl -s -X POST \
   -H "Authorization: Bearer $TOKEN" \
   -H "Accept: application/vnd.github.v3+json" \
   https://api.github.com/repos/DannyAn/SecGuardian/pulls \
   -d '{"title":"...", "head":"branch-name", "base":"develop", "body":"..."}'

 # 使用完毕立即清除
 unset TOKEN
 ```

 GitHub API 常用操作：

 - **创建 PR**: `POST /repos/DannyAn/SecGuardian/pulls`
 - **改默认分支**: `PATCH /repos/DannyAn/SecGuardian` with `{"default_branch":"master"}`
 - **获取 check runs**: `GET /repos/DannyAn/SecGuardian/commits/{sha}/check-runs`
 - **获取 annotations**: `GET /repos/DannyAn/SecGuardian/check-runs/{id}/annotations`
