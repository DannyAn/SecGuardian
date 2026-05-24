---
detector: weak-random
severity: high
cwe: CWE-338
language: [c, cpp]
tags: [crypto, randomness, prng]
---

# 弱随机数生成 (Weak Random)

## 检测概要

检查安全敏感场景中是否使用了非密码学安全的随机数生成器。

## 检测逻辑

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

## 误报排除

| 场景 | 原因 |
|------|------|
| 非安全场景（游戏/模拟） | 不需要密码学强度 |
| `std::random_device` | 硬件熵源，密码学安全 |
| `getrandom()`/`/dev/urandom` | 内核 CSPRNG |
| `RAND_bytes` (OpenSSL) | 密码学安全 |
| `arc4random()` (BSD/macOS) | CSPRNG |

## 检测模式汇总

```
# 非安全随机函数
rand\(\)|srand\(|random\(\)|srandom\(|drand48|lrand48|mrand48
→ 上下文: token|key|iv|nonce|session|csrf|crypto

# 可预测种子
srand\(time|srand\(getpid|srand\(clock
→ rand() 用于安全上下文
```