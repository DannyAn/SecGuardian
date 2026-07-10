# Progress — FEATURE-002: Tree-sitter Primary + CFG Construction

> **隶属**: EPIC-011 / FEATURE-002
> **状态**: 🔄 进行中（设计四环就绪，实现待启动）

## 状态总览

| 阶段 | 状态 |
|------|------|
| 🧠 Brainstorm | ✅ 已记入 brainstorm-log.md |
| 📋 Spec | ✅ 就绪 |
| 📝 ADR | ✅ 就绪（ADR-101~103）|
| 📐 Plan | ✅ 就绪（TG-E~G，11 Task）|
| 🔨 Task | 🔄 TG-E 启动中 |
| 📊 Progress | 🔄 本文件 |
| 🔄 Change | ⬜ 无 |

## Task 进度

### TG-E: CFG 构建
- [x] TASK-014 FunctionCFG 类型（BasicBlock/Edge/EdgeType + Exit 块）✅ 2026-07-10
- [x] TASK-015 cfg.go BB + if/for/while/return/break/continue 边构建 ✅ 2026-07-10（4/4 单测通过）
- [x] TASK-016 IsReachable + Dominates（迭代支配树）✅ 2026-07-10
- [ ] TASK-017 switch/try/throw + incomplete 标记（switch/try 已保守处理并标 Incomplete，待精确化）
- [x] TASK-018 CFG 接入索引管线 ✅ 2026-07-10（AnalysisContext.cfgs 字段 + extractCFGs 在 ParseFile 调用 + main.go 聚合；cpp-vuln-demo 实测 110 CFGs/96 函数，双路径构建通过）

### TG-F: S3 Declarations + prescreener
- [x] TASK-019 填充 Declarations（修 3 个预存红测试）✅ 2026-07-10（collectDeclarations + extractCInclude；3 红测试转绿，cpp-vuln-demo 139 decls/57 imports）
- [x] TASK-020 prescreener 接通 ✅ 2026-07-10（SafeCount 0→8，EPIC-009 降噪生效；self-check 113/113，e2e 54/0）

### TG-G: tree-sitter 全平台
- [ ] TASK-021 zig cc 交叉编译
- [ ] TASK-022 删 parser_re + 移除 cgo tag
- [ ] TASK-023 CI 装 zig
- [ ] TASK-024 跨平台等价守卫

## 关键里程碑
- 2026-07-10: 设计四环就绪；关键实证：tree-sitter 确需 CGO（非 tag 误标），zig cc 为全平台唯一解析器路径
- 2026-07-10: TG-E TASK-014/015/016 落地——`internal/parser/cfg.go` + `cfg_test.go`，4/4 单测通过，build + indexer/context 无回归。3 个预存 F6 红测试待 TASK-019 修复

## 阻塞项
- TG-G 依赖 zig 安装（brew install zig），需用户环境确认或 CI 提供
- TG-E/TG-F 不依赖 zig，可立即推进
