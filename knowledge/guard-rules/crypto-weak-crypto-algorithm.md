---
detector: weak-crypto-algorithm
severity: high
cwe: CWE-327
language: [c, cpp, java, python, go, js]
tags: [crypto, algorithm, deprecated]
precision: very-high
confidence: dynamic
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "crypto.weak-crypto-algorithm",
  "type": "guard-rule",
  "namespace": "crypto",
  "severity": "High",
  "cwe": "CWE-327",
  "cvss": 7.5,
  "confidence": "dynamic",
  "precision": "very-high",
  "languages": [
    "c",
    "cpp",
    "java",
    "python",
    "go",
    "js"
  ],
  "target_functions": [
    "_des",
    "_ecb",
    "_md5",
    "_rc4",
    "aes_128_ecb",
    "bf_cbc",
    "call_stack",
    "code_context",
    "crypto",
    "generate_parameters_ex",
    "hashlib",
    "judgment_rationale",
    "key",
    "md5",
    "password",
    "random",
    "session",
    "set_key",
    "token",
    "variable_state"
  ],
  "match_patterns": [
    "MD5_|EVP_md5|SHA1_|EVP_sha1                            # C/C++ 弱哈希",
    "MessageDigest\\.getInstance\\(\"MD5|MessageDigest\\.getInstance\\(\"SHA-1  # Java 弱哈希",
    "hashlib\\.md5\\(|hashlib\\.sha1\\(                           # Python 弱哈希",
    "crypto/md5|crypto/sha1                                    # Go 弱哈希",
    "CryptoJS\\.MD5|CryptoJS\\.SHA1                              # JavaScript 弱哈希",
    "DES_|EVP_des|RC4_|EVP_rc4|EVP_bf_                       # C/C++ 弱加密",
    "Cipher\\.getInstance\\(\"DES|Cipher\\.getInstance\\(\"RC4      # Java 弱加密",
    "Crypto\\.Cipher\\.DES|Crypto\\.Cipher\\.ARC4                 # Python 弱加密",
    "EVP_.*_ecb|Cipher\\.getInstance.*ECB                      # ECB模式不安全",
    "DH_generate_parameters.*512|DH_generate_parameters.*1024 # DH 密钥过短",
    "rand\\(\\)|Math\\.random\\(\\)|random\\.randint                  # 安全上下文中使用非密码学随机"
  ],
  "exclude_patterns": [],
  "required_evidence": [
    "code_context",
    "judgment_rationale"
  ],
  "optional_evidence": [
    "data_flow_path",
    "call_stack"
  ]
}
```
## 威胁定义 (Threat Definition)

使用已被证明不安全或过时的加密算法、哈希函数、随机数生成器。按用途分类：弱哈希（MD2/MD4/MD5/SHA-1）、弱加密（DES/3DES/RC2/RC4/Blowfish/ECB 模式）、不安全随机数（rand()/Math.random() 用于安全用途）、弱密钥派生（单次 SHA/MD5 作密钥）。

**核心原则：禁止已知弱算法，使用业界标准的安全算法。**

## 检测逻辑 (Detection Logic)

### Step 1: 搜索弱哈希函数 (Weak Hash Functions)

```c
// BAD: 弱哈希
MD5_Init(&ctx);
SHA1(...);
// 对于密码存储，即使是 SHA-256 也不够（需要 PBKDF2/bcrypt/Argon2）
```

### Step 2: 搜索弱加密算法 (Weak Encryption Algorithms)

```c
// BAD: 弱加密
DES_cblock key;
DES_set_key(&key, &schedule);
RC4_set_key(&key, len, data);
EVP_bf_cbc();                    // Blowfish 已过时

