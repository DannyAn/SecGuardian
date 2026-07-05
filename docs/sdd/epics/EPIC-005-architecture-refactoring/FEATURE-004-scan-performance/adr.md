# ADR-004: Scan Performance Optimization Decisions

> **Feature**: FEATURE-004 Scan Performance Optimization

## ADR-004-001: I/O Consolidation (Not Architecture Rewrite)

**Context**: 扫描耗时 97% 在 I/O（shell commands + file reads/writes），
不在 AI 推理。优化方向是减少操作次数，而不是重写引擎或替换 LLM。

**Decision**: 保持现有架构不变（LLM 作为执行引擎），只优化 commands/skills
中 AI Agent 的操作指令——减少 shell command 次数、合并文件 I/O。

**Consequences**:
- Positive: 无需修改 Go 代码，改动范围可控
- Positive: 效果可预测量化（次数减少 → 时间减少）
- Risk: 每次操作合并后，AI 的上下文可能变大（单次输出更多）
- Mitigation: 控制单次操作的输出量（language-index.md 57 行本身已很小）

## ADR-004-002: Language-index as Single Detector Source

**Context**: 67 个 detector 各对应一个 `knowledge/guard-rules/*.md` 文件。
AI 逐个加载导致 10s+ 延迟。`knowledge/language-index.md`（57 行）已包含
所有检测器的语言分组列表。

**Decision**: AI 通过 language-index.md 获取全量检测器清单。
按需（when a match is found）再加载单个 detector 的详情文件。
整体 I/O 从 67 次文件读取降至 ≤ 2 次。

**Consequences**:
- Positive: 检测器清单加载时间从 10s+ 降到 <3s
- Risk: AI 可能因为缺少 detector 详情而误判
- Mitigation: detector 详情在匹配到 candidate 后再按需加载

## ADR-004-003: Findings Batch Output

**Context**: v5.0 协议要求每个 finding 一个独立 JSON 文件，AI 逐个写入。
30 个 finding 用了 16 次 shell write。

**Decision**: AI 不再逐个写入 finding 文件。改为一次性输出所有 findings
到 `findings.json`（v4.0 单文件格式），由 `render-report.py` 统一拆分为
per-detector 文件和各格式报告。

**Consequences**:
- Positive: 写入操作从 N 次降为 1 次
- Positive: renderer 已支持拆分（通过 `--findings findings.json` 参数）
- Risk: findings.json 单文件可能较大（1000+ findings）
- Mitigation: renderer 拆分是流式读取，不一次性加载全部

## ADR-004-004: --health as Single Pre-flight Check

**Context**: 前置检查列了 9 个独立 check 项。`secguardian-index --health`
已经包含 binary 健康检查 + 环境验证。

**Decision**: 前置检查替换为：
1. `secguardian-index --health`（验证 binary + 环境）
2. 检查扫描路径是否存在

其他检查（python3、renderer、language-index）由对应步骤失败时处理。

**Consequences**:
- Positive: 前置检查从 27s 降至 ~3s
- Risk: 某些环境问题可能延迟暴露（如 python3 缺失）
- Mitigation: 每一步执行时检查依赖，不存在则报错
