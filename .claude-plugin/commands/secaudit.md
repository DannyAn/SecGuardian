---
description: AI 深度安全审计 — 17 项专业安全分析
---

# /secaudit — AI 深度安全审计

针对安全专项问题进行深度审计分析。自动识别用户意图，路由到对应的分析或领域审计 skill。

## 可用分析类 Skills (5)

| Skill | 描述 |
|-------|------|
| taint-analysis | 污点分析 — 追踪不可信数据到危险操作 |
| data-flow-analysis | 数据流分析 — 敏感数据完整流向追踪 |
| attack-surface-analysis | 攻击面分析 — 入口点枚举+风险评估 |
| state-machine-analysis | 状态机分析 — 状态转换安全审计 |
| trust-boundary-analysis | 信任边界分析 — 跨边界安全控制 |

## 可用领域审计 Skills (12)

| Skill | 描述 |
|-------|------|
| auth-and-session | 认证与会话管理 — OWASP ASVS |
| authorization | 授权与访问控制 — 越权/IDOR |
| cryptography | 密码学安全 — 算法/密钥/随机数 |
| input-validation | 输入验证 — OWASP Top 10 注入 |
| data-protection | 数据保护 — 敏感数据生命周期 |
| secrets-management | 密钥管理 — 凭证存储/轮换 |
| secure-transport | 安全传输 — TLS/AZURE 配置 |
| http-security-headers | HTTP 安全头 — CSP/HSTS |
| logging-and-monitoring | 日志与监控 — 安全事件追溯 |
| output-encoding | 输出编码 — XSS/注入防护 |
| dependency-security | 依赖安全 — 已知漏洞/供应链 |
| infra-hardening | 基础设施加固 — 容器/K8s/云资源 |

## 执行

1. 匹配用户指定的 skill 名称
2. 加载 `skills/secaudit-<name>/SKILL.md`
3. 按 skill 中定义的审计流程执行
4. 遵循 Scan Output Protocol 1.0 输出审计报告
