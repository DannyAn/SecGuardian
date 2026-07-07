# 硬编码密钥规则定义

## 核心规则

源代码中不得包含硬编码的密码、API 密钥、加密密钥、token 或其他机密凭据。

## 检测模式

### 模式 A: 密码/密钥字符串字面量
```c
// BAD
const char *password = "abc123";
char *api_key = "sk-live-abc123def456";
static const char secret[] = "my-secret-key";

// GOOD（来自环境变量）
char *password = getenv("DB_PASSWORD");

// GOOD（来自配置文件读取）
read_config(&cfg);
use_key(cfg.api_key);
```

### 模式 B: 密钥材料数组
```c
// BAD: 硬编码 AES 密钥
static const uint8_t aes_key[32] = {
    0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
    0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
    // ...
};

// GOOD: 从密钥派生
uint8_t key[32];
HKDF_extract(key, sizeof(key), ikm, sizeof(ikm), salt, sizeof(salt));
```

### 模式 C: 字符串比较密码
```c
// BAD: 硬编码密码比较
if (strcmp(user_pass, "admin123") == 0) {
    grant_access();
}

// GOOD: 使用哈希验证
bool ok = verify_password_hash(user_pass, stored_hash);
```

### 模式 D: 连接字符串嵌入式凭据
```c
// BAD
#define DB_URL "mysql://admin:secret@localhost:3306/db"

// GOOD
#define DB_URL_CONFIG "/etc/myapp/db.conf"
```

## 安全变体审计

1. 变量名暗示密钥但值为 getenv()/读取文件 → 不报告
2. 密钥来自编译期配置（非源文件，来自构建系统）→ 报告并标记
3. Base64 编码高熵字符串 → 确认是否为真正密钥（检查使用上下文）
4. 测试目录中的假密钥 → 检查是否含有生产环境前缀
