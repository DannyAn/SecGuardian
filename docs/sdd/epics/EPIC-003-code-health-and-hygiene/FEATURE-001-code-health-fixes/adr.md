 # ADR: Code Health Fixes

 ## ADR-001: GOCACHE 环境变量绕过 Go build 假阳性

 **日期**: 2026-06-21
 **状态**: ✅ Accepted

 ### Decision

 在 self-check.sh 和 ci-check.sh 的 Go 编译检查中，在执行 `go build` 前设置 `GOCACHE` 为可写的临时目录（`$(mktemp -d)`），区分构建错误和缓存 trim 失败。

 ### Reason

 1. Go 1.23+ 在 build 缓存 trim 失败时（sandbox/权限不足）返回 exit code 1，即便构建成功
 2. `2>/dev/null` 能隐藏 stderr 但无法改变退出码
 3. 设置 `GOCACHE` 是最小侵入方案——不改 Go 版本、不改构建流程

 ### Rejected Alternatives

 | 方案 | 否决原因 |
 |------|---------|
 | 移除 `2>/dev/null` 并解析输出 | 脆弱、依赖 Go 工具链未文档化的输出格式 |
 | 构建后检查产物是否存在 | 需要额外文件系统检查，不直接 |
 | `|| true` 忽略 exit code | 会真正掩盖构建失败 |

 ### Consequences

 - 验证脚本新增 `GOCACHE` 环境变量设置
 - 假阳性消除后，真正的 Go 编译错误仍会被正确捕获

 ## ADR-002: parser_re.go 变量提取只扩展 Go/Java/Python（不含 JS）

 **日期**: 2026-06-21
 **状态**: ✅ Accepted

 ### Decision

 对 parser_re.go 的变量提取增加 Go/Java/Python 三种语言的支持。JavaScript 跳过，因为已有独立的 parser_javascript.go 处理。

 ### Reason

 1. Go 索引器跨平台构建使用 parser_re.go（CGO 禁用时），但变量提取全覆盖只有 C/C++ 有
 2. JS 的变量提取由 parser_javascript.go（无 build tag）统一处理，不受 parser_re.go 影响
 3. Python 的变量提取相对简单（`variable = value` 模式），Go 和 Java 有合适的正则模式

 ### Rejected Alternatives

 | 方案 | 否决原因 |
 |------|---------|
 | 连 JS 也加上 | 与 parser_javascript.go 职责重叠，有重复定义风险 |
 | 合并 parser_re.go 和 parser_javascript.go | 违反编译期二选一设计，JS 始终需要独立解析器 |

 ### Consequences

 - parser_re.go 增加 ~30 行代码
 - regex 模式为近似匹配，精度远低于 Tree-sitter（已文档化）

 ## ADR-003: context/ 测试只做 JSON round-trip + 核心类型验证

 **日期**: 2026-06-21
 **状态**: ✅ Accepted

 ### Decision

 context/ 包的测试只覆盖 JSON 序列化/反序列化和核心类型字段赋值验证，不追求全路径覆盖。

 ### Reason

 1. context/ 包本质是 Go 结构体定义 + JSON 序列化，无业务逻辑
 2. 核心风险在 JSON 字段 tag 和类型字段缺失，round-trip 测试覆盖了这个风险
 3. 最小化测试维护成本——结构体变化时只需要更新测试用例

 ### Consequences

 - 新增 context/context_test.go，包含 2 个测试函数
 - 不引入 test helper 或 mock 框架
