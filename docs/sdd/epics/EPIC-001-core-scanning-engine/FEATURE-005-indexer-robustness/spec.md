# FEATURE-005: Indexer Robustness

> **Epic**: EPIC-001 (Core Scanning Engine)
> **状态**: 📋 Spec 编写中
> **周期**: 2026-06-27 ~ TBD

## 问题陈述

2026-06-27 对 Java Spring Boot 项目执行 `/secguard ./src java` 扫描时，串联暴露了索引器（secguardian-index）的 4 个系统性可靠性缺陷：

| # | 缺陷 | 会话症状 | 根因层级 |
|---|------|---------|---------|
| 1 | `--lang` 参数未在 SKILL.md Step 2 传递 | 索引器按 auto 模式解析了 43 个 JS minified bundle（7067 函数，其中 4418 来自单个文件），两次超时（120s+300s） | 流程指令 (SKILL.md) |
| 2 | JS minified bundle 解析无上限 | `chunk-libs.dc48dc82.js`（4418 函数）正则解析，索引器卡死 | 代码 (parser_javascript.go) |
| 3 | auto 模式路径排除不全 | 未排除 `target/`、`build/`、`static/`、`public/`、`resources/static/` | 代码 (main.go) |
| 4 | index.json 缺乏预计算统计字段 | AI 手写 Python 解析 JSON 计算 file_count、function_count | 代码 (main.go) / 协议 (scan-output.md) |

这些缺陷并非 Java 独有——所有 5 个语言 SKILL.md 的 Step 2 都缺失 `--lang` 传参。C/Python/Go 没触发只是因为它们的源码树没有大型前端 bundle，auto 模式刚好没踩到超时阈值。

同类问题已频发的根源：**索引器缺少针对非预期输入的防御性处理，流程指令缺少语言感知的参数传递。** 每次扫描都在赌——赌目标项目的源码树里没有让解析器卡住的文件。这个赌不该打。

## 设计目标

### 可度量的成功标准

| 指标 | 当前 | 目标 | 验证方式 |
|------|------|-----|---------|
| `--lang` 在 SKILL.md Step 2 中传递 | ❌ 全缺 | ✅ 5 个语言全覆盖 | `grep '\-\-lang \$language' skills/secguard/*/SKILL.md` |
| JS minified bundle 解析超时 | 单文件 4418 函数卡死 | 单文件 >500KB 或 >500 函数跳过 | 对 `chunk-libs.dc48dc82.js` 实测 |
| auto 模式路径排除覆盖 | 7 个目录 | 12 个目录（含 target/build/static/public/resources） | `grep 'skip\|exclude\|ignore' internal/main.go` |
| index.json 聚合字段 | 0 个 | 4 个（file_count/function_count/call_edge_count/primary_language）对 Java 和 C 项目可取 | `cat index.json | python3 -c "import json,sys; d=json.load(sys.stdin); assert all(k in d for k in ['file_count','function_count','call_edge_count','primary_language'])"` |
| 含前端 bundle 的 Java 项目索引成功率 | 未知（当前会超时） | 100%（正常完成，不超时） | 对 pkmhipster 项目重跑 `dev-deploy.sh --verify && /secguard ./src java` |

### 非目标（明确不做）

- ❌ 不重构整个 parser 架构（双解析器保持不变）
- ❌ 不添加 Tree-sitter JS 语法编译到二进制（保持当前 JS 正则解析）
- ❌ 不改变 index.json 的核心数据结构（只加字段不改结构）
- ❌ 不修改 scanner output protocol schema

## 需求规格

### REQ-001: `--lang` 参数传递

SKILL.md Step 2 的索引器调用命令**必须**将用户指定的语言参数传递给索引器：

```
# 当前（错误）:
$INDEXER --path <path> --output <path>/index.json

# 修正后:
LANG_FLAG=""
[ -n "$language" ] && LANG_FLAG="--lang $language"
$INDEXER $LANG_FLAG --path <path> --output <path>/index.json
```

**覆盖文件**: `skills/secguard/cpp/SKILL.md`、`skills/secguard/go/SKILL.md`、`skills/secguard/java/SKILL.md`、`skills/secguard/js/SKILL.md`、`skills/secguard/python/SKILL.md`

### REQ-002: JS minified bundle 防御

`parser_javascript.go` 对解析的 JS 文件增加大小和复杂度阈值：

