---
detector: weak-random
severity: high
cwe: CWE-338
cvss: 7.5
language: [c, cpp, java, python, go, js]
tags: [crypto, randomness, prng]
precision: very-high
confidence: dynamic
target_functions: [bytes, drand48, gen, getpid, getrandom, lrand48, open, rand, random, read, srand, srandom, time]
match_patterns: []
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

安全场景（token/key/session/IV 生成）使用非密码学安全的 PRNG（`rand()`/`random()`/`Math.random()`），攻击者可预测输出，导致会话劫持、密钥猜测等。

**核心原则：安全相关随机数必须使用 CSPRNG。检测时要区分安全场景和非安全场景（游戏/模拟），仅报告前者。**

## 检测逻辑 (Detection Logic)

### Step 1: 搜索非安全 PRNG

```c
// BAD: 非密码学安全
rand();
srand(seed);
random();
srandom(seed);
drand48();
lrand48();
```

### Step 2: 识别安全敏感场景

这些函数在以下场景中为高危：
- 生成 Session Token
- 生成加密密钥 / IV / Nonce
- 生成密码重置 Token
- 生成 CSRF Token
- 随机文件名（防猜测）

### Step 3: 检查种子质量

```c
// BAD: 可预测种子
srand(time(NULL));               // 种子可预测
srand(getpid());                 // 种子范围小

// BAD: C++ 默认随机引擎
std::default_random_engine eng;  // 实现定义，可能为 LCG
```

### Step 4: 安全替代

```c
// GOOD: 平台 API
// Linux: getrandom() / /dev/urandom
int fd = open("/dev/urandom", O_RDONLY);
read(fd, buf, len);

// GOOD: OpenSSL
RAND_bytes(buf, len);

// GOOD: C++ <random>
std::random_device rd;           // 硬件熵源
std::mt19937 gen(rd());          // 但仅是梅森旋转，非密码学安全！
// 密码学场景应用 std::random_device 或 OpenSSL
```

## 修复指引 (Remediation)

| 平台 | 安全 API |
|------|---------|
| Linux | `getrandom()` / `getentropy()` / `read(/dev/urandom)` |
| OpenSSL | `RAND_bytes(buf, len)` |
| Java | `java.security.SecureRandom` |
| Python | `secrets.token_bytes()` / `os.urandom()` |
| Go | `crypto/rand.Read()` |
| JS/Node | `crypto.randomBytes()` |

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：随机数生成函数调用及上下文
      → findings.evidence.code_context
- [ ] **judgment_rationale**：调用是否在安全场景中
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：随机数从生成到使用的数据流
      → findings.evidence.data_flow_path
- [ ] **call_stack**：随机数生成函数的调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：随机种子来源和可预测性
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否正确区分安全/非安全场景
      → findings.evidence.sanitizer_analysis

## 误报排除 (False Positive Exclusion)

| 场景 (Scenario) | 排除依据 (Exclusion Basis) | 证据要求 (Evidence Required) |
|------|------|------|
| 非安全场景（游戏/模拟） | 不需要密码学强度 | 确认代码不在安全上下文（token/key/session/csrf生成路径）中 |
| `std::random_device` | 硬件熵源，密码学安全 | 确认使用了std::random_device且未被伪随机引擎替代 |
| `getrandom()`/`/dev/urandom` | 内核 CSPRNG | 确认调用getrandom()/getentropy()或从/dev/urandom读取 |
| `RAND_bytes` (OpenSSL) | 密码学安全 | 确认使用了RAND_bytes且正确初始化OpenSSL |
| `arc4random()` (BSD/macOS) | CSPRNG | 确认平台为BSD/macOS且调用arc4random接口 |

## 检测模式汇总 (Detection Pattern Summary)

### 匹配模式 (MATCH)

```
# 非安全随机函数
rand\(\)|srand\(|random\(\)|srandom\(|drand48|lrand48|mrand48
→ evidence: code_context (随机函数调用点)
→ 上下文: token|key|iv|nonce|session|csrf|crypto
   → evidence: data_flow_path (随机数使用目的)

# 可预测种子
srand\(time|srand\(getpid|srand\(clock
→ evidence: variable_state (种子来源)
→ rand() 用于安全上下文
   → evidence: judgment_rationale (安全场景判定)
```

### 排除模式 (EXCLUDE)

```
std::random_device
→ 硬件熵源，密码学安全，无需报告
getrandom\(|getentropy\(|/dev/urandom|/dev/random
→ 内核CSPRNG接口，无需报告
RAND_bytes|RAND_priv_bytes
→ OpenSSL安全随机接口，无需报告
SecureRandom|secrets\.token|os\.urandom|crypto\.randomBytes|crypto/rand\.Read
→ 各语言安全随机API，无需报告
(非安全上下文: 游戏|模拟|动画|shuffle|random.*color|random.*name)
→ 非密码学场景使用非安全PRNG，无需报告
```
