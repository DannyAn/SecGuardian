# Architecture Decision Records — FEATURE-007

> **Feature**: FEATURE-007 Strategic Repositioning
> **Context**: 与 ChatGPT 深度讨论后，决定对项目进行战略定位升级

---

## ADR-001: 从"AI Scanner"叙事切换到"Security Workflow"叙事

**日期**: 2026-06-30
**状态**: ✅ Accepted

### Context

项目 README 的旧叙事是"AI 比传统 SAST 更聪明"（如"年省 $50K+ 安全顾问费用"、"5 项 AI 分析方法超越传统扫描"）。
ChatGPT 指出该叙事生命周期很短：12 个月后 AI 推理能力将是所有产品的共同能力。

### Decision

将 README 的核心叙事从"AI 优于 SAST"切换为"三件随时间增值的事":

1. **Enterprise Security Knowledge (Rule Packs)** — 行业标准 → 可执行审计规则
2. **Secure SDLC Workflow (Four Gates)** — 编码 → PR → 修复 → 发布
3. **Enterprise-Consumable Outputs** — 给不同角色的输出

### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 继续卖"AI 比 SAST 聪明" | ChatGPT：生命周期 < 12 个月。Cursor/GPT/Gemini 都在追赶 AI 推理能力 |
| 既保留旧叙事、又叠加新叙事 | README 变冗长，读者注意力被稀释。一个文件只讲一个核心故事 |
| 卖"Rule Packs 比检测规则更聪明" | 这还是同一件事换了一个说法。Rule Packs 的价值在于组织方式，不是"更聪明" |

### Consequences

- 丢掉"传统 SAST 做不到"这个短期共情点
- 获得了"知识组织 + 流程 + 输出"这个长期防御优势
- README 的第一印象从"又一个安全扫描工具"变为"企业安全流程平台"

---

## ADR-002: /secreview 从"规范检视"改为"AI Security Code Review for PRs"

**日期**: 2026-06-30
**状态**: ✅ Accepted

### Context

旧的 /secreview 定位是"安全编码规范检视"——检查代码是否符合 SEI CERT、OWASP 等编码规范。
但这个定位：

1. 拉低了用户的期望值（只是检查规范合规？那不如用 linter）
2. 和 /secguard 的关系模糊（secguard 也是检视漏洞）
3. 在 SDLC 中的阶段不明确

### Decision

将 /secreview 重新定位为 **"AI Security Code Review for Pull Requests"**：

- 面向 PR 阶段（而非编码阶段）
- 输出 exploit scenarios + CWE + 业务逻辑分析（而非合规性报告）
- 与 /secguard 的区别从"漏洞 vs 规范"变为"Coding vs PR"

### Key Changes

| 变化 | 旧 | 新 |
|------|-----|-----|
| Scan ID 前缀 | `rv-` | `pr-` |
| 检视维度 | 反模式识别 | 三轮推理：Vulnerability Detection → Business Logic → Anti-pattern |
| 必须字段 | 四段式 + 规范条款引用 | 四段式 + exploit_scenario (必填) + CWE |
| 支持模式 | 全量扫描 | 全量 + git diff PR review |

### Consequences

- /secreview 现在与 /secguard 有清晰的分工：编码时预防 vs PR 时检测
- 每个 finding 的必填 exploit_scenario 字段确保 AI 不只是做模式匹配
- 需要更新 5 个语言的 SKILL.md 中的 vs secguard 对比表

---

## ADR-003: /secfix 命名与位置

**日期**: 2026-06-30
**状态**: ✅ Accepted

### Context

发现 → 修复 → 验证是一个自然的工作流。/secreview 检出发现后，应该有一个对应的修复命令。

### Decision: 命名

**选中方案: `/secfix`**

| 候选 | 评估 |
|------|------|
| **/secfix ✅** | sec- 前缀一致，2 音节，固定动词，"fix" 是工程师最自然的选择 |
| /fixit ❌ | 语气太随意，"帮我修一下"不像安全工具 |
| /secremediate ❌ | 4 音节太长，remediate 在日常开发对话中不自然 |
| /secpatch ❌ | 容易联想到 OS 补丁管理，语义范围太窄 |

### Decision: 位置

**/secfix 不是独立第四 Gate，而是 /secreview 的出口动作。**

```
/secreview
    |
    ├── Clean → Merge
    |
    └── Findings → /secfix → patches → git commit → /secreview re-run
```

Gate 是决策点（合并/不合并、发布/不发布）。「修复」是不对应决策点的动作——修完之后还是要重新走检测 Gate。因此 /secfix 作为 secreview 的 remediation 出口，同时被 secguard 和 secaudit 按需调用。

### Decision: 商业价值叙事

不卖"AI 替人修代码"（企业不会让 AI 自主修安全代码）。卖 **"把 30 分钟修复耗时降到 2 分钟"**。

| 价值点 | 受众 |
|--------|------|
| 减少修复耗时 10x | 工程 VP |
| 标准化修复质量 | 安全负责人 |
| 降低修复门槛 | 团队新人 |
| 可审计的修复记录 | 合规团队 |
| 修复 backlog 清零 | 所有人都爱 |

### Consequences

- README 的 SDLC 图加入了 /secfix 分支
- 命令命名体系完整：secguard / secreview / secfix / secaudit
- /secfix MVP 路径清晰：消费 findings/ 目录 → 从 fix.before_code + fix.after_code 生成 .patch 文件

---

## ADR-004: Four Gates — 完整 SDLC 管线

**日期**: 2026-06-30
**状态**: ✅ Accepted

### Context

旧版 README 使用"三个产品"的表述（SecGuard / SecReview / SecAudit），但只强调了它们"是什么"，没有明确它们"在 SDLC 的哪个阶段用"。

### Decision

重新定义为 **Four Gates**，每个 Gate 对应 SDLC 的一个阶段：

| Gate | 命令 | SDLC 阶段 | 用户 | 决策 |
|------|------|-----------|------|------|
| Prevent | /secguard | 编码 | 开发者 | 安全地编码 |
| Detect | /secreview | PR | 开发者 + Reviewer | 是否可以合并 |
| Fix | /secfix | PR 出口 | 开发者 | 修复是否完成 |
| Verify | /secaudit | 发布 | 安全团队 | 是否可以发布 |

关键设计原则：每个 Gate 回答一个明确的 yes/no 问题。

### Consequences

- 从"三个产品"变为"四个阶段"——叙事从工具导向变为流程导向
- 新增 /secfix Gate 需要更新 README 中的 SDLC 图、Gate 表、Vison 章节
- 本次不调整 /secaudit 内容（等用户提供新方案）

---

## ADR-005: 采纳 ChatGPT "商品化推理"预警

**日期**: 2026-06-30
**状态**: ✅ Accepted

### Context

ChatGPT 提出如下观点：**"12 个月后 AI 推理能力是商品，不是差异化优势。真正长期不贬值的只有 Rule Packs、Workflow、Outputs。"**

### Decision

在本版本中彻底采纳该观点：

- "Why SecGuardian?" 章节直接点明："AI reasoning is becoming a commodity"
- "Deep AI Analysis" 章节结尾增加标注："Analysis strategies are tools, not the product"
- "Rule Packs & Knowledge System" 章节强调："Rule Packs outlast the AI engine"
- "Vision" 章节增加三阶段演进路径

### Consequences

- 短期会失去"我们的 AI 比 SAST 强"这个容易理解的卖点
- 长期建立起难以被 commodity AI 产品替代的护城河
