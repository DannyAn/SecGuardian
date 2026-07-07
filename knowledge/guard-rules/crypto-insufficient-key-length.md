---
detector: insufficient-key-length
severity: medium
cwe: CWE-326
cvss: 5.5
language: [c, cpp, java, python, go, js]
tags: [crypto, key-size, configuration]
precision: high
confidence: dynamic
target_functions: [bcrypt_gensalt, generate_key_ex, generate_parameters_ex, new_by_curve_name]
match_patterns: []
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

加密密钥长度不足——如RSA 1024（已可被破解）、EC P-192（非安全曲线）、PBKDF2 低迭代次数。NIST SP 800-57 和 BSI TR-02102 定义了最低安全强度（至少 128-bit security）。

**核心原则：RSA ≥ 2048 / ECC ≥ P-256 / AES ≥ 128 / HMAC ≥ 256。不满足最低标准的密钥参数必须报告。**

## 检测逻辑 (Detection Logic)

### Step 1: 搜索密钥生成

| 算法 | 最低安全位 | 危险值 |
|------|----------|--------|
| RSA | 2048 | < 2048 位 (如 1024, 512) |
| DH | 2048 | < 2048 位 |
| DSA | 2048 | < 2048 位 |
| ECDSA/ECDH | 256 (P-256) | < 256 位曲线 |
| AES | 128 | 未达标 |
| HMAC | 256 | < 128 位 |

### Step 2: 危险代码模式

```c
// BAD: RSA 1024 位
RSA_generate_key_ex(rsa, 1024, e, NULL);

// BAD: DH 1024 位
DH_generate_parameters_ex(dh, 1024, DH_GENERATOR_2, NULL);

// BAD: EC 弱曲线
EC_KEY_new_by_curve_name(NID_secp192r1);  // 192 位曲线
EC_KEY_new_by_curve_name(NID_X9_62_prime192v1);

// BAD: AES-128 在某些场景不足
// (虽然 AES-128 仍被 NIST 认可，敏感数据应使用 AES-256)
```

### Step 3: 密钥派生参数

```c
// BAD: PBKDF2 迭代次数不足
PKCS5_PBKDF2_HMAC(password, len, salt, salt_len, 1000, ...);

// GOOD: 至少 100,000 次 (推荐)
PKCS5_PBKDF2_HMAC(password, len, salt, salt_len, 100000, ...);

// BAD: bcrypt cost 过低
char salt[BCRYPT_HASHSIZE];
bcrypt_gensalt(5, salt);         // cost=5 太低
// 推荐 cost >= 12
```

## 修复指引 (Remediation)

| 算法 | 最低安全参数 |
|------|------------|
| RSA | ≥ 2048 bits（推荐 3072） |
| DH/ElGamal | ≥ 2048 bits |
| ECDSA/ECDH | ≥ P-256（推荐 P-384） |
| AES | ≥ 128 bits（推荐 256） |
| HMAC | ≥ 256 bits |
| PBKDF2 | ≥ 100,000 次迭代 |
| bcrypt | cost ≥ 12 |

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：密钥生成调用及参数值
      → findings.evidence.code_context
- [ ] **judgment_rationale**：参数值与最低安全标准的对比
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：密钥参数的来源追溯
      → findings.evidence.data_flow_path
- [ ] **call_stack**：密钥生成函数的调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：密钥长度/曲线类型/迭代次数
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否有条件编译或配置覆盖
      → findings.evidence.sanitizer_analysis

## 误报排除 (False Positive Exclusion)

| 场景 (Scenario) | 排除依据 (Exclusion Basis) | 证据要求 (Evidence Required) |
|------|------|------|
| 非对称算法 3072+ / 曲线 384+ | 已超标 | 确认密钥参数配置值 ≥3072 bits 或曲线 ≥P-384 |
| 内部测试/非生产代码 | 无安全影响 | 确认代码路径仅存在于测试文件或非生产构建中 |
| 与外部系统兼容的协议限定 | 有文档记录 | 提供系统间兼容性文档，明确记载密钥长度限制及原因 |

## 检测模式汇总 (Detection Pattern Summary)

### 匹配模式 (MATCH)

```
# RSA/DH 短密钥
RSA_generate_key.*1024|RSA_generate_key.*512
→ evidence: code_context (密钥生成调用参数值)
DH_generate_parameters.*1024|DH_generate_parameters.*512
→ evidence: code_context (DH参数长度值)

# 弱 EC 曲线
NID_secp192|NID_X9_62_prime192|NID_secp160|NID_sect163
→ evidence: variable_state (曲线标识符)

# 低迭代 PBKDF2
PKCS5_PBKDF2_HMAC.*[0-9]{1,3}\)  # < 10000 次迭代
→ evidence: variable_state (迭代次数值)
```

### 排除模式 (EXCLUDE)

```
RSA_generate_key.*(204[89]|3072|4096|8192)
→ 密钥长度已达标，无需报告
NID_secp256|NID_secp384|NID_secp521|NID_X9_62_prime256
→ 安全曲线，无需报告
PKCS5_PBKDF2_HMAC.*[0-9]{5,}\)
→ 迭代次数 ≥100000，无需报告
```
