---
category: concept
threat_type: deserialization
severity: critical
cwe: CWE-502
owasp: A08:2021 - Software and Data Integrity Failures
---

# 反序列化漏洞 (Insecure Deserialization)

攻击者构造恶意序列化数据，在反序列化过程中触发代码执行、对象注入、权限提升。

## 检测策略

### 核心原则
**不可信数据不可反序列化。尤其是能够实例化任意类型的反序列化机制。**

1. **原生反序列化接口**
   - Java ObjectInputStream / readObject
   - Python pickle / cPickle / yaml.unsafe_load
   - Go gob 解码不受信任数据
   - C++ Boost.Serialization 处理外部输入

2. **第三方序列化框架**
   - Fastjson、Jackson 的多态类型指定
   - XStream 未限制类型

3. **非预期的反序列化路径**
   - Cookie 反序列化（Shiro RememberMe）
   - Session 序列化
   - JMX/RMI 反序列化

### 误报排除
- 仅反序列化基本类型（String、int、byte[]）
- 类型白名单 + TypeFilter
- 数据来源可信（内部系统间通信）

## 修复指引

1. **首选**：使用纯数据格式（JSON Schema 验证后的 JSON）
2. **次选**：类型白名单反序列化
3. **补充**：反序列化前签名验证（HMAC）
