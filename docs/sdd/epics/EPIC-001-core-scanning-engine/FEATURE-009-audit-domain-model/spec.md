# FEATURE-009: SecAudit Domain Model — 分析方法降级、领域模型重构

> **隶属 Epic**: EPIC-001 Core Scanning Engine
> **版本**: v0.1
> **修改时间**: 2026-07-02
> **目标版本**: v0.7.0

---

## 1. Problem Statement

当前 SecAudit 将两类不同维度的概念混在同一级：

- **分析方法**: Taint Analysis, Attack Surface, Data Flow, Trust Boundary, State Machine
- **安全领域**: Authentication, Cryptography, Input Validation, Secrets Management, ...

用户必须理解并选择分析方法才能使用 SecAudit，增加了认知负担。实际上分析方法应是 AI 内部推理能力，而非用户入口。

### 具体问题

| 问题 | 表现 | 影响 |
|------|------|------|
| 概念混淆 | 17 个平铺的 audit-rules + 18 个平铺的 skills | 用户不知道选什么 |
| 分析算法暴露 | Taint Analysis 作为用户入口 | 开发者困惑 "我为什么要理解 taint analysis？" |
| Skills 膨胀 | 5 分析方法 + 12 领域 + 1 workflow = 18 个 skill | 维护成本高，扩展困难 |
| 标准映射困难 | 新增 OWASP ASVS 需要加 N 个 skill | 不可扩展 |

## 2. Scope

### In Scope

| # | 可交付 | 说明 |
|---|--------|------|
| 1 | knowledge/audit-rules/ 清理 | 删除 5 个分析方法文件 (attack-surface-analysis, data-flow-analysis, state-machine-analysis, taint-analysis, trust-boundary-analysis) |
| 2 | knowledge/audit-rules/ 新增 | 新增 information-exposure.md（用户列出的 12 个域之一，当前无对应文件） |
| 3 | skills/secaudit/ 清理 | 删除 15 个独立 skill 目录（5 分析方法 + 12 领域），仅保留 workflow-secaudit |
| 4 | commands/secaudit.md 重写 | 移除 skill 列表，简化 Step 3 路由逻辑，入口保持 /secaudit <path> <lang> |
| 5 | docs/audit-framework/ 更新 | architecture.md 和 workflow.md 反映新的领域模型 |
| 6 | manifest.json 更新 | audit-rules 计数从 17 改为 13 |

### Out of Scope

- 新增安全检测能力（本次只重构，不增）
- 修改 workflow-secaudit/SKILL.md 的 AI 推理逻辑（内部实现不变）
- 修改 secguard / secreview 架构
- 修改 internal/（Go 索引器）

## 3. 领域模型

### 最终模型

```
User 入口: /secaudit <path> <lang>

    ▼
Workflow: skills/secaudit/workflow-secaudit/SKILL.md
    │
    ├── 自动选择推理策略 (Taint Analysis / Data Flow / ...)
    │
    ▼
Knowledge: knowledge/audit-rules/{domain}.md
    │
    ▼
AI Analysis → Evidence → Findings → Report
```

### Audit Domain（产品能力）

| 域 | 文件 | 说明 |
|----|------|------|
| Authentication & Session | auth-and-session.md | 认证与会话管理 |
| Authorization | authorization.md | 权限与访问控制 |
| Cryptography | cryptography.md | 加密实现 |
| Input Validation | input-validation.md | 输入验证与注入防护 |
| Output Encoding | output-encoding.md | 输出编码与 XSS 防护 |
| Secrets Management | secrets-management.md | 密钥与凭证管理 |
| Secure Transport | secure-transport.md | 传输层安全 |
| Data Protection | data-protection.md | 数据保护与隐私 |
| Dependency Security | dependency-security.md | 依赖与供应链安全 |
| Infrastructure Hardening | infra-hardening.md | 基础设施加固 |
| Logging & Monitoring | logging-and-monitoring.md | 日志与监控 |
| HTTP Security Headers | http-security-headers.md | HTTP 安全头配置 |
| Information Exposure | information-exposure.md | 信息泄露防护（新增） |

### Analysis Method（AI 内部推理能力，不暴露给用户）

| 方法 | 说明 |
|------|------|
| Taint Analysis | 污点传播分析 |
| Data Flow Analysis | 数据流追踪 |
| Attack Surface Analysis | 攻击面识别 |
| Trust Boundary Analysis | 信任边界识别 |
| State Machine Analysis | 状态机分析 |

## 4. Success Criteria

| # | 标准 | 验证方式 |
|---|------|---------|
| 1 | knowledge/audit-rules/ 无分析方法文件 | `ls knowledge/audit-rules/` 无 attack-surface/data-flow/state-machine/taint/trust-boundary |
| 2 | knowledge/audit-rules/ 有 information-exposure.md | 文件存在 |
| 3 | skills/secaudit/ 只有 workflow-secaudit | `ls -d skills/secaudit/*/` 只输出 workflow-secaudit/ |
| 4 | commands/secaudit.md 无 skill 列表 | `grep -c "## 可用 Skills" commands/secaudit.md` = 0 |
| 5 | self-check 通过 | `bash scripts/self-check.sh` exit 0 |
| 6 | secaudit CLI 可用 | `bash scripts/dev-verify.sh` 通过 |
