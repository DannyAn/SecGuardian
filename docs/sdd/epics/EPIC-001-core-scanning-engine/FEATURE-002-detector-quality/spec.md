# Detector Quality Enhancement — 检测器误报消除 & 取证证据增强

> **Feature**: FEATURE-002-detector-quality
> **Epic**: EPIC-001-core-scanning-engine
> **状态**: ✅ 已完成
> **日期**: 2026-06-11
> **作者**: JonyAn + Claude Opus 4.8
> **范围**: 67 个检测器全员覆盖

**目标**: 均衡推进误报消除 (False Positive Elimination) 与取证证据增强 (Forensic Evidence Enhancement)

---

## 1. 背景与动机

### 1.1 当前问题

通过全面审查 67 个检测器，发现以下系统性问题：

| 问题 | 影响范围 | 严重度 |
|------|---------|--------|
| 误报排除章节缺失 | 6 个检测器 (resource-lock-misuse, resource-file-double-close, resource-refcount-misuse, resource-file-use-after-close, resource-socket-leak, system-secrets-detection) | 高 |
| 证据/取证概念空白 | 全部 67 个检测器 — 无一包含证据收集指引 | 严重 |
| 误报排除格式不统一 | ~30 个检测器（中文/英文标题混用，表格列数不一致） | 中 |
| 检测模式排除规则缺失 | ~40 个检测器仅有匹配模式，没有结构化排除规则 | 中 |
| 质量差异悬殊 | SQL 注入 278 行 vs Socket 泄漏 48 行 | 中 |
| Indexer Input 非标准章节 | resource-socket-leak, resource-lock-misuse 等混入部署指令 | 低 |

### 1.2 业界对标

本设计融合四大业界顶级实践的精华：

| 来源 | 借鉴要点 |
|------|---------|
| **CodeQL** `@precision` + `@problem.severity` | 检测器精度分级 (low→very-high)，经实测验证而非主观声明 |
| **Semgrep Registry** `confidence` + `likelihood` + `impact` | 分离检测器质量 (confidence) 与漏洞危害 (severity) |
| **SARIF 2.1.0** `codeFlows` / `stacks` / `suppressions` / `fingerprints` | 证据结构化：执行路径、调用栈、抑制审计追踪、跨版本匹配 |
| **ZEROFalse** (北大, 2025) 证据门控推理 | 无充分证据→不报告；LLM 基于 SARIF 结构化契约裁决 SAST 结果 (F1=0.912) |

### 1.3 超越竞品的关键差异

- **CodeQL** 的 `@precision` 是静态属性，由 GitHub 员工手动赋值；SecGuardian 新增动态 `confidence`——AI 扫描时根据实际证据完整度实时判定
- **Semgrep** 的 `confidence` 是规则级静态字段；SecGuardian 将其设为 `dynamic`，让 AI Agent 在每次扫描中根据证据收集情况动态计算
- **无竞品**在检测器文档中嵌入"证据收集指引"章节——这是 AI Agent 原生 SAST 的独特优势

---

## 2. 统一检测器模板

### 2.1 完整章节结构

```
---
detector: <namespace>.<name>
severity: <critical|high|medium|low|info>
cwe: CWE-<number>
language: [<languages>]
tags: [<tags>]
precision: <very-high|high|medium|low>
confidence: dynamic
---

# <中文标题> (<English Name>)

## 威胁定义 (Threat Definition)

## 检测逻辑 (Detection Logic)

## 取证证据收集指引 (Evidence Collection Guide)
### 必须收集 (MUST)
### 建议收集 (SHOULD)
### 可选收集 (MAY)

## 误报排除 (False Positive Exclusion)

## 修复指引 (Remediation Guidance)

## 检测模式汇总 (Detection Pattern Summary)
```

### 2.2 元数据字段定义

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `detector` | string | ✅ | 格式 `<namespace>.<name>`，如 `web.sql-injection` |
| `severity` | enum | ✅ | `critical` / `high` / `medium` / `low` / `info`，漏洞危害级别 |
| `cwe` | string | ✅ | 格式 `CWE-<number>`，精确映射 |
| `language` | array | ✅ | 适用编程语言 |
| `tags` | array | ✅ | 分类标签，≤10 个 |
| `precision` | enum | ✅ ★新增 | `very-high` / `high` / `medium` / `low`，检测器真阳性率 |
| `confidence` | string | ✅ ★新增 | 固定为 `dynamic`，AI 扫描时根据证据完整度动态判定 |

### 2.3 precision 定义

