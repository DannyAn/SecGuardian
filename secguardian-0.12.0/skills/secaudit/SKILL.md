---
name: secaudit
description: "★ 旗舰：完整代码库安全审计工作流 — 12 安全域深度审计，产出专业审计报告。替换传统安全顾问，年省 $50K+ 审计费用。当用户请求完整安全审计、深度代码审查、安全评估时使用。"
category: workflow
---

# 安全审计工作流

## 何时使用

当用户执行 `/secaudit <path> <language> [--focus <domain>]` 时激活。

- 无 `--focus`：执行全部 12 个审计域 phase，产出一份完整审计报告
- 有 `--focus`：只执行指定 domain 的 phase，用于团队分工/单项验证/快速迭代

## 分析方法参考

AI 在审计时根据领域自动选择分析策略。每个参考文件描述了方法的执行思路和检测模式。

```
审计域                    → 分析策略           → 参考文件
─────────────────────────────────────────────────────
Input Validation          → Taint Analysis       references/taint-analysis.md
Auth & Session            → State Machine        references/state-machine-analysis.md
Authorization             → Trust Boundary       references/trust-boundary-analysis.md
Cryptography              → Data Flow            references/data-flow-analysis.md
Secrets Management        → Data Flow            references/data-flow-analysis.md
Secure Transport          → Attack Surface       references/attack-surface-analysis.md
Data Protection           → Data Flow + Boundary references/data-flow-analysis.md
Dependency Security       → Attack Surface       references/attack-surface-analysis.md
Infrastructure Hardening  → Attack Surface       references/attack-surface-analysis.md
HTTP Security Headers     → Attack Surface       references/attack-surface-analysis.md
Logging & Monitoring      → Data Flow            references/data-flow-analysis.md
```

每个 phase 加载对应的 `.md` 参考文件，按其中的方法论执行分析。

## 前置条件

- index.json 已由 Command 层生成（含 `symbols`、`call_graph`、`alloc_free`、`lock_graph`）
- `knowledge/language-index.md` 已自动读取，获得该语言适用的所有规则清单

## 工作流

### Phase 1: 技术栈识别

从 index.json 确定：
- 开发语言和框架（如 Spring Boot、Django、Express）
- 使用的安全框架/库（Spring Security、Shiro、Django Auth）
- 数据存储类型（SQL/NoSQL/Redis 等）
- 部署架构（容器化/K8s/微服务）

### Phase 2: 输入验证审计

加载 `knowledge/audit-rules/input-validation.md`。
参考: `references/taint-analysis.md` — 追踪不可信数据从 Source 到 Sink

检查所有输入点的验证完整性：SQL 注入、命令注入、XSS、路径穿越、LDAP 注入、XML/XXE。验证参数化查询、输入净化、输出编码的覆盖范围。

### Phase 3: 认证与会话审计

加载 `knowledge/audit-rules/auth-and-session.md`。
参考: `references/state-machine-analysis.md` — 分析认证状态转换与会话生命周期

检查认证机制：密码策略、MFA、会话管理、Token 安全、OAuth/OIDC 配置、密码重置流程、session fixation 防护。

### Phase 4: 授权审计

加载 `knowledge/audit-rules/authorization.md`。
参考: `references/trust-boundary-analysis.md` — 检查用户/角色/权限边界

检查权限模型：RBAC/ABAC 实现、API 级授权检查、IDOR 防护、权限提升路径、越权测试。

### Phase 5: 密码学审计

加载 `knowledge/audit-rules/cryptography.md`。
参考: `references/data-flow-analysis.md` — 追踪密钥材料生命周期

检查加密实现：弱算法使用、密钥管理、随机数安全、TLS 配置、加密模式选择、证书验证、密码存储算法。

### Phase 6: 密钥管理审计

加载 `knowledge/audit-rules/secrets-management.md`。
参考: `references/data-flow-analysis.md` — 追踪凭证读取和传递路径

检查密钥和凭证：硬编码密码、API 密钥暴露、密钥轮换策略、密钥存储方案（环境变量/Vault/KMS）、密钥生命周期。

### Phase 7: 安全传输审计

加载 `knowledge/audit-rules/secure-transport.md`。
参考: `references/attack-surface-analysis.md` — 枚举 TLS 端点与传输入口

检查传输安全：TLS 版本、证书链验证、mTLS 配置、HSTS 头、证书固定、内部服务间传输加密。

### Phase 8: 数据保护审计

加载 `knowledge/audit-rules/data-protection.md`。
参考: `references/data-flow-analysis.md` + `references/trust-boundary-analysis.md` — 追踪敏感数据生命周期并检查访问边界

检查敏感数据：PII 识别、数据分类、加密存储、数据最小化、备份安全、数据擦除策略。

### Phase 9: 依赖安全审计

加载 `knowledge/audit-rules/dependency-security.md`。
参考: `references/attack-surface-analysis.md` — 评估第三方组件引入的攻击面

检查依赖项：已知漏洞扫描、许可证合规、依赖版本更新、供应链攻击面（恶意包、typosquatting）。

### Phase 10: 基础设施加固审计

加载 `knowledge/audit-rules/infra-hardening.md`。
参考: `references/attack-surface-analysis.md` — 识别暴露端口、服务、配置入口

检查基础设施：容器安全（Docker/K8s）、云资源配置、网络策略、最小权限原则、配置文件的敏感信息。

### Phase 11: HTTP 安全头审计

加载 `knowledge/audit-rules/http-security-headers.md`。
参考: `references/attack-surface-analysis.md` — 评估 HTTP 响应暴露面

检查 HTTP 响应头：CSP、HSTS、X-Frame-Options、X-Content-Type-Options、Referrer-Policy、Permissions-Policy。

### Phase 12: 日志与监控审计

加载 `knowledge/audit-rules/logging-and-monitoring.md`。
参考: `references/data-flow-analysis.md` — 追踪敏感数据是否流入日志

检查日志安全：敏感数据泄露风险、日志完整性、审计日志覆盖、告警配置、安全事件响应能力。

## 汇总报告

所有 phase 完成后：

1. **合并去重**：跨 phase 的相同 finding 合并
2. **严重度排序**：按 CVSS 评分从高到低排列
3. **分类索引**：按 OWASP Top 10 / CWE Top 25 分类
4. **安全评分**：`100 - (Critical×25 + High×10 + Medium×3 + Low×1)`
5. **修复路线图**：分 immediate / short-term / long-term 三阶段

## --focus 单项模式

当用户指定 `--focus <domain>` 时：

- 跳过不相关的 phase
- 只加载 `knowledge/audit-rules/{domain}.md`
- 仅执行匹配的 phase
- 输出精简报告，只包含该领域发现

用于团队分工（A 负责密码学、B 负责输入验证）、局部验证（改了一个 domain 后快速验证）、能力迭代（集中打磨单项 quality）。
