# FEATURE-004: Scan Performance Optimization

> **隶属 Epic**: EPIC-005 Architecture Refactoring
> **版本**: v0.1 (Final)
> **参考**: 实测数据见 brainstorm-log.md（go-vuln-demo 8 文件, 16m47s）

---

## 1. Problem Statement

### 1.1 扫描 I/O 次数过高

对 `examples/go-vuln-demo`（8 个 Go 源文件）扫描实测：

| 操作 | 次数 | 耗时 | 占总时间 |
|------|------|------|---------|
| Shell commands（前置检查） | 9 | 27s | 2.7% |
| File reads（源文件） | 8 | 19s | 1.9% |
| File writes（findings） | 16 | 19s | 1.9% |
| Shell cmds（检测器加载） | 2 | 10s | 1.0% |
| 索引构建 | 1 | 1s | ✅ 可接受 |
| 渲染器 | 1 | 15s | 含 AI 修复 import 时间 |
| **总计** | **37** | **~100s** | **16m47s** |

**核心瓶颈不是 AI 推理，是 I/O 次数。** 每次 shell command / file read 在 Claude Code
中约消耗 1-3s（含上下文切换）。AI 的推理时间占比不足 10%。

### 1.2 已部署代码与架构合约的差距

FEATURE-002 在 commands/skills 中增加了架构层标记，但**内容本身仍是旧版的 I/O 密集写法**。
前置检查、finding 写入、检测器加载等操作未按 `engine_contract.md` / `output_contract.md`
的要求优化。

---

## 2. Requirements

### REQ-001: 前置检查从 9 步合并为 1 步

**现状**: `commands/secguard.md` 前置检查列出了 9 个独立 check 项
（SECGUARDIAN_HOME、binary、health、python3、renderer、language-index 等）。

**目标**: 用 `secguardian-index --health` 单次检查替代 9 次独立 shell command。

### REQ-002: 源文件读取从逐文件改为 index 驱动

**现状**: AI 逐个 read 源文件。对 8 个文件做了 8 次 read。

**目标**: 读取 index.json 后，用符号表定位检测目标，只读 index 标注的 "有检测价值" 的代码段。
没有符号的文件不读全文（除非 detector 明确要求）。

### REQ-003: 检测器加载从逐个 .md 改为批量 language-index

**现状**: AI 逐个加载 `knowledge/guard-rules/*.md`（67 个文件），每个文件 ~120 行。

**目标**: `knowledge/language-index.md`（57 行）已包含所有检测器列表。
一次加载该文件即可获取全量检测器清单。按需加载实际匹配的 detector 详情。

### REQ-004: Finding 记录从逐条改为批量

**现状**: AI 逐条执行 `python3 record-finding.py` 写入，30 个 finding 做了 16 次 write。

**目标**: AI 一次输出全部 findings 到 `findings.json`（v4.0 单文件格式），
然后由 `render-report.py` 统一拆分为 per-detector 文件和各类报告。

### REQ-005: Renderer import 修复

**现状**: 部署版 render-report.py 缺少 `from collections import Counter`，
AI 扫描到一半自己加了一行。

**目标**: 修复 renderer 的 import 缺失，部署后无需 AI 运行时修补。

---

## 3. Non-Requirements

| 不做 | 原因 |
|------|------|
| 修改 Go 索引器代码 | 索引器本身已快（1s），瓶颈在 AI 端的 I/O |
| 修改 detector 规则内容 | 知识资产不动 |
| 修改 output protocol 格式 | v5.0/v7.0 协议已定 |
| 修改 renderer 渲染逻辑 | 只修 import 缺失 |

---

## 4. Success Criteria

| # | 标准 | 验证方式 |
|---|------|---------|
| 1 | 前置检查 shell 命令数 ≤ 2 | 扫描日志 grep |
| 2 | 源文件 read 数 ≤ 4（8 文件项目的参考标准） | 扫描日志 grep |
| 3 | 检测器加载 shell 命令数 ≤ 2 | 扫描日志 grep |
| 4 | Finding 写入 shell 命令数 ≤ 2 | 扫描日志 grep |
| 5 | renderer 无 AI 运行时修补 | 扫描日志中无 "Add import" 操作 |
| 6 | go-vuln-demo 扫描时间 ≤ 3min | `time` 实测 |
| 7 | cpp-vuln-demo 扫描时间 ≤ 5min | `time` 实测 |
| 8 | self-check 通过 | exit 0 |
| 9 | e2e-verify --quick 通过 | exit 0 |

---

## 5. 相关文档

- `internal/engine/engine_contract.md` — Engine 职责定义
- `internal/output/output_contract.md` — 输出职责定义
- `knowledge/protocols/scan-output.md` — v7.0 输出协议
- `knowledge/language-index.md` — 语言规则索引（57 行）
- `docs/sdd/brainstorm-log.md` — 实测耗时分析
