# AGENTS.md — SecGuardian 运维须知

## 项目解剖

```
secguardian/                # v0.5.3, Go 1.25.3, 无传统测试套件
│
├── internal/               # ★ 唯一原生代码: Go 索引器 → 产出 secguardian-index 二进制
│   ├── parser/             #   双解析器: parser_ts.go(cgo) + parser_re.go(!cgo), 编译期二选一
│   ├── indexer/            #   符号表/调用图/alloc-free配对/锁图 构建
│   ├── context/            #   共享数据模型 AnalysisContext
│   └── main.go             #   入口: --path, --output, --health, --version
│
├── commands/               # 3 个 slash command 定义: secguard.md, secaudit.md, secreview.md
│
├── skills/                 # AI Agent 的扫描说明书 (Markdown, 由 agent 在扫描时加载)
│   ├── secguard/            #   /secguard 命令 → cpp/go/java/python/js 各有 SKILL.md
│   ├── secaudit/            #   /secaudit 命令 → 17 个审计 skill
│   └── secreview/           #   /secreview 命令 → 5 语言检视
│
├── knowledge/              # 可复用知识库 (全部 Markdown)
│   ├── detectors/          #   60 个检测规则 (自包含: 定义→检测→修复→白名单)
│   ├── languages/          #   5 语言画像 (cpp/go/java/python/js)
│   ├── protocols/          #   输出协议 v2.0: report.md + results.sarif + summary.json
│   ├── standards/          #   SEI CERT C/C++/Java + OWASP Cheat Sheet 映射
│   └── threat-catalog.md   #   威胁目录索引
│
├── examples/               # 故意含漏洞的测试代码 (cpp-vuln-demo, python-vuln-demo, java-vuln-demo)
│
├── scripts/                # 构建/部署/验证 脚本
│   ├── dev-deploy.sh       #   ★ 日常唯一入口
│   ├── dev-verify.sh       #   25 项部署健康检查
│   ├── package.sh          #   跨平台编译 + 组装 extension 包 → dist/
│   ├── deploy.sh           #   部署 dist/ → 三平台插件目录
│   ├── secguardian-index   #   索引器 shell wrapper (查找 bin/ 下匹配平台的二进制)
│   └── bin/                #   5 平台预编译二进制
│
├── extensions/             # 每个产品的 extension.json 清单 (skills/languages/detectors 声明)
├── dist/                   # 构建输出 → 被 deploy.sh 部署
├── manifest.json           # 项目注册表: 版本/产品/技能/检测器/覆盖率
├── CLAUDE.md               # 遗留指引 (部分过时，以本文件和 deploy.sh 源码为准)
└── .codeagent/             # 扫描输出归档: secguard-secguardian/scans/<scan-id>/
```

> **核心认知**: 这不是传统 SAST。只有 Go 索引器是编译代码，其余全部是 Markdown 知识文件，由 AI Agent 在扫描时动态加载。修改任何 `.md` → `dev-deploy.sh` → AI 重启即可生效。

## 构建与部署

> **日常开发只需要记一条**: `bash scripts/dev-deploy.sh` — 改了什么文件都这个命令重建 + 部署。

| 你做了什么 | 执行命令 | 耗时 |
|-----------|---------|------|
| 修改 skills/knowledge/commands | `bash scripts/dev-deploy.sh` | ~30s |
| 修改 internal/ (Go 索引器) | `bash scripts/dev-deploy.sh --verify` | ~35s (含冒烟) |
| 怀疑部署状态异常 | `bash scripts/dev-verify.sh` | ~5s |
| 彻底清理重来 | `bash scripts/dev-deploy.sh --reset` | ~60s (含验证) |

```bash
bash scripts/dev-deploy.sh --uninstall                   # 卸载部署（保留 .codeagent/ 扫描）
bash scripts/dev-deploy.sh --uninstall --clean-scans    # 完全抹除
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

## Go 索引器 (仅有的原生代码)

`internal/` 是 Go module (`go 1.25.3`)，产出唯一的原生二进制 `secguardian-index`。

**双解析器架构**:
- `internal/parser/parser_ts.go` — **build tag: `cgo`**，使用 tree-sitter (CGO)
- `internal/parser/parser_re.go` — **build tag: `!cgo`**，纯 Go 正则回退

两个文件定义了**完全相同的类型** (`ParseResult`, `FunctionInfo`, `VariableInfo`, `TypeInfo`)——无共享类型文件，靠 Go 的 build tag 在编译期选择。

**package.sh 构建策略**:
- 本地平台: `go build`（CGO 启用，tree-sitter 解析器）
- 跨平台 (linux/windows/amd64): `CGO_ENABLED=0 go build`（纯 Go regex 回退）

**二元性检查点**: 修改 `parser_ts.go` 后必须重建本地平台**和**跨平台路径，确保两个 parser 的逻辑等价。`package.sh` 会并行构建全部平台。

## parser_ts.go nil 守卫约定

`node.Child(i)` 即使 `i < node.ChildCount()` 也可能返回 nil（tree-sitter partial parse）。**每个 `node.Child(i)` 调用后必须 nil 检查**，否则调用 `.Kind()` 会 panic。参照 `safeText` 已有的边界检查形式。

```go
child := node.Child(i)
if child == nil {
    continue
}
kind := child.Kind()
```

## 扫描执行与输出

`/secguard` 命令的执行流:
1. `secguardian-index --health` → HEALTH:OK/WARN
2. `secguardian-index --path <path> --output .codeagent/.../index.json`
3. AI Agent 读取 `index.json` → 加载 `skills/secguard/<lang>/SKILL.md` → 按 detector 执行
4. 输出到 `.codeagent/secguard-secguardian/scans/<scan-id>/`

输出协议 v2.0 在 `knowledge/protocols/scan-output.md`（CLAUDE.md 中写的是 1.0，已过时）。

## Skill 源码 vs 部署位置

| 源码 | 部署后 (OpenCode) |
|------|------------------|
| `skills/secguard/cpp/SKILL.md` | `.opencode/plugins/secguardian/skills/` |
| `knowledge/detectors/*.md` | `.opencode/plugins/secguardian/knowledge/detectors/` |
| `knowledge/protocols/scan-output.md` | `.opencode/plugins/secguardian/knowledge/protocols/` |

Skill 加载路径歧义: 系统提示中写的是 `.opencode/skills/secguardian/`，但部署到 `.opencode/plugins/secguardian/`。如果 skill 加载 404，检查部署目标。

## 注意事项

- `git diff` 中 `HEAD~1` 和 `HEAD~1 --name-only` 的行为不同，增量扫描时注意解析
- `scripts/secguardian-index` wrapper 查找顺序: canonical name → 平台匹配 → dev fallback，任一找不到就 `exit 1`
- 扫描后必须创建 `latest → <scan-id>/` 符号链接供 delta.json 增量对比
- `internal/` 下没有 `go test`，只有一个 `health` 子命令用于冒烟测试
- `CLAUDE.md` 中部署路径描述与实际不一致，以 `deploy.sh` 源码为准
- `scripts/` 下的 `secguardian-index` 是源码文件（git 跟踪），卸载操作不应删除它
