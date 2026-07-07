---
detector: system.secrets-detection
severity: critical
cwe: CWE-798
language: [c, cpp, python, java, go, javascript, typescript]
tags: [secrets, credentials, hardcoded, entropy, key, token, password]
precision: low
confidence: dynamic
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "system.system.secrets-detection",
  "type": "guard-rule",
  "namespace": "system",
  "severity": "Critical",
  "cwe": "CWE-798",
  "cvss": 9.8,
  "confidence": "dynamic",
  "precision": "low",
  "languages": [
    "c",
    "cpp",
    "python",
    "java",
    "go",
    "javascript",
    "typescript"
  ],
  "target_functions": [
    "jdbc",
    "mongodb",
    "mysql",
    "postgres",
    "redis"
  ],
  "match_patterns": [
    "AKIA[0-9A-Z]{16}                                         # → MUST: 匹配的 AWS Access Key ID 前缀模式 + 前后3行上下文",
    "ghp_[0-9a-zA-Z]{36}                                      # → MUST: 匹配的 GitHub Personal Access Token 模式",
    "github_pat_[0-9a-zA-Z_]{36,}                             # → MUST: 匹配的细粒度 GitHub PAT 模式",
    "glpat-[0-9a-zA-Z\\-]{20,}                                 # → MUST: 匹配的 GitLab PAT 模式",
    "AIza[0-9A-Za-z\\-_]{35}                                   # → MUST: 匹配的 Google API Key 前缀模式",
    "xox[baprs]-[0-9a-zA-Z\\-]+                                # → MUST: 匹配的 Slack Token 前缀模式",
    "sk_live_[0-9a-zA-Z]{24}                                  # → MUST: 匹配的 Stripe Live Secret Key 模式",
    "-----BEGIN (RSA|EC|DSA|OPENSSH) PRIVATE KEY-----         # → MUST: 匹配的 PEM Private Key 边界标记",
    "[aA][pP][iI]_?[kK][eE][yY][=:][\"']?[0-9a-zA-Z]{32,}     # → MUST: 匹配的 Generic API Key 赋值模式",
    "[tT][oO][kK][eE][nN][=:][\"']?[0-9a-zA-Z]{16,}           # → MUST: 匹配的 Generic Token 赋值模式",
    "[sS][eE][cC][rR][eE][tT][=:][\"']?[0-9a-zA-Z]{16,}       # → MUST: 匹配的 Generic Secret 赋值模式",
    "[pP][aA][sS][sS][wW]?[oO]?[rR]?[dD]?[=:][\"']?[^ &\\n]{8,}  # → MUST: 匹配的 Password 赋值模式",
    "(jdbc|mongodb|postgres|mysql|redis)://[^ \\n]+@           # → MUST: 匹配的连接字符串含嵌入式凭据",
    "DefaultEndpointsProtocol=https;AccountName=.*;AccountKey=.*  # → MUST: 匹配的 Azure 存储连接字符串",
    "[A-Za-z0-9+/=]{40,} (需上下文确认高熵)                    # → MUST: 高熵 Base64 + 熵值计算 → SHOULD: sanitizer_analysis 上下文排除"
  ],
  "exclude_patterns": [],
  "required_evidence": [
    "code_context",
    "judgment_rationale"
  ],
  "optional_evidence": [
    "sanitizer_analysis",
    "data_flow_path"
  ]
}
```
## 威胁定义 (Threat Definition)

源代码、配置文件、CI/CD 脚本或基础设施即代码（IaC）模板中包含硬编码的密钥、令牌、密码、API 密钥或连接字符串，映射 CWE-798（Use of Hard-coded Credentials）。硬编码凭据一旦进入版本控制系统（git history），即使后续删除，历史记录中仍永久存在，构成不可撤销的泄露。攻击者获取代码访问权限（源代码泄露、内部人员、依赖混淆攻击窃取 `.git` 目录）后可直接利用这些凭据访问云资源、数据库、第三方 API 或内部服务。后果包括：云账户劫持（AWS/GCP/Azure API 密钥）、数据泄露（数据库连接字符串含密码）、供应链攻击（CI/CD token 泄露）、服务冒充（JWT 签名密钥泄露）。

## 检测逻辑 (Detection Logic)

### Step 1 — 已知密钥前缀匹配

对源代码进行结构化正则匹配，搜索已知云服务和工具的密钥前缀模式。

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

### Step 2 — 高熵字符串检测

搜索长度为 40+ 字符的 Base64 编码字符串（字符集 `[A-Za-z0-9+/=]`），计算其 Shannon 熵值。高熵（>4.5）的 Base64 字符串大概率是加密密钥、签名或 token。

```bash
# 高熵字符串扫描
grep -rE '[A-Za-z0-9+/=]{40,}' --include="*.{java,py,go,js,ts,yml,yaml,properties,xml,json,env,tf}"

