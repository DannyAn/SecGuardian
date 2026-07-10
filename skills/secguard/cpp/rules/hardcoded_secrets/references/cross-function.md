> **定位**: 密钥字面量跨函数边界传递的追踪规则 | **加载时机**: Phase 2c Counter Evidence | **消费方**: Judge (Step 7)

# 硬编码密钥跨函数追踪

## 规则

当密钥字面量通过函数参数传递时，追踪目标函数内部的使用方式。

### 最大深度: 1 层

```c
void setup() {
    use_key("my-secret-key", 128);
}

void use_key(const char *key, int bits) {
    // 确认 use_key 内部调用 AES_set_encrypt_key 等加密 API
    AES_set_encrypt_key((const uint8_t*)key, bits, &ctx);
}
```

### 深度上限

超过 depth 1 的调用链 → 降级为 suspicious。

## 跨函数密钥传播模式

### 1. 直接参数传递（最常见）

```c
// 报告：密钥字面量传递给加密函数
void init_crypto() {
    init_aes("sk-prod-abc123def456", 256);  // 第1层：直接传递
}

void init_aes(const char *key, int bits) {
    AES_set_encrypt_key((const uint8_t*)key, bits, &global_ctx);  // 第2层：追踪到此
}
```

### 2. 全局变量污染追踪

```c
// 报告：密钥通过全局变量传播
static const char *g_secret_key = NULL;

void setup_secrets() {
    g_secret_key = "hardcoded-api-token-xyz";  // 感染全局变量
}

void connect_api() {
    api_call(g_secret_key);  // 通过全局变量使用 → 追踪感染源
}
```

### 3. 结构体字段污染

```c
// 报告：密钥通过结构体字段传播
typedef struct {
    const char *api_key;
    const char *endpoint;
} ConnectionConfig;

void init_config(ConnectionConfig *cfg) {
    cfg->api_key = "sk-live-7890abcdef";  // 感染结构体字段
}

void connect(ConnectionConfig *cfg) {
    http_set_header(cfg->api_key);  // 通过结构体使用 → 追踪
}
```

### 4. 宏展开中的密钥

```c
// 报告：宏定义中的硬编码密钥
#define DB_PASSWORD "prod-db-password-2024"

void connect_db() {
    mysql_real_connect(conn, host, user, DB_PASSWORD, db, port, NULL, 0);
    // 即使通过宏引用，密钥仍嵌入代码
}
```

### 5. 间接调用链（降级处理）

```c
// suspicious（降级）: 超过 depth 1 的调用链
void level0() {
    level1("secret-key-value");  // depth 0
}
void level1(const char *k) {
    level2(k);  // depth 1: 仅追踪到此
}
void level2(const char *k) {
    AES_set_encrypt_key((const uint8_t*)k, 256, &ctx);  // depth 2: 超出限制
}
```

## 全局变量污染追踪规则

| 感染源 | 追踪方式 | 示例 |
|--------|---------|------|
| `static` 全局变量赋值 | 追踪所有引用点 | `g_key = "secret";` → 所有 `g_key` 读取 |
| 结构体字段赋值 | 追踪该字段的后续读取 | `cfg->token = "abc";` → `cfg->token` 传递 |
| `const` 全局数组/指针 | 按字面量处理 | `const char key[] = "abc";` → 等效于直接字面量 |
| 函数返回的密钥字符串 | 追踪返回值的使用 | `const char *k = load_key();` → 检查 `load_key()` 实现 |

## OWASP 参考

- **OWASP Top 10 (2021) A07:2021**: Identification and Authentication Failures — 硬编码凭据是主要成因
- **OWASP ASVS V2.10**: 验证应用不使用硬编码凭据（代码、配置、环境变量名中）