| 等级 | 含义 | 判定标准 |
|------|------|---------|
| `very-high` | 极低误报率 | 检测模式高度特化 + 排除规则完整（≥5 条） + MUST 证据 ≥3 项 |
| `high` | 低误报率 | 检测模式清晰 + 排除规则 ≥3 条 + MUST 证据 ≥2 项 |
| `medium` | 中等误报率 | 检测模式可能有变体未覆盖 + 排除规则 ≥1 条 |
| `low` | 较高误报率 | 高熵/启发式检测，需人工判断（如 system-secrets-detection） |

### 2.4 章节标准化规则

| 章节 | 标准化要求 |
|------|-----------|
| 威胁定义 | 一句话核心原则 + CWE 映射说明 + 漏洞后果 |
| 检测逻辑 | 按语言/模式分 Step，每 Step 含 BAD/GOOD 代码对比 |
| 证据收集指引 | MUST/SHOULD/MAY 三级，每项含 checkbox + 目标 schema 字段 |
| 误报排除 | 三列表格：场景 / 排除依据 / 证据要求，中文列头 |
| 修复指引 | 1→2→3 分层编号 |
| 检测模式汇总 | MATCH / EXCLUDE 分离 + Evidence 锚点注释 |

---

## 3. 证据收集指引详细设计

### 3.1 三级证据体系

| 级别 | 语义 | 对标 SARIF | 缺失后果 |
|------|------|-----------|---------|
| **MUST** | 没有这项证据，finding 不成立 | `threadFlowLocation.importance: "essential"` | 不报告 |
| **SHOULD** | 增强可复现性和审计追溯 | `importance: "important"` | 降 `confidence` 一级 |
| **MAY** | 深度取证，高严重度建议 | `attachments` / `properties` | 不影响 confidence |

### 3.2 六类证据项

| 证据项 | 级别 | 目标 schema 字段 | 说明 |
|--------|------|-----------------|------|
| code_context | MUST | `evidence.code_context` | 漏洞位置前后 ≥10 行代码，含行号 |
| judgment_rationale | MUST | `evidence.judgment_rationale` | 为什么是漏洞，引用检测逻辑的具体匹配点 |
| data_flow_path | SHOULD | `evidence.data_flow_path` | Source→Propagation→Sink 链路，每步 file+line+desc |
| call_stack | SHOULD | `evidence.call_stack` ★需新增 | 入口函数到漏洞位置的调用链 |
| variable_state | MAY | `evidence.variable_state` ★需新增 | 关键变量在触发点的值/类型/约束 |
| sanitizer_analysis | MAY | `evidence.sanitizer_analysis` ★需新增 | 消毒函数存在性+绕过分析 |

### 3.3 各检测器 MUST 证据数量要求

| precision | 最少 MUST 项 | 最少 SHOULD 项 |
|-----------|-------------|---------------|
| very-high | ≥3 | ≥2 |
| high | ≥2 | ≥2 |
| medium | ≥2 | ≥1 |
| low | ≥1 | ≥1 |

---

## 4. 误报排除升级设计

### 4.1 表格格式

统一为三列表格，每行绑定证据要求：

```
| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| <误报场景描述> | <为什么不应报告> | <需要收集什么证据才能判定为误报> |
```

### 4.2 覆盖率要求

| precision | 最少 FP 排除项 |
|-----------|--------------|
| very-high | ≥5 |
| high | ≥3 |
| medium | ≥2 |
| low | ≥1 |

### 4.3 缺失 FP 章节的 6 个检测器

需从零补齐：resource-lock-misuse, resource-file-double-close, resource-refcount-misuse, resource-file-use-after-close, resource-socket-leak, system-secrets-detection

---

## 5. 检测模式汇总升级设计

### 5.1 MATCH/EXCLUDE 分离

所有检测模式汇总统一为两个区块：

```
# === MATCH (触发检测) ===
<模式1>                          # → 证据: MUST/SHOULD/MAY 指向
<模式2>

# === EXCLUDE (不报告) ===
→ <排除条件1>                     # 对应 FP 排除表
→ <排除条件2>
```

### 5.2 Evidence 锚点

MATCH 区块的每条正则/模式必须注释对应的证据收集项，让 AI 匹配到模式时立即知道该收集什么。

---

## 6. findings-schema.json 同步更新

证据收集指引引入了 3 个新 evidence 子字段，需同步更新 schema：

### 6.1 新增字段

