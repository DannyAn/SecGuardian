---
detector: deserialization
severity: critical
cwe: CWE-502
language: [java]
tags: [web, deserialization, rce]
---

# Java 反序列化漏洞检测

## 威胁定义

攻击者构造恶意序列化数据，在反序列化过程中触发代码执行、对象注入、权限提升。主要影响 Java（ObjectInputStream）、Python（pickle/yaml.load）和 Fastjson/Jackson/XStream 等框架。

**核心原则：不可信数据不可反序列化，尤其是能够实例化任意类型的反序列化机制。**

## 检测逻辑

### Step 1: 搜索反序列化入口

```java
// BAD: ObjectInputStream 直接反序列化
ObjectInputStream ois = new ObjectInputStream(inputStream);
Object obj = ois.readObject();

// BAD: FastJson 未禁用 autoType
JSON.parseObject(jsonString);  // 默认可能开启 autoType

// BAD: Jackson enableDefaultTyping
ObjectMapper mapper = new ObjectMapper();
mapper.enableDefaultTyping(ObjectMapper.DefaultTyping.NON_FINAL);
mapper.readValue(jsonString, Object.class);

// BAD: XStream 未限制类型
XStream xstream = new XStream();
Object obj = xstream.fromXML(xmlString);

// BAD: SnakeYAML load (非 safeLoad)
Yaml yaml = new Yaml();
Object obj = yaml.load(yamlString);
```

### Step 2: 安全替代

```java
// GOOD: ObjectInputFilter 白名单 (Java 9+)
ObjectInputFilter filter = ObjectInputFilter.Config.createFilter(
    "com.example.model.*;!*");
ois.setObjectInputFilter(filter);

// GOOD: FastJson 禁用 autoType
ParserConfig.getGlobalInstance().setAutoTypeSupport(false);
// 或使用白名单
ParserConfig.getGlobalInstance().addAccept("com.example.model.");

// GOOD: Jackson 不使用 enableDefaultTyping
// 或配置 BasicPolymorphicTypeValidator

// GOOD: SnakeYAML safeLoad
Yaml yaml = new Yaml(new SafeConstructor());
Object obj = yaml.load(yamlString);

// GOOD: 用 JSON 替代原生序列化
ObjectMapper mapper = new ObjectMapper();
MyClass obj = mapper.readValue(jsonString, MyClass.class);
```

## 修复指引

1. **首选**：使用纯数据格式（JSON Schema 验证后的 JSON）
2. **次选**：类型白名单反序列化（Look-ahead ObjectInputStream、FastJson autoType 关闭）
3. **补充**：反序列化前签名验证（HMAC）

## 误报排除

| 场景 | 原因 |
|------|------|
| ObjectInputFilter 白名单正确配置 | 已限制可反序列化类型 |
| Jackson 仅 readValue(Class) 无 enableDefaultTyping | 安全绑定具体类型 |
| FastJson autoType 已关闭或白名单配置 | 已防护 |
| SnakeYAML SafeConstructor | 已使用安全构造器 |
| 仅 JSON 序列化（非原生 Java） | JSON 不执行代码 |

## 检测模式汇总

```
# ObjectInputStream
ObjectInputStream|readObject
→ 无 ObjectInputFilter|setObjectInputFilter

# FastJson
JSON.parse|JSON.parseObject
→ 无 setAutoTypeSupport\(false\)|addAccept

# Jackson
enableDefaultTyping|ObjectMapper.enableDefaultTyping
→ 类型的反序列化

# XStream
new XStream\(\)|fromXML
→ 无 addPermission|allowTypes

# SnakeYAML
new Yaml\(\)|\.load\(
→ 非 SafeConstructor
```
