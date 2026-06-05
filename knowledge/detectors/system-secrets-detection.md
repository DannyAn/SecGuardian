---
detector: secrets-detection
severity: critical
cwe: CWE-798
language: [c, cpp, python, java, go, javascript]
tags: [secrets, credentials, hardcoded, entropy]
---

# 密钥检测模式

## 高熵字符串检测

### 正则模式速查

| 密钥类型 | 正则模式 | 示例前缀 |
|---------|---------|---------|
| AWS Access Key | `AKIA[0-9A-Z]{16}` | `AKIA` |
| AWS Secret Key | `[0-9a-zA-Z/+]{40}` | — |
| GitHub Token | `ghp_[0-9a-zA-Z]{36}` | `ghp_` |
| GitHub PAT | `github_pat_[0-9a-zA-Z_]{36,}` | `github_pat_` |
| GitLab PAT | `glpat-[0-9a-zA-Z\-]{20,}` | `glpat-` |
| Google API Key | `AIza[0-9A-Za-z\-_]{35}` | `AIza` |
| Google OAuth | `[0-9]+-[0-9A-Za-z_]{32}\.apps\.googleusercontent\.com` | — |
| Slack Token | `xox[baprs]-[0-9a-zA-Z\-]+` | `xoxb-`, `xoxp-` |
| Stripe Secret | `sk_live_[0-9a-zA-Z]{24}` | `sk_live_` |
| Stripe Test | `sk_test_[0-9a-zA-Z]{24}` | `sk_test_` |
| JWT Token | `eyJ[0-9a-zA-Z\-_=]+\.[0-9a-zA-Z\-_=]+\.?[0-9a-zA-Z\-_=]*` | `eyJ` |
| Private Key (PEM) | `-----BEGIN (RSA\|EC\|DSA\|OPENSSH) PRIVATE KEY-----` | — |
| Generic API Key | `[aA][pP][iI]_?[kK][eE][yY][=:]["']?[0-9a-zA-Z]{32,}` | `api_key=` |
| Generic Token | `[tT][oO][kK][eE][nN][=:]["']?[0-9a-zA-Z]{16,}` | `token=` |
| Generic Secret | `[sS][eE][cC][rR][eE][tT][=:]["']?[0-9a-zA-Z]{16,}` | `secret=` |
| Generic Password | `[pP][aA][sS][sS][wW]?[oO]?[rR]?[dD]?[=:]["']?[^ &\n]{8,}` | `password=` |
| Connection String | `(jdbc\|mongodb\|postgres\|mysql\|redis)://[^ \n]+@` | — |
| Azure Connection | `DefaultEndpointsProtocol=https;AccountName=.*;AccountKey=.*` | — |
| Generic Base64 | `[A-Za-z0-9+/=]{40,}` (需要上下文确认) | — |

### 扫描命令

```bash
# 高熵字符串扫描
grep -rE '[A-Za-z0-9+/=]{40,}' --include="*.{java,py,go,js,yml,yaml,properties,xml,json,env}"

# 已知密钥前缀扫描
grep -rE '(api_key|apikey|secret|password|token|credential)\s*[=:]\s*["'\'']?[A-Za-z0-9_\-]{8,}' .

# git-secrets 集成
git secrets --scan -r
```

## 密钥存储安全检查

| 存储方式 | 风险等级 | 问题 |
|---------|---------|------|
| 源代码硬编码 | 🔴 Critical | `git log` 永久记录 |
| 配置文件 (未加密) | 🔴 Critical | 误提交到版本控制 |
| 环境变量 | 🟡 Acceptable | 需确保容器/platform 安全 |
| `.env` 文件 | 🔴 Critical | 常被误提交，需 `.gitignore` |
| CI/CD 变量 | 🟡 Acceptable | 需检查流水线访问权限 |
| 密钥管理服务 (KMS/AKV/Vault) | 🟢 Best | 集中管理 + 审计 + 轮换 |
| Kubernetes Secrets | 🟡 Acceptable | 默认 base64 非加密，需 etcd 加密 |
| Helm Values | 🔴 Critical | 常被提交到仓库 |
| Dockerfile ENV | 🔴 Critical | `docker history` 可见 |

## 密钥生命周期检查

| 阶段 | 检查项 |
|------|--------|
| 生成 | 是否使用密码学安全随机源？非 `Math.random()` / `rand()` |
| 分发 | 是否通过安全通道传输？非 email/Slack/明文 |
| 存储 | 是否加密存储？非明文在代码/配置中 |
| 使用 | 是否在日志中泄露？非 `console.log(token)` |
| 轮换 | 是否有定期轮换机制？90天或更短 |
| 撤销 | 是否有紧急撤销流程？泄露时能否立即失效 |
| 销毁 | 是否安全删除？非仅 `git rm`（历史仍存在） |
