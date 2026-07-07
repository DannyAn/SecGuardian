# ADR-003: Review Remediation Decisions

> **Feature**: FEATURE-003 Review Remediation

## ADR-003-001: Gradual O(n²) Mitigation (Not Full Rewrite)

**Context**: MatchAllocFree 在 indexer.go 中使用 O(n²) 遍历。完全修复需要 CFG/DFG 能力。
但当前索引器的 text-approximate 设计取舍是已知的（AGENTS.md 已记录）。

**Decision**: 做函数作用域哈希分组来缩小匹配范围，不做完整变量追踪。
这是渐进改善（O(n²) → O(n × lines_in_function)），不是重写。

**Consequences**:
- Positive: 零行为变更，旧逻辑安全降级为回退
- Risk: 函数作用域分组的边界条件可能 miss 跨函数 free
- Mitigation: 当分组无法确定时回退到全文件搜索

## ADR-003-002: JS Regex Parser Gets Same Protection as Tree-sitter

**Context**: parser_re.go 的 JS 路径在 CGO=0 构建时是唯一 JS 解析器，
但没有 parser_ts.go 的 512KB/2000行防护。

**Decision**: parser_re.go 中增加同样的文件大小和行长度检查。
JS 文件解析路径在 CGO=1 和 CGO=0 时行为一致。

**Consequences**:
- Positive: 跨平台二进制不再对压缩 JS 文件 OOM
- Positive: dual parser 的 JS 行为对齐

## ADR-003-003: Cache Key Includes Source Content Hash

**Context**: secguardian-index wrapper 的缓存用路径做 key。用户修改源码后路径不变 → 缓存命中 → 旧结果。

**Decision**: 将缓存 key 改为 `path + source_content_md5`。运行时计算源码 MD5 前缀，
插入到缓存键中。路径变或内容变 → 缓存 miss → 重建。

**Consequences**:
- Positive: 不再有脏缓存命中
- Risk: 全量扫描场景需要对源文件少量 I/O（计算 MD5 前 4KB 以减少开销）
