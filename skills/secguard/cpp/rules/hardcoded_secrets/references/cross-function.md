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
