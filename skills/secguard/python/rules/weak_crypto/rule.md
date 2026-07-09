---
name: secguard-python-weak-crypto
description: "检测弱加密算法 — hashlib.md5 / random.random / SHA-1"
language: python
topic: [crypto, algorithm, deprecated]
skill_id: python.weak-crypto.md5
signal_filter: python.weak-crypto.md5*
signal_source: call_sites[category="crypto"]
severity: high
cwe: CWE-327
trigger_functions: [hashlib.md5, hashlib.sha1, Crypto.Cipher.DES, Crypto.Cipher.ARC4, Crypto.Cipher.Blowfish, Cryptodome.Cipher.DES, Cryptodome.Cipher.ARC4, os.urandom, secrets.token_bytes, random.random, random.randint, random.choice]
---

# 弱加密算法检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE | Guard-rule |
|----------|---------------|-------------------|----------|-----|------------|
| `python.weak-crypto.md5` | `call_sites[cat="crypto"]` | `hashlib.md5`, `Crypto.Cipher.DES`, `random.random` | High | CWE-327 | `weak-crypto-algorithm` |

## Scenario 1: 弱哈希/弱加密算法使用

### 威胁定义
使用 MD5/SHA-1（碰撞攻击可行）、DES/RC4/Blowfish（密钥过短或已破解）、`random` 模块（非密码学安全）用于安全敏感场景（令牌/密码/密钥生成）。

### 检测逻辑
```python
# BAD: MD5 用于安全场景
token = hashlib.md5(user_input).hexdigest()

# BAD: DES 加密
from Crypto.Cipher import DES
cipher = DES.new(key, DES.MODE_ECB)

# BAD: random 用于安全场景
token = str(random.randint(100000, 999999))

# GOOD: 安全替代
import hashlib, secrets
token = hashlib.sha256(user_input.encode()).hexdigest()
cipher = AES.new(key, AES.MODE_GCM)
token = secrets.token_hex(16)
```

### 检测模式
- **MATCH**: `hashlib\.md5\(` | `hashlib\.sha1\(` | `Crypto\.Cipher\.(DES|ARC4|Blowfish)` | `Cipher\.getInstance.*(DES|ARC4|ECB)` | `random\.(random|randint|choice|uniform)`
- **EXCLUDE**: 非安全场景（checksum/dedup）| `secrets\.` | `hashlib\.sha256\|sha3` | `AES.*GCM` | `Crypto\.Cipher\.AES`

### 修复指引
| 用途 | 禁止 | 推荐 |
|------|------|------|
| 哈希 | MD5, SHA-1 | SHA-256/384/512 |
| 对称加密 | DES, RC4, AES-ECB | AES-256-GCM, ChaCha20 |
| 密码存储 | 任何单次哈希 | bcrypt, scrypt, Argon2 |
| 随机数 | random.* | secrets.token_bytes(), os.urandom() |

## 证据收集指引

| 证据类型 | 要求 |
|----------|------|
| code_context | MUST — 算法调用行 + 算法名称 |
| judgment_rationale | MUST — 用途（安全性 vs 非安全性） |
| call_stack | SHOULD — 用途上下文（认证/加密/校验和） |
| variable_state | MAY — 密钥长度/模式/IV 生成方式 |

## 输出格式

记录为 finding，标注 `severity: high`，`cwe: CWE-327`。
