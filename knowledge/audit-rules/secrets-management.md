---
name: secrets-management
description: 审计密钥、凭证、Token等敏感信息的管理方式，检测硬编码、泄露、不当存储和缺失轮换等安全风险。当用户请求密钥管理审计、硬编码凭证检测、密钥泄露扫描、凭证轮换审查、密钥存储安全时使用。
category: domain
topic: [system]
severity: Medium
cwe: CWE-000
cvss: 5.5
---

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`（含 `symbols.functions`、`call_graph.edges`、`files`）。审计时优先利用符号表和调用图定位目标，追踪数据流路径。
> **输出**: 遵循 `knowledge/protocols/scan-output.md`（报告格式：report.md + results.sarif + summary.json）。


# 密钥管理安全审计

## 审计概览

密钥管理是安全体系中最核心也最容易出问题的环节。审计覆盖：

> **检测规则**: 详细检测逻辑见 [`../../knowledge/guard-rules/secrets-detection.md`](../../knowledge/guard-rules/secrets-detection.md)。
- **硬编码检测**：代码和配置中是否包含明文凭证
- **存储安全**：密钥的存储方式和访问控制
- **生命周期管理**：密钥的生成、分发、轮换、撤销
- **使用安全**：密钥在代码中的使用方式是否安全

## 审计流程

### Phase 1: 密钥资产发现

搜索代码仓库中所有可能的密钥形态：

```bash
# 高熵字符串 (可能的 API Key / Token)
grep -rE '[A-Za-z0-9+/=]{40,}' --include="*.{java,py,go,js,yml,yaml,properties,xml,json}"

# 已知密钥前缀
grep -rE '(sk-|pk-|AKIA|eyJ|-----BEGIN|api_key|apikey|api-key)' .

# 变量名提示
grep -rE '(password|passwd|secret|token|key|private_key|access_key)\s*=' .

# 配置文件
find . -name '*.env' -o -name '*.properties' -o -name 'application*.yml' -o -name 'secrets.yaml'
```

### Phase 2: 检查清单

#### 2.1 硬编码检测

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 代码中是否有明文密钥 | grep 高熵字符串 + 变量名匹配 |
| [C] | 配置文件中是否有明文密码 | 检查 `.env`、`application.properties`、`config.yml` |
| [C] | Git 历史中是否有密钥 | `git log -p` + `git secrets` / `truffleHog` 扫描 |
| [H] | CI/CD 日志中是否打印了密钥 | 检查 CI 构建日志输出 |
| [H] | 测试代码中是否有真实密钥 | 测试文件中的 "fake" 密钥可能被复制了真实值 |
| [H] | Docker 镜像层中是否有密钥 | `docker history` 检查是否有 `COPY .env` 等操作 |

#### 2.2 密钥存储

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [C] | 是否使用了密钥管理服务 | KMS / Vault / Secrets Manager vs 环境变量 |
| [H] | 环境变量是否安全 | K8s Secrets 默认不加密 etcd 存储 |
| [H] | 是否有密钥访问控制 | 谁/哪个服务可以读取密钥 |
| [H] | 是否有密钥访问审计日志 | 每次密钥使用是否记录 |
| [M] | 密钥是否区分环境 | dev/staging/prod 是否使用不同密钥 |

#### 2.3 密钥生命周期

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [H] | 密钥是否有轮换机制 | 检查是否有定期轮换逻辑或脚本 |
| [H] | 密钥轮换是否支持零停机 | 检查是否支持多密钥同时有效 |
| [H] | 泄露密钥是否有吊销机制 | 是否有紧急吊销流程 |
| [H] | 密钥生成是否使用安全随机数 | 检查密钥/Token 生成的随机源 |
| [M] | 旧密钥是否有安全删除机制 | KMS 中的密钥删除是否有恢复期保护 |

#### 2.4 密钥使用安全

| 优先级 | 检查项 | 审计方法 |
|--------|--------|---------|
| [H] | 密钥是否在内存中长时间驻留 | 使用后是否 `memset`/`explicit_bzero` 清零 |
| [H] | 密钥是否出现在调试日志中 | 检查 debug 模式下是否打印密钥值 |
| [H] | 密钥是否通过安全通道传输 | API Key 是否只在 HTTPS 中传输 |
| [M] | 密钥是否通过 URL 传递 | 检查 GET 请求中是否包含 API Key |

### Phase 3: 常见漏洞模式

#### 模式 1: 代码中的硬编码密钥

```java
// BAD: 硬编码密钥
private static final String AWS_SECRET_KEY = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY";
private static final String JWT_SECRET = "my-secret-key-12345";

// GOOD: 运行时从安全存储加载
private String getAwsSecretKey() {
    return secretsManager.getSecret("aws/secret-key");
}
```

#### 模式 2: Git 历史中的密钥

```bash
# 危险操作: 从代码中删除密钥后提交，但历史中仍存在
git log -p | grep -E 'SECRET|PASSWORD|API_KEY'

# 搜索已删除的文件
git log --all --full-history -- '**/credentials.*' '**/.env'

# 检测工具
truffleHog --regex --entropy=True <repo_url>
git secrets --scan-history
```

#### 模式 3: 环境变量泄露

```dockerfile
# BAD: 构建时环境变量固化在镜像层中
ARG DATABASE_PASSWORD
RUN echo $DATABASE_PASSWORD > /etc/app/db.conf
# docker history 可看到 ARG 的值!

# GOOD: 运行时注入
# docker run -e DATABASE_PASSWORD=xxx
# 或使用 K8s Secrets + Volume Mount
```

#### 模式 4: K8s Secrets 不安全

```yaml
# BAD: K8s Secret 默认只是 base64 编码（不是加密!）
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
data:
  password: cGFzc3dvcmQxMjM=  # echo cGFzc3dvcmQxMjM= | base64 -d → password123

# GOOD: 使用 Sealed Secrets / External Secrets Operator / Vault Injector
# 或启用 etcd encryption at rest
```

### Phase 4: 密钥泄露后的补救

```
1. 立即轮换泄露的密钥
2. 审计密钥使用日志，评估影响范围
3. 从 Git 历史中清除：
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch path/to/secret-file" \
     --prune-empty --tag-name-filter cat -- --all
4. 检查是否有攻击者利用泄露密钥的痕迹
5. 更新密钥管理策略，防止再次发生
```

### Phase 5: 输出格式

```markdown
## 密钥管理审计报告

### 资产发现: 23 个密钥/凭证

| 类型 | 数量 | 存储方式 |
|------|------|---------|
| API Key | 8 | 3 个硬编码, 5 个环境变量 |
| 数据库密码 | 4 | 配置文件 (明文!) |
| JWT Secret | 2 | 代码 + K8s Secret |
| TLS 私钥 | 3 | KMS |
| SSH Key | 2 | 文件系统 |
| 云服务凭证 | 4 | IAM Role (安全) |

### 发现清单

#### [C-01] GitHub Actions Secret 日志泄露
- CI Job 中 `echo ${{ secrets.DATABASE_URL }}` 将数据库连接串（含密码）输出到公开日志

#### [C-02] 生产数据库密码硬编码
- 文件: src/main/resources/application-prod.properties
- 内容: spring.datasource.password=prod123!
```
