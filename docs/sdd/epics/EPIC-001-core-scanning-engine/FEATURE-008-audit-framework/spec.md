# FEATURE-008: Audit Framework — Rule Pack 架构与基础实现

> **隶属 Epic**: EPIC-001 Core Scanning Engine
> **版本**: v0.1 (MVP)
>
> **修改时间**: 2026-06-30
> **目标版本**: v0.6.0

---

## 1. Problem Statement

### 1.1 SecAudit 当前的架构瓶颈

**现状**: SecAudit = 18 个平铺的 Markdown skill 文件。AI Agent 按 `skills/secaudit/*/SKILL.md` 逐个加载执行。

问题：
1. **技能不可分组**：无法表达"我想跑 OWASP ASVS 标准"或"跑公司安全红线"——所有 skill 是扁平的
2. **无法组合/选择**：AI Agent 必须加载全部 18 个 skill，无法按标准筛选
3. **技能与标准无映射**：cryptography skill 同时覆盖 OWASP ASVS V6、PCI DSS 4.1、NIST SP 800-175b，但没有任何地方记录这种映射
4. **难以扩展**：增加一个企业安全基线需要再加 N 个平铺 skill，而不是一组可配置的规则

### 1.2 ChatGPT 的建议

> 建议增加 `audit-framework/` 目录，包含：
> - `rulepacks/` — 按标准分组的可插拔审计规则（owasp-asvs/, company-redline/, pci-dss/ 等）
> - `engine/` — 框架核心
> - `templates/` — 输出模板
> - `reporters/` — 输出格式生成器

愿景 CLI：
```
/secaudit --rulepack secguardian          ← 内置默认
/secaudit --rulepack company-redline-v3    ← 企业安全红线
/secaudit --rulepack owasp-asvs            ← OWASP ASVS
/secaudit --rulepack pci-dss               ← PCI DSS
```

### 1.3 本次 MVP 范围

> 先打基础，不追求完美。建立框架骨架 + 迁移当前 17 个审计域为一个 rule pack。

---

## 2. Scope

### In Scope

| # | 可交付 | 说明 |
|---|--------|------|
| 1 | `audit-framework/` 目录骨架 | rulepacks/ + engine/ + templates/ + reporters/ 四个子目录 |
| 2 | 内置 secguardian rule pack | `pack.json` + 规则索引，引用当前 `knowledge/audit-rules/` 中的规则 |
| 3 | 规则与标准的映射 | 每个 audit rule 在 pack.json 中标注覆盖的 OWASP ASVS 章节和 CWE |
| 4 | `/secaudit --rulepack` CLI | 支持 `--rulepack` 参数选择审计规则包 |
| 5 | engine/README.md | 文档化 AI Agent 如何执行 rule pack |
| 6 | templates/README.md | 文档化报告模板结构 |
| 7 | reporters/README.md | 文档化输出格式扩展点 |
| 8 | `commands/secaudit.md` 更新 | 反映新框架架构 |

### Out of Scope

- 移除 `knowledge/audit-rules/` 中的旧规则文件（保持向后兼容）
- 实现独立的 Rule Pack 编译/验证工具
- 非内置 Rule Pack（owasp-asvs/, company-redline/, pci-dss/ 等——留作未来扩展）
- /secfix 的 patch 生成集成
- `engine/` 的独立可执行代码（AI Agent 仍然是执行引擎）

---

## 3. Success Criteria

| # | 标准 | 验证方式 |
|---|------|---------|
| 1 | `audit-framework/` 存在且包含 4 个子目录 | `ls audit-framework/` 输出 rulepacks/ engine/ templates/ reporters/ |
| 2 | `audit-framework/rulepacks/secguardian/pack.json` 存在 | 文件可读，JSON 格式合法，包含 17 条 rule 条目 |
| 3 | 每条 audit rule 有 OWASP ASVS 映射 | `grep -c "owasp-asvs" audit-framework/rulepacks/secguardian/pack.json` = 17 |
| 4 | `commands/secaudit.md` 描述 --rulepack 参数 | `grep --rulepack commands/secaudit.md` 有输出 |
| 5 | self-check 通过 | `bash scripts/self-check.sh` exit code 0（仅预存异常） |
| 6 | 旧 `knowledge/audit-rules/` 仍可用 | `ls knowledge/audit-rules/` 仍有 17 个文件 |

---

## 4. 架构概览

```
audit-framework/
├── README.md                        ← 框架概览
│
├── rulepacks/                        ← 可插拔规则包
│   ├── README.md                     ← 如何编写自定义 Rule Pack
│   │
│   └── secguardian/                  ← 内置默认 Rule Pack
│       ├── pack.json                 ← 清单：元数据 + 规则索引 + 标准映射
│       └── rules/                    ← 规则文件（从 knowledge/audit-rules/ 迁移而来）
│           ├── authentication-and-session.md
│           ├── authorization.md
│           ├── cryptography.md
│           ├── input-validation.md
│           ├── output-encoding.md
│           ├── secret-management.md
│           ├── secure-transport.md
│           ├── data-protection.md
│           ├── dependency-security.md
│           ├── information-exposure.md
│           ├── logging-and-audit.md
│           ├── infrastructure-hardening.md
│           ├── attack-surface-analysis.md
│           ├── taint-analysis.md
│           ├── data-flow-analysis.md
│           ├── state-machine-analysis.md
│           ├── trust-boundary-analysis.md
│           └── http-security-headers.md
│
├── engine/                           ← 执行引擎（文档 + AI Agent）
│   └── README.md                     ← AI Agent 执行规则的标准流程
│
├── templates/                        ← 报告模板
│   └── README.md                     ← 模板格式说明
│
└── reporters/                        ← 输出格式扩展点
    └── README.md                     ← 如何添加新的输出格式
```

---

## 5. 相关文档

- `docs/sdd/brainstorm-log.md` — 讨论记录
- `FEATURE-007-strategic-repositioning/` — 前序战略 repositioning 工作
- `knowledge/audit-rules/` — 当前审计规则源（保持向后兼容）
- `commands/secaudit.md` — 本次更新的命令定义