```json
"call_stack": {
  "type": "array",
  "description": "调用链：从入口函数到漏洞位置的完整调用栈",
  "items": {
    "type": "object",
    "properties": {
      "function": { "type": "string" },
      "file": { "type": "string" },
      "line": { "type": "integer" },
      "depth": { "type": "integer" }
    }
  }
},
"variable_state": {
  "type": "object",
  "description": "关键变量在漏洞触发点的快照",
  "properties": {
    "variable_name": { "type": "string" },
    "inferred_value": { "type": "string" },
    "type": { "type": "string" },
    "constraints": { "type": "string" }
  }
},
"sanitizer_analysis": {
  "type": "object",
  "description": "消毒函数分析：是否存在 sanitizer 及为何不足以防护",
  "properties": {
    "sanitizer_present": { "type": "boolean" },
    "sanitizer_name": { "type": "string" },
    "bypass_reason": { "type": "string" },
    "verdict": {
      "type": "string",
      "enum": ["no_sanitizer", "sanitizer_bypassed", "sanitizer_insufficient", "sanitizer_adequate"]
    }
  }
}
```

---

## 7. 实施策略

### 7.1 实施批次

67 个检测器按缺失严重度分批实施：

| 批次 | 检测器 | 工作内容 |
|------|--------|---------|
| **P0 (6个)** | resource-lock-misuse, resource-file-double-close, resource-refcount-misuse, resource-file-use-after-close, resource-socket-leak, system-secrets-detection | 从零补齐 FP 排除 + 证据收集 + 章节标准化 |
| **P1 (~15个)** | 内容过短的检测器 (<80 行)：concurrency-*, error-*, resource-* | 补充 FP 排除 + 证据收集 + 检测逻辑丰富化 |
| **P2 (~25个)** | 中等质量检测器：memory-*, system-*, crypto-* (部分) | 格式标准化 + FP 排除补充 + 证据收集 |
| **P3 (~21个)** | 已较完整的检测器：web-* (大部分), crypto-* (已完善) | 格式标准化 + 新增 precision/confidence 元数据 |

### 7.2 每批次执行流程

1. 读取检测器当前内容
2. 按统一模板改写/补齐
3. 自检清单验证（章节完整性 + FP 覆盖 + Evidence MUST 项数）
4. 扫描漏洞示例代码验证效果

---

## 8. 验证方案

### 8.1 扫描实测验证

改造后扫描 `examples/` 下的漏洞示例代码，对比改进前后：

| 验证维度 | 衡量标准 |
|---------|---------|
| 误报减少 | findings 数量变化 + 人工确认误报率 |
| 证据完整性 | evidence 四个字段（code_context, judgment_rationale, data_flow_path, call_stack）填充率 |
| 可复现性 | 同一段代码多次扫描结果的一致性 |

### 8.2 未来可选：自动化结构验证

可在 `self-check.sh` 中新增 § 检查项，自动验证每个检测器：
- 7 个必需章节全部存在
- `precision` 和 `confidence` 元数据字段存在
- MUST 证据项 ≥ precision 级别要求
- FP 排除表 ≥ precision 级别要求
- MATCH/EXCLUDE 分离

---

## 9. 参考示例

完整改造示例见 `resource-socket-leak.md` 的前后对比（设计讨论中已呈现）。

改造后的 `resource-socket-leak.md` 从 48 行 5 章节 → ~120 行 7 章节，补齐 7 项 FP 排除 + MUST 2 / SHOULD 2 / MAY 2 证据收集项。

---

## 附录 A: 67 个检测器分类清单

| 命名空间 | 数量 | 检测器 |
|---------|------|--------|
| concurrency | 4 | data-race, deadlock, race-condition, thread-unsafe-signal |
| crypto | 9 | aes-ecb-mode, custom-crypto, hardcoded-iv, hardcoded-secrets, insufficient-key-length, password-storage, tls-version, weak-crypto-algorithm, weak-random |
| error | 6 | debug-mode-production, exception-swallow, log-sensitive-data, panic-to-client, stack-trace-leak, unified-error-format |
| memory | 13 | bad-cast, buffer-overflow, double-free, format-string, heap-buffer-overflow, integer-overflow, memory-leak, mismatched-free, null-dereference, off-by-one, oob-read, uninitialized-memory, use-after-free |
| resource | 6 | file-double-close, file-leak, file-use-after-close, lock-misuse, refcount-misuse, socket-leak |
| system | 8 | command-injection, insecure-permissions, insecure-temp-file, path-traversal, privilege-escalation, secrets-detection, symlink-attack, toctou |
| web | 21 | auth-bypass, code-injection, csrf, deserialization, excessive-data-exposure, idor, input-validation, jwt-misuse, mass-assignment, missing-authentication, missing-authorization, nosql-injection, open-redirect, prototype-pollution, resource-exhaustion, sql-injection, ssrf, ssti, unrestricted-upload, xss, xxe |
