# ADR Records — FEATURE-005: Indexer Robustness

---

## ADR-001: `--lang` 参数放在 SKILL.md 指令层而非索引器 auto 检测

**日期**: 2026-06-27
**状态**: ✅ Accepted

### Decision

在 5 个语言的 `skills/secguard/*/SKILL.md` Step 2 指令中，将用户传入的 `$language` 参数以 `--lang $language` 传递给索引器。

### Reason

- **流程问题用流程解决**：`--lang` 不传参是 AI Agent 执行指令时的遗漏，不是索引器本身的缺陷。索引器已经有了 `--lang` flag（confirmed via `--help`），只是 SKILL.md 没有教 AI 怎么用
- **零代码改动**：5 个 SKILL.md 的修改不涉及 Go 编译，`dev-deploy.sh` 后即时生效
- **语义精确**：用户说 `/secguard ./src java`，索引器收到 `--lang java`，两者一致。auto 检测做不到这种精度

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 在索引器 `auto` 模式中增加增强的扩展名过滤 | 索引器不知道用户意图——它不知道扫描是只针对 Java 还是全量。语言选择权在命令层面 |
| 在命令层的 find_indexer() 之后加入参数拼装逻辑 | 逻辑重复。5 个语言的 SKILL.md 都要改，不如一步到位 |
| 在 validate-index.py 中检测语言不匹配 | 那是事后诸葛亮，扫描已经浪费了时间 |

### Consequences

+ 5 个 SKILL.md 文件修改量极小（各 1 行）
+ AI Agent 在任何语言下都会准确传参
- `auto` 模式的路径排除仍需加强作为兜底（REQ-003）

---

## ADR-002: JS minified bundle 双阈值检测（文件大小 + 行长）

**日期**: 2026-06-27
**状态**: ✅ Accepted

### Decision

在 `parser_javascript.go` 中增加两阶段守卫：

1. 文件大小 >512KB → 跳过
2. 单行字符数 >2000 → 判定为 minified，跳过

### Reason

- **双阈值互补**：文件大小捕捉大型 bundle（>512KB），行长捕捉小文件但单行极长（某些 esbuild 产出产物只有几百 KB 但压缩成一行的）
- **性能可预测**：单次扫描的 JS 解析时间上限 = `文件数量 × O(1)` 不是 `总字符数`
- **简单可验证**：双阈值都是标量比较，不依赖 AST 分析，不引入新的依赖

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 使用 AST 节点数阈值（>500 函数跳过）| 需要先 parse 才能知道 AST 节点数，已经浪费了解析时间 |
| 只使用文件大小 | 某些 esbuild 产物几百 KB 但一行到底，行长可以单独命中 |
| 黑名单文件名模式（如 `chunk-*.js`）| 模式变化太多，维护成本高，容易漏 |
| 移到 main.go 用扩展名排除 | 正常 JS 文件（如 webpack.config.js）需要解析，不能一刀切 |

### Consequences

+ 解析时间可预测的上限 = O(文件数)，不再是 O(字符数)
+ minified bundle 跳过后不影响目标语言的索引
- 极端情况 510KB 的非 minified JS 文件误判跳过（概率极低，不影响安全扫描）

---

## ADR-003: index.json 聚合字段放在顶层而非独立元数据文件

**日期**: 2026-06-27
**状态**: ✅ Accepted

### Decision

在 `internal/main.go` 序列化 `AnalysisContext` 时，在 JSON 顶层写入 `file_count`、`function_count`、`call_edge_count`、`primary_language` 四个字段。

### Reason

- **消费方零改动**：AI Agent 和 renderer 现有的 `data.file_count` 路径不需要改（新字段不在 core schema 中，但增加了 `data.file_count` 的便利访问）
- **自包含**：index.json 就是元数据本身，不需要额外加载第二个文件
- **与 protocol_version 兼容**：新增字段不破坏现有 schema（顶层键只是增加）

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 独立 metadata.json | 两个文件需要同步加载，原子性差。AI Agent 需要做文件存在性检查 |
| 写入 index.json 的 `stats` 子对象 | 多一层嵌套，AI 访问路径变长（`data.stats.file_count` vs `data.file_count`） |
| render-report.py 在消费端计算 | 每次渲染都重复计算，浪费。且 AI Agent 也需要这些值 |

### Consequences

+ AI Agent 无需写 Python 解析 JSON 即可获取扫描统计
+ renderer 可复用这些字段做 dashboard
- index.json 体积增大 ~100 字节（可忽略）

---

## ADR-004: auto 模式路径排除采用静态列表而非 glob 模式

**日期**: 2026-06-27
**状态**: ✅ Accepted

### Decision

在 `internal/main.go` 的 `skipDir` 静态列表中增加 `target/`、`build/`、`static/`、`public/`、`resources/static/`，不做 glob 或通配符匹配。

### Reason

- **与现有模式一致**：已有排除是静态目录名比较（如 `node_modules`、`.git`），新增目录用同样方式
- **性能**：静态比较是 O(n)，glob 匹配按行
- **精确**：静态目录名不会误匹配用户自定义目录

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 全局忽略文件（类似 .gitignore） | 需要额外维护和读取，与现有架构不兼容 |
| 配置文件中的排除列表 | 会增加复杂度，且需要让 AI Agent 感知 |
| 传递给 --exclude 参数 | 指令层复杂度增加，与 REQ-001 的 `--lang` 叠加复杂度高 |

### Consequences

+ 零配置直接生效
+ 与 `--lang` 配合：`--lang java` 时按扩展名过滤，路径排除作为兜底
- `resources/static/` 是相对路径，只在特定项目结构下有效。更通用的方案是 `static/` 作为目录名

---

## ADR-005: JS 文件跳过时不记录日志到 stdout

**日期**: 2026-06-27
**状态**: ✅ Accepted

### Decision

对于被阈值跳过的 JS 文件，不在索引器 stdout 中输出警告或错误。信息仅通过 `ParseResult.SkippedReason` 字段保留（debug 级别，不序列化到 index.json）。

### Reason

- **不影响用户感知**：用户只关心目标语言的索引结果，不关心"跳过了哪些 JS bundle"
- **减少 stdout 噪声**：含前端项目的 src 可能有几十个 bundle，每个输出一行 warning 会淹没有用信息
- **可调试**：内部仍保留 skipped_reason 字段，需要调试时加一行 debug 输出即可

### Consequences

+ 用户视角：索引器输出更干净
+ AI Agent 视角：不影响现有输出解析逻辑
- 调试时需要手动加 debug 输出
