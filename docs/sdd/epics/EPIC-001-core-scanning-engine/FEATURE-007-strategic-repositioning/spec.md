# FEATURE-007: Strategic Repositioning — Four Gates + /secfix

> **隶属 Epic**: EPIC-001 Core Scanning Engine
> **版本**: v0.1 (Final)
>
> **修改时间**: 2026-06-30
> **目标版本**: v0.6.0

---

## 1. Problem Statement

### 1.1 定位危机

项目 README 的核心卖点是"AI 比传统 SAST 更聪明"（如旧版标语"年省 $50K+ 安全顾问费用"）。但与 ChatGPT 的深度讨论揭示了一个致命问题：

> **AI 推理能力正在加速商品化。12 个月后，所有开发工具都有同等水平的代码推理能力。"AI 更聪明"的叙事寿命很短。**

这意味着目前的定位没有长期防御力。当 ChatGPT、Cursor、Claude 等产品都具备了类似的代码推理能力，"我们的 AI 更智能"就不再是差异化卖点。

### 1.2 三个产品表达不一致

| 产品 | 旧 README 表述 | 问题 |
|------|---------------|------|
| SecGuard | "AI 引导的代码漏洞发现" | 定位模糊，与 SAST 无区别 |
| SecReview | "安全编码规范审查" | 定位太低，被理解为 linter |
| SecAudit | "AI 深度安全审计（旗舰）" | 卖点集中在"比 SAST 聪明"上 |

三个产品被表述为"不同级别的扫描"，而非"SDLC 不同阶段的不同工作"。

### 1.3 工作流不完整

```
旧:  Coding ──→ /secguard ──→ /secaudit
     (忽略: PR review、fix remediation、release gate)
```

缺少 PR 阶段的 Code Review（/secreview）和修复加速（/secfix）。

---

## 2. Scope

### In Scope

| # | 可交付 | 说明 |
|---|--------|------|
| 1 | README.md 英文重写 | 从中文改为英文，从"卖 AI 能力"改为"卖 Workflow + Rule Packs + Outputs" |
| 2 | /secreview 命令微重构 | 从"安全编码规范检视"改为 "AI Security Code Review for PRs" |
| 3 | /secreview 5 语言 SKILL.md 重构 | 对应的 cpp/go/java/python/js 技能文件 |
| 4 | /secfix 命令定义 | 新增第四门命令，定位为 AI Remediation |
| 5 | 四门工作流设计 | secguard → secreview → secfix → secaudit |
| 6 | 设计决策文档化 | brainstorm-log.md 补充 + FEATURE-007 完整 SDD 包 |
| 7 | 战略叙事升级 | Why SecGuardian → Deep AI Analysis → Rule Packs → Vision 全线更新 |

### Out of Scope

- /secaudit 命令重构（等待用户提供新设计方案）
- /secfix MVP 实现（patch 文件生成逻辑）
- 增加 detector 数量（已有 67 个，此次不动）
- manifest.json / extensions/ 文件变更（本次无 schema 变化）
- CI 管线变更

---

## 3. Success Criteria

| # | 标准 | 验证方式 |
|---|------|---------|
| 1 | README 无中文内容 | `grep -c '[\x{4e00}-\x{9fff}]' README.md` = 0 |
| 2 | 四门工作流在 README 中可读 | 从 "Why SecGuardian" 到 "Vision" 完整叙事过渡自然 |
| 3 | /secreview 命令定位从"规范检视"变为"AI Security Code Review" | description 字段包含 "Security Code Review" |
| 4 | /secreview 5 个 SKILL 文件更新 | 每个文件 description 含 "AI Code Security Review"，vs secguard 表已改为 SDLC stage 差异 |
| 5 | /secfix 命令定义存在 | `commands/secfix.md` 存在且包含用法、输出格式、patch 规范 |
| 6 | SDD Feature Package 完整 | spec.md + adr.md + plan.md + progress.md 四件套齐全 |
| 7 | self-check 通过（仅预存 gemini/*toml 异常可接受） | `bash scripts/self-check.sh` exit code 0 |

---

## 4. 明确不做的决策

> 以下决策在讨论中被明确提出并否决，记录以供回溯。

| 决策 | 否决原因 |
|------|---------|
| /secfix 命名为 /fixit | 语气不像安全工具，不匹配 sec- 前缀规范 |
| /secfix 命名为 /secremediate | 4 音节太长，破坏命令简洁性 |
| /secfix 作为独立第四 Gate | fix 是"动作"而非"决策点"，不应对应一个独立的 Gate |
| 增加第 18/19/20 个 Skill | ChatGPT 明确指出"能力线性增长不如产品抽象升级"，本次聚焦战略定位 |
| 保留中文 README | 英文是全球化开源/企业 AD 的必要条件 |
| 继续卖"AI 比 SAST 聪明" | ChatGPT 分析：该叙事生命周期 < 12 个月 |

---

## 5. 相关文档

- `docs/sdd/brainstorm-log.md` — 完整讨论记录（含 ChatGPT 对话摘要）
- `README-EN.md` — ChatGPT 讨论产物，临时愿景文件（存留作参考）
- `README.md` — 本次重写目标文件
- `commands/secreview.md` — 微重构后的命令定义
- `commands/secfix.md` — 新增命令定义

---

## 6. 演进路径

本项目整体按以下路径演进，本次 FEATURE-007 完成第 1 阶段：

| 阶段 | 定位 | 时间 |
|------|------|------|
| ✅ **AI Security Scanner** | 单次扫描 + 发现 | v0.1–v0.5 |
| 🔄 **AI Security Workflow** | 四门 SDLC 管线 | **v0.6 (本次)** |
| ⬜ **AI Security Governance Platform** | 可配置 Rule Packs + 审计证据链 | v0.7+ |
