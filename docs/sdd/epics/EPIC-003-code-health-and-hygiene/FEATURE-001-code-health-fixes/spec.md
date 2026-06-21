 # Spec: Code Health Fixes

 ## 问题陈述

 SecGuardian 项目在持续迭代中积累了一批技术债问题。七项具体问题：

 | # | 问题 | 影响 |
 |---|------|------|
 | 1 | 版本漂移 — manifest.json 0.6.0 vs 主代码 0.5.5 | CI 版本检查 4/4 失败 |
 | 2 | Go build 假阳性 — 缓存 trim 失败导致 exit 1 | 验证脚本误报构建失败 |
 | 3 | AGENTS.md 内容过时 | 误导开发者 |
 | 4 | JS 解析器关键字误匹配 | 解析准确性下降 |
 | 5 | parser_re.go 变量提取不完整 | 跨平台解析不一致 |
 | 6 | context/ 包无测试 | 核心数据模型无防护 |
 | 7 | go.mod 未使用依赖残留 | 包管理整洁性 |

 ## 设计目标

 - **REQ-001**: 所有版本声明文件统一到 0.6.0
 - **REQ-002**: 验证脚本 Go 编译检查返回真实构建状态
 - **REQ-003**: AGENTS.md 项目描述与实际一致
 - **REQ-004**: JS 解析器不误匹配 JavaScript 关键字
 - **REQ-005**: 跨平台 fallback 解析器覆盖所有语言的变量提取
 - **REQ-006**: context/ 包有可执行的单元测试
 - **REQ-007**: go.mod 声明与代码实际依赖一致

 ## 不做什么

 - 不引入新的 Tree-sitter 语法编译（JS 仍用正则 fallback）
 - 不改动分析上下文 (AnalysisContext) 的数据结构
 - 不改动 index.json 输出格式
 - 不添加 parser_re.go 对 JavaScript 的变量提取（已由 parser_javascript.go 处理）