// BAD: 弱模式
EVP_aes_128_ecb();               // ECB 模式不安全
```

### Step 3: 搜索弱密钥交换 (Weak Key Exchange)

```c
// BAD: 弱 DH 参数
DH *dh = DH_new();
DH_generate_parameters_ex(dh, 512, ...);  // 512 位太短
```

## 废弃算法清单 (Deprecated Algorithm List)

| 算法 | 状态 | 替代方案 |
|------|------|---------|
| MD2, MD4, MD5 | 完全破解 | SHA-256/384/512 |
| SHA-1 | 碰撞攻击可行 | SHA-256+ |
| RC2, RC4 | 已破解 | AES-GCM / ChaCha20 |
| DES, 3DES | 密钥过短 | AES-128+ |
| ECB 模式 | 模式不安全 | CBC/GCM/CTR |
| RSA PKCS#1 v1.5 | 填充攻击 | OAEP |
| DH < 2048 位 | 不够安全 | DH 2048+ / ECDH |
| DSA < 2048 位 | 不够安全 | ECDSA / EdDSA |

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：弱算法调用的完整代码行，包含算法名称（如 "MD5"/"DES"/"RC4"）、API 函数名（如 MD5_Init/EVP_des_*）、上下文用途（哈希/加密/签名/密码存储）
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析该算法的已知安全缺陷（碰撞/原像/密钥长度）在当前使用场景下是否构成实际风险；区分安全性用途（认证/加密/签名）vs 非安全性用途（校验和/去重/哈希表）
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：输入数据 → 弱算法处理 → 输出使用的完整数据流，标注数据敏感性（明文密码/会话token/支付数据/PII）
      → findings.evidence.data_flow_path
- [ ] **call_stack**：弱算法调用位置 → 上层调用者 → 最外层用途（API 响应/数据库存储/文件加密），确认使用场景的安全需求级别
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：密钥长度（bits）、轮数、IV/Nonce 生成方式、操作模式（ECB/CBC/GCM）
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否存在密码学合规配置（如 BoringSSL/FIPS 模式）、是否启用了 -Wdeprecated-declarations 检测废弃API
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

| 用途 | 禁止 | 推荐 |
|------|------|------|
| 哈希 | MD5, SHA-1 | SHA-256/384/512 |
| 对称加密 | DES, RC4, AES-ECB | AES-256-GCM, ChaCha20-Poly1305 |
| 密码存储 | SHA, MD5 单次 | bcrypt, scrypt, Argon2id |
| 随机数 | rand(), Math.random() | getrandom(), SecureRandom, secrets.token_bytes() |

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 非安全用途（校验和） | MD5/SHA-1 用于数据完整性校验（checksum）、去重哈希、内容寻址，不涉及安全防护 | 确认算法输出不用于认证、加密、签名或密码存储；确认上下文为 checksum/dedup/fingerprint |
| 遗留系统互操作 | 与外部遗留系统通信需使用对方支持的算法，但有明确文档记录和控制措施 | 确认存在文档说明互操作需求，且有补偿控制（如限制通信仅在隔离网络内） |
| 测试向量中的已知值 | 单元测试中硬编码的已知哈希/密文值，用于验证算法实现正确性 | 确认代码位于 test/ 路径，且输入/输出均为硬编码的已知向量 |
| 已配置补偿控制 | 虽使用弱算法但有额外保护层（如短时效token、IP绑定、速率限制） | 确认补偿控制的实现代码存在且生效，风险已降至可接受水平 |
| 库内部实现（非直接调用） | 弱算法是第三方库的内部实现细节，应用代码未直接调用，升级库即可修复 | 确认调用链中应用代码未直接引用弱算法 API，弱算法在依赖库源码中 |
| 仅用于数据标识/非安全标记 | 如 MD5 用于生成缓存 key、文件标识符 | 确认哈希值不用于任何安全决策（认证/授权/完整性验证） |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# 弱哈希 API
MD5_|EVP_md5|SHA1_|EVP_sha1                            # C/C++ 弱哈希
                                                         # → MUST: code_context (算法名+用途)
                                                         # → MUST: judgment_rationale (已知缺陷+风险评估)
MessageDigest\.getInstance\("MD5|MessageDigest\.getInstance\("SHA-1  # Java 弱哈希
hashlib\.md5\(|hashlib\.sha1\(                           # Python 弱哈希
crypto/md5|crypto/sha1                                    # Go 弱哈希
CryptoJS\.MD5|CryptoJS\.SHA1                              # JavaScript 弱哈希

# 弱加密 API
DES_|EVP_des|RC4_|EVP_rc4|EVP_bf_                       # C/C++ 弱加密
Cipher\.getInstance\("DES|Cipher\.getInstance\("RC4      # Java 弱加密
Crypto\.Cipher\.DES|Crypto\.Cipher\.ARC4                 # Python 弱加密
                                                         # → SHOULD: call_stack (用途上下文)

# 弱模式
EVP_.*_ecb|Cipher\.getInstance.*ECB                      # ECB模式不安全
                                                         # → MAY: variable_state (模式/密钥长度)

# 弱 DH 参数
DH_generate_parameters.*512|DH_generate_parameters.*1024 # DH 密钥过短

# 不安全随机数（安全用途）
rand\(\)|Math\.random\(\)|random\.randint                  # 安全上下文中使用非密码学随机
→ 上下文含 token|session|password|crypto|key|iv

# === EXCLUDE (不报告) ===
→ checksum|dedup|fingerprint|cache.*key                   # 非安全用途（校验和/去重/缓存）
→ // test|/* test|@Test|def test_                         # 测试代码中的已知向量
→ // INTEROP|// legacy|// backward compatibility           # 明确文档化的互操作需求
→ 补偿控制: token.*expir|IP.*bind|rate.*limit              # 有补充保护
→ BoringSSL|FIPS_mode|FIPS_mode_set                       # FIPS 模式下严格算法控制
→ Argon2|bcrypt|scrypt|PBKDF2|SHA-256|SHA-384|SHA-512    # 安全算法
→ AES.*GCM|ChaCha20|XChaCha20|Ed25519|X25519              # 现代安全算法
→ SecureRandom|secrets\.|crypto/rand|getrandom\(           # 安全随机数生成
```