- 文件大小 >512KB → 跳过不解析（跳过去，不作任何解析，不报错）
- 单行字符数 >2000 → 判定为 minified，跳过不解析
- 在 ParseResult 中记录 `skipped_reason`（仅 debug 级别）

### REQ-003: auto 模式路径排除

`internal/main.go` 中的 `skipDir` 列表扩展，增加常见的构建产物目录：

| 新增排除目录 | 适用项目类型 |
|-------------|------------|
| `target/` | Maven (Java) |
| `build/` | Gradle (Java/Kotlin) / CMake (C++) |
| `static/` | 前端构建产物（Java/Python 项目常见） |
| `public/` | 前端构建产物（Go/Node 项目常见） |
| `resources/static/` | Spring Boot 前端资源 |

### REQ-004: index.json 聚合字段

`internal/main.go` 序列化 index.json 时在顶层写入以下字段：

```json
{
  "file_count": 225,
  "function_count": 392,
  "call_edge_count": 1213,
  "primary_language": "java",
  "path": "./src",
  "files": [...],
  "symbols": {...},
  "call_graph": {...}
}
```

字段说明：
- `file_count`: `len(context.Files)` — 实际索引的文件数量
- `function_count`: `len(context.Symbols.Functions)` — 提取的函数数量
- `call_edge_count`: `len(context.CallGraph.Edges)` — 调用边数量
- `primary_language`: 由 `--lang` 参数决定；未指定时 auto 模式自动检测

### REQ-005: 语言检测确定性

当 `--lang` 指定时，索引器**只**索引该语言的文件（按扩展名过滤）。当 `--lang auto`（默认）时，按当前逻辑扫描全部文件，但应用 REQ-003 的排除规则。

### REQ-006: 验证体系增强

`scripts/dev-verify.sh` 的 L3 验证增加：

- 检查 `dist/` 和部署目录中 `knowledge/guard-rules/` 的存在性
- 检查 `validate-index.py` 和 `validate-findings.py` 在 dist/ 中的存在性

（此 REQ 与 FEATURE-003 Build & Deployment Verification 共享，但索引器相关的验证在此记录）

## 设计方案

### 架构变更概览

```
┌─────────────────────┐     ┌────────────────────────────┐
│  SKILL.md (5个)      │     │  internal/main.go          │
│  Step 2 加入 --lang   │────▶│  · skipDir 扩展            │
│  instruction         │     │  · index.json 聚合字段新增  │
└─────────────────────┘     │  · lang 过滤确定性           │
                            └───────────┬────────────────┘
                                        │
                            ┌───────────▼────────────────┐
                            │  internal/parser_js.go      │
                            │  · 大小/复杂度阈值           │
                            └────────────────────────────┘
```

### 实现顺序

1. **REQ-004** (index.json 聚合字段) — 改动最小，Go 代码只加 4 行
2. **REQ-002** (JS bundle 防御) — 防止解析器卡死，独立改动
3. **REQ-003** (路径排除) — 降低 auto 模式误扫概率
4. **REQ-001** (SKILL.md `--lang`) — 影响面最大，需 5 个文件逐一修改
5. **REQ-005** (语言过滤确定性) — 配合 REQ-001 实现
6. **REQ-006** (验证增强) — 配合 deploy.sh 修复

## 风险与约束

### 已知限制

- JS minified bundle 跳过不解析后，Docker/CI 脚本中的 JS 文件（如 `webpack.config.js`）也跳过了——这不影响安全扫描，因为这些不是目标语言
- index.json 新增字段需要 render-report.py 同步感知（当前 `protocol_version` 未递增，属于兼容性扩展）
- `primary_language` 在混合语言项目（如 Java + JS）中语义上取 --lang 参数，auto 模式取占多数的语言

### 不做什么

- 不修改 index.json 的核心 schema（只加顶层字段，不改深层结构）
- 不修改 SKILL.md 的扫描执行逻辑（只改 Step 2 的参数传递）
- 不修改 render-report.py（新字段可选，AI Agent 可使用，但 renderer 不需要）
- 不修改 output protocol schema（聚合字段是便利性添加，不是协议要求）

## 变更记录

| 日期 | 变更 | 影响 REQ |
|------|------|---------|
| 2026-06-27 | 初始版本 | 全部 |
