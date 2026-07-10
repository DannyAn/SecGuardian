# Plan — FEATURE-002: Tree-sitter Primary + CFG Construction

> **隶属**: EPIC-011 / FEATURE-002
> **目标**: tree-sitter 全平台唯一解析器 + CFG 构建，奠定引擎 recall 基线

---

## Goal
让 tree-sitter 在所有平台成为唯一解析器（打败 AST），构建 CFG 提供可达性/必经性事实，填充 S3 接通 prescreener。

## Architecture
见 spec §4。新增 `internal/indexer/cfg.go`（CFG 构建 + 查询）；改 `package.sh`（zig cc 交叉编译）；删 `parser_re.go`；扩展 `AnalysisContext` 加 `cfg` 字段。

## File Structure
| 文件 | 改动 | 量 |
|------|------|----|
| `internal/indexer/cfg.go` | 新增（CFG 构建 + IsReachable/Dominates）| 大 |
| `internal/indexer/cfg_test.go` | 新增 | 中 |
| `internal/parser/parser_ts.go` | 移除 `//go:build cgo` tag；填充 S3 Declarations | 中 |
| `internal/parser/parser_re.go` | **删除** | — |
| `internal/parser/parser_re_test.go` | 删除/迁移 | 小 |
| `internal/context/context.go` | `AnalysisContext` 加 `cfg` 字段 | 小 |
| `internal/indexer/prescreener.go` | 验证接通（S3 填充后）| 小 |
| `internal/main.go` | index 输出含 cfg | 小 |
| `scripts/package.sh` | zig cc 交叉编译 | 中 |
| `Dockerfile` / CI | 安装 zig | 小 |
| `internal/go.mod` | 移除 `mattn/go-pointer` | 小 |

## Tasks（按执行顺序，每 Task 一次 commit）

### TG-E: CFG 构建（不依赖 zig，先落地新能力）
- [ ] **TASK-014** `AnalysisContext` 加 `cfg` 字段 + 序列化结构（spec §4.2）。验证：context_test.go 编译
- [ ] **TASK-015** `cfg.go` 基本块 + 控制边构建骨架（if/for/while/return/break/continue），语言适配层映射 tree-sitter kind。验证：cfg_test.go 对 C/Go fixture 产出预期 BB/边
- [ ] **TASK-016** `IsReachable` + `Dominates`（迭代支配树）查询 API。验证：单测覆盖可达/不可达、支配/不支配
- [ ] **TASK-017** 扩展控制节点（switch/case/try/catch/throw/goto）+ `cfg_incomplete` 标记。验证：Java try/catch、C switch fixture
- [ ] **TASK-018** CFG 接入 `main.go` 索引管线，写入 index.json。验证：5 语言 example 索引含 cfg

### TG-F: S3 Declarations + prescreener（F6）
- [ ] **TASK-019** `parser_ts.go` 填充 `Declarations`（C/C++/Go/Java/Python 声明节点）。验证：`TestDeclarationExtraction` 转绿
- [ ] **TASK-020** prescreener 接通验证：`SafeCount > 0`，safe-variant（strcpy_s 等）被过滤。验证：prescreener_test.go + example 实测

### TG-G: tree-sitter 全平台唯一解析器（F5，依赖 zig）
- [ ] **TASK-021** 本地 `brew install zig`，`package.sh` 改 zig cc 交叉编译 linux/windows/arm64 `CGO_ENABLED=1`。验证：linux 二进制在 docker 跑通，index.json 与 darwin 等价
- [ ] **TASK-022** 删 `parser_re.go` + `parser_re_test.go`，移除 `parser_ts.go` 的 `//go:build cgo` tag，清理 `mattn/go-pointer`。验证：`CGO_ENABLED=0 go build ./...` 仍用 tree-sitter（因 zig 提供 C）；双解析器测试合并为单解析器回归测试
- [ ] **TASK-023** Dockerfile/CI 安装 zig。验证：CI 全平台构建绿
- [ ] **TASK-024** 等价性守卫：fixture 语料在 darwin/linux/windows 产出 diff 为空。验证：跨平台 index.json 对比脚本

## Verification
- 每个 TASK：`cd internal && go test ./...` 必绿
- TG-E 完成后：CFG 单测覆盖 if/for/switch/try + 支配树
- TG-G 完成后：`bash scripts/e2e-verify.sh` 5 语言索引含 cfg；跨平台 index.json 等价
- 全部完成：L1-L5 全跑，`SafeCount > 0`，CFG 可达性查询可用

## Dependencies
- TG-G 依赖 zig 安装（TASK-021）；zig 不可用时 TG-E/TG-F 仍可独立推进（CFG/S3 不依赖跨平台）
- TASK-018 的 CFG 消费方是 FEATURE-003（Q-matrix 用 Dominates 校验 Q3）与 FEATURE-001 gate（可校验缓解存在）
- 与 FEATURE-001 正交：CFG 落地后 gate 可用 CFG 事实，但 gate 不阻塞 CFG
