# ADR — Output Protocol Architecture Decisions

> **Feature**: FEATURE-001-output-protocol
> **原则**: Brainstorm 决定方向 → ADR 记录决策

---

## ADR-001: 四段式强制质量门禁

**日期**: 2026-06-05
**状态**: ✅ Accepted

### Decision

每个安全 Finding 必须包含四段式结构，缺一不可：
1. 📍 Location — 文件+行号+函数+代码行
2. 📋 Evidence — 代码上下文+判定依据+数据流
3. ⚠️ Impact — 攻击场景+CVSS+利用条件
4. 🔧 Fix — Before/After 代码+工作量+验证方法

质量门禁强制执行：AI Agent 输出前逐项检查，任一 ❌ → 补充 → 重新检查，最多 3 次。

### Reason

- v2.0 输出质量波动大：同一份协议，有时完整报告有时只有摘要
- 根因是**无强制性门禁**——协议定义了模板但未要求验证
- SARIF viewer 体验差：用户点击定位后只看到一行 message.text 摘要

### Rejected Alternatives

- **仅更新协议文件不改命令**：AI Agent 可能忽略协议升级，质量不会改善
- **在 renderer 层校验**：丢失的信息无法恢复，校验必须在 AI 输出阶段完成

### Consequences

- 3 个 command 文件 + 5 个 skill 文件需嵌入质量检查清单
- 增加 AI Agent 输出耗时约 10-20%（自检开销），但消除返工

---

## ADR-002: AI/Renderer 分离架构

**日期**: 2026-06-05
**状态**: ✅ Accepted

### Decision

AI Agent 只负责语义分析 → 输出结构化 `findings.json`。
Renderer (`scripts/render-report.py`) 负责所有格式化输出（report.md / SARIF / summary / manifest / status / delta）。

### Reason

- AI 擅长语义分析，不擅长模板渲染和格式校验
- 渲染逻辑与 AI 上下文无关——占用 token 却不产生安全价值
- 分离后 AI token 消耗降低 66%，扫描耗时降低 70%

### Rejected Alternatives

- **AI 直接输出 Markdown**：格式不一致、SARIF 生成困难、难以 CI 集成
- **Renderer 用 Node.js/Python 双实现**：维护两套，无必要。Python 3 stdlib 足够

### Consequences

- `render-report.py` 成为架构关键路径（CI 门禁依赖它）
- findings.json 需严格遵循 `findings-schema.json`（Renderer 按 schema 解析）

---

## ADR-003: 目录树 vs 单体 JSON

**日期**: 2026-06-07
**状态**: ✅ Accepted

### Decision

v5.0 将单体 `findings.json` 拆分为按 detector 组织的目录树：
```
findings/<namespace>/<detector>/<finding-id>.json
```
每个 finding 一个独立文件（~2KB），文件名 = finding ID（天然唯一）。

`findings.json` 同名升级：从"单体四段式"变为"轻量索引+元数据"。

### Reason

- v4.0 单体 JSON 在 1000 文件项目中预估 25MB——AI Agent 无法读取
- 企业级项目（10000+ 文件）完全不可行
- 按 detector 拆分的目录树天然支持：
  - 按需读取单个 finding（2KB vs 25MB）
  - 按漏洞类型分工（"小王负责 findings/crypto/，小李负责 findings/web/"）
  - Git 友好的增量变更

### Rejected Alternatives

- **按 severity 分目录**：用户明确反对——"级别低不代表不是问题，不要给客户造成某些问题不重要的暗示"
- **`<file>__<func>.json` 命名**：同文件同函数同 detector 不同行会碰撞，需要 `__N` 后缀补丁
- **保持单体 JSON + 分页读取**：增加复杂度，且 AI Agent 的 Read 工具不支持分页

### Consequences

- Renderer 需支持 `--findings-dir` 新模式（`os.walk()` 遍历聚合）
- AI Agent 输出从 1 次 Write(50KB) 变为 N 次 Write(2KB each)
- 向后兼容 v4.0 单体格式（`--findings` 参数保留）
