 # TASK-006: context/ 包测试覆盖

 ## Goal

 为分析上下文 AnalysisContext 包添加单元测试，覆盖 JSON 序列化/反序列化和核心类型字段赋值。

 ## Files Changed

 - `internal/context/context_test.go` — 新测试文件
   - TestJSONRoundTrip: 创建完整 AnalysisContext，marshal→unmarshal，验证字段一致性
   - TestEmptyContext: 验证空 AnalysisContext JSON 输出包含所有必需字段

 ## Verification

 ```bash
 (cd internal && gc=$(mktemp -d) && GOCACHE=$gc go test ./context/... 2>&1; rm -rf "$gc")
 ```