# 已知密钥前缀扫描
grep -rE '(api_key|apikey|secret|password|token|credential)\s*[=:]\s*["'\'']?[A-Za-z0-9_\-]{8,}' .

# git-secrets 集成
git secrets --scan -r
```

### Step 3 — 上下文语义过滤

对每个匹配进行语义分析，排除误报：
- 检查匹配所在行前后 3 行的上下文，识别是否为模板变量、测试数据、公开证书
- 检查文件路径是否在 `.gitignore` 覆盖范围内或属于 test/mock/fixture 目录
- 检查匹配字符串是否具有已知非秘密模式（`BEGIN CERTIFICATE`、Base64 编码的图片/字体/图标数据）

### Step 4 — 密钥存储安全检查

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

### Step 5 — 密钥生命周期检查

| 阶段 | 检查项 |
|------|--------|
| 生成 | 是否使用密码学安全随机源？非 `Math.random()` / `rand()` |
| 分发 | 是否通过安全通道传输？非 email/Slack/明文 |
| 存储 | 是否加密存储？非明文在代码/配置中 |
| 使用 | 是否在日志中泄露？非 `console.log(token)` |
| 轮换 | 是否有定期轮换机制？90天或更短 |
| 撤销 | 是否有紧急撤销流程？泄露时能否立即失效 |
| 销毁 | 是否安全删除？非仅 `git rm`（历史仍存在） |

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：匹配行 + 前后各 3 行源代码，完整展示密钥出现的上下文（变量赋值、配置文件键值、注释等）
      → `findings.evidence.code_context`
- [ ] **judgment_rationale**：匹配的具体正则模式名称（如 "AWS Access Key AKIA prefix"、"Generic Password assignment"）、密钥类型（API Key/Token/Password/Private Key/Connection String），以及匹配字符串的 Shannon 熵值（如适用）
      → `findings.evidence.judgment_rationale`

### 建议收集 (SHOULD)
- [ ] **sanitizer_analysis**：语义排除分析——匹配是否属于以下任一可排除类别：模板变量（`${VAR}` / `{{VAR}}`）、测试/演示数据（文件路径含 test/demo/fixture/mock）、公开证书（`BEGIN CERTIFICATE` / `PUBLIC KEY`）、Base64 编码的非秘密数据（图片/字体/图标）
      → `findings.evidence.sanitizer_analysis`
- [ ] **data_flow_path**：密钥从定义/赋值点到使用点的数据流追踪（如 `const KEY = "xxx"` → `fetch(url, { headers: { Authorization: KEY } })`），标注密钥是否仅用于本地开发或流向外部分服务
      → `findings.evidence.data_flow_path`

### 可选收集 (MAY)
- [ ] **variable_state**：匹配字符串的 Shannon 熵值（计算值）、字符串长度、字符集分布（如适用，帮助区分高熵密钥与低熵占位符）
      → `findings.evidence.variable_state`
- [ ] **call_stack**：密钥的外传路径（如通过 HTTP 请求头、日志输出、环境变量注入传递给外部系统），或 `N/A — 密钥尚未被引用，仅定义`
      → `findings.evidence.call_stack`

## 误报排除 (False Positive Exclusion)

由于本检测器依赖高熵字符串检测和正则模式匹配（非语义分析），天然存在高误报率（precision: low 是正确的设计选择——宁可多报不漏）。

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `-----BEGIN CERTIFICATE-----` / `-----BEGIN PUBLIC KEY-----` | 公开证书和公钥是有意公开的非秘密数据 | 匹配字符串包含 `BEGIN CERTIFICATE` 或 `PUBLIC KEY` 边界标记 |
| Base64 编码的图片/字体/图标资源（通常出现于 CSS/HTML/配置文件） | Data URI 或内嵌资源不是密钥：`data:image/png;base64,...`、`@font-face { src: url(data:font/woff;base64,...) }` | 上下文为 data URI 或 CSS 内嵌资源声明 |
| 模板变量/占位符：`${API_KEY}`、`{{SECRET}}`、`<%= secret %>`、`$ENV_VAR` | 模板语法中的变量引用而非实际值 | 匹配字符串嵌入在模板语法标记内（`${...}`/`{{...}}`/`<%=...%>`） |
| test/、spec/、mock/、fixture/、__tests__/ 目录下的文件 | 测试数据通常为伪造凭据，不授予实际权限 | 文件路径匹配测试目录模式，且凭据不符合已知密钥前缀（如 `AKIA`、`ghp_`） |
| 全零/全F/重复字符占位符（如 `00000000-0000-0000-0000-000000000000`、`xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`） | 明显为占位符或骨架代码 | 字符串主要由重复的单字符/模式构成，Shannon 熵值 < 2.0 |
| `.gitignore` 覆盖的文件（`.env`、`secrets.yml`、`credentials.json` 等已排除版本控制的文件） | 文件不在版本管理中，不存在泄露到 git history 的风险 | 文件名匹配 `.gitignore` 中的排除规则，且不是 CI/CD 中强制检查的文件 |
| 短字符串 < 32 字符（对通用 Base64 匹配） | 长度不足 32 的 Base64 字符串不具备足够熵值构成有效密钥 | 匹配字符串长度 < 32 且不符合已知密钥前缀（如 `ghp_`、`sk_live_` 等短 token） |
| 编译产物/构建输出目录（dist/、build/、node_modules/、vendor/） | 非源代码，通常是依赖或构建产物 | 文件路径匹配构建输出或依赖目录模式 |

## 修复指引 (Remediation Guidance)

1. **首选**：从代码中移除硬编码凭据，迁移到密钥管理服务（AWS Secrets Manager / Azure Key Vault / HashiCorp Vault / GCP Secret Manager），运行时通过 SDK 动态获取。对于 K8s 环境，使用 External Secrets Operator 同步到 K8s Secret。
2. **次选**：将凭据移至环境变量（通过 CI/CD secrets 注入），在代码中通过 `process.env.SECRET` / `os.getenv("SECRET")` 读取。确保 `.env` 文件已加入 `.gitignore`。（环境变量仍有容器逃逸/调试端点泄露风险，不是最终方案。）
3. **最低要求**：如因遗留系统限制暂时无法迁移，至少：(a) 将凭据移至单独的配置文件并添加到 `.gitignore`；(b) 使用 `git filter-branch` 或 `bfg-repo-cleaner` 从 git 历史中清除已提交的凭据；(c) 立即在云平台轮换已泄露的凭据；(d) 启用 git-secrets 或 detect-secrets pre-commit hook 防止再次提交。

## 检测模式汇总 (Detection Pattern Summary)

```
# === MATCH (触发检测) ===
AKIA[0-9A-Z]{16}                                         # → MUST: 匹配的 AWS Access Key ID 前缀模式 + 前后3行上下文
ghp_[0-9a-zA-Z]{36}                                      # → MUST: 匹配的 GitHub Personal Access Token 模式
github_pat_[0-9a-zA-Z_]{36,}                             # → MUST: 匹配的细粒度 GitHub PAT 模式
glpat-[0-9a-zA-Z\-]{20,}                                 # → MUST: 匹配的 GitLab PAT 模式
AIza[0-9A-Za-z\-_]{35}                                   # → MUST: 匹配的 Google API Key 前缀模式
xox[baprs]-[0-9a-zA-Z\-]+                                # → MUST: 匹配的 Slack Token 前缀模式
sk_live_[0-9a-zA-Z]{24}                                  # → MUST: 匹配的 Stripe Live Secret Key 模式
-----BEGIN (RSA|EC|DSA|OPENSSH) PRIVATE KEY-----         # → MUST: 匹配的 PEM Private Key 边界标记
[aA][pP][iI]_?[kK][eE][yY][=:]["']?[0-9a-zA-Z]{32,}     # → MUST: 匹配的 Generic API Key 赋值模式
[tT][oO][kK][eE][nN][=:]["']?[0-9a-zA-Z]{16,}           # → MUST: 匹配的 Generic Token 赋值模式
[sS][eE][cC][rR][eE][tT][=:]["']?[0-9a-zA-Z]{16,}       # → MUST: 匹配的 Generic Secret 赋值模式
[pP][aA][sS][sS][wW]?[oO]?[rR]?[dD]?[=:]["']?[^ &\n]{8,}  # → MUST: 匹配的 Password 赋值模式
(jdbc|mongodb|postgres|mysql|redis)://[^ \n]+@           # → MUST: 匹配的连接字符串含嵌入式凭据
DefaultEndpointsProtocol=https;AccountName=.*;AccountKey=.*  # → MUST: 匹配的 Azure 存储连接字符串
[A-Za-z0-9+/=]{40,} (需上下文确认高熵)                    # → MUST: 高熵 Base64 + 熵值计算 → SHOULD: sanitizer_analysis 上下文排除

# === EXCLUDE (不报告) ===
→ -----BEGIN CERTIFICATE----- / -----BEGIN PUBLIC KEY-----      # 公开证书/公钥
→ data:image/;base64, 或 CSS url(data:font/;base64,)            # Base64 内嵌资源
→ ${VAR} / {{VAR}} / <%= var %> 模板变量占位符                   # 模板语法非实际值
→ 路径匹配 test/ / spec/ / mock/ / fixture/ / __tests__/       # 测试/演示数据
→ 全零/全F/同字符占位符（熵值 < 2.0）                            # 骨架代码占位符
→ .gitignore 中声明的文件（.env / secrets.yml 等）               # 已被版本控制排除
→ 字符串长度 < 32 且不匹配已知密钥前缀                            # 低熵短字符串
→ 路径匹配 dist/ / build/ / node_modules/ / vendor/            # 构建产物/依赖
→ Settings.API_KEY = "<your_api_key_here>"                      # 文档示例（语义排除）
```
