# EPIC-008: OOP-Aware Semantic Indexing

> **状态**: 📋 进行中
> **周期**: 2026-07-08 ~
> **目标**: 系统性修复索引器对 OOP 语言（Java/C++/Python/Go）的类方法提取缺陷，建立面向安全扫描的 OOP 元数据和局部类型推断能力

## 问题背景

生产扫描日志分析发现索引器存在系统性 OOP 缺陷：

| 发现问题 | 严重度 | 发现方式 |
|----------|--------|----------|
| C++ `class_specifier` → method 未行走，inline 类方法完全丢失 | ✅ **Bug** | Code review |
| Python `function_definition` 不提取 call sites | ✅ **Bug** | Code review |
| Go `function_declaration`/`method_declaration` 不提取 call sites | ✅ **Bug** | Code review |
| `FunctionInfo` 无 ClassName，无法关联方法到所属类 | ⚠️ 设计缺失 | Code review |
| `CallSite` 无 ReceiverExpr，`obj.method()` 丢失接收者信息 | ⚠️ 设计缺失 | 生产日志 |
| 无类型推断，`conn.executeQuery` 和 `safeWrapper.executeQuery` 无法区分 | ⚠️ 设计缺失 | 生产日志 |

## 包含 Feature

| Feature | 状态 | 说明 |
|---------|------|------|
| FEATURE-001: Fix Class Method Extraction | 📋 Spec/ADR/Plan 完成 | C++/Python/Go 类方法提取修复 + parser_re.go 扩展 |
| FEATURE-002: OOP Metadata Enrichment | 📋 Spec/ADR/Plan 完成 | ClassName、Visibility、IsStatic、ReceiverExpr 字段 |
| FEATURE-003: Single-File Type Inference | 📋 Spec/ADR/Plan 完成 | import 解析 + 局部变量类型追踪 + ReceiverType |

## 架构影响

本 Epic 扩展了 ADR-007（信号-LLM 协作模型）中"确定性信号层"的粒度：

- **Before**: 索引器知道 `executeQuery` 被调用，但不知道接收者是谁
- **After**: 索引器知道 `conn.executeQuery(sql)`，且 ReceiverType 可被解析为 `java.sql.Connection`

下游检测器可根据 `ReceiverType` 做更精准的置信度判断——`Connection.executeQuery` 高置信 SQL 注入，`DTO.executeQuery` 降级或忽略。

## 验证体系

| 层次 | 方法 | 工具 |
|------|------|------|
| 单元测试 | 各语言临时文件解析测试 | `go test -run TestParseFile_TS_*` |
| 冒烟 | Java/C++/Go/Python demo 项目 | `dev-verify.sh --quick` |
| 端到端 | 生产 Java 项目 | `verify-signals.sh --round4` |
| 回归 | 现有测试全部通过 | `go test ./...` |
