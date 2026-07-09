---
name: secguard-java-deserialization
description: "检测 Java 反序列化漏洞 — ObjectInputStream / FastJson @type / Jackson enableDefaultTyping / XStream / SnakeYAML 不可信数据反序列化"
language: java
topic: [web, deserialization, rce]
skill_id: java.deserialization.insecure
signal_source: call_sites[cat="deserialization"]
severity: critical
cwe: CWE-502
trigger_functions: [readObject, parseObject, enableDefaultTyping, fromXML, load, addAccept, setAutoTypeSupport, setObjectInputFilter]
---

# deserialization 检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE |
|----------|---------------|-------------------|----------|-----|
| `java.deserialization.insecure` | `call_sites[cat="deserialization"]` | `readObject`, `parseObject`, `enableDefaultTyping`, `fromXML`, `load` | Critical | CWE-502 |

## Scenario 1: 不可信数据反序列化

### 威胁定义
攻击者构造恶意序列化数据，在反序列化过程中触发 RCE。Java 框架中 FastJson `@type`、Jackson `enableDefaultTyping`、XStream `fromXML`、SnakeYAML `load` 均可被利用。Shiro 使用 `ObjectInputStream` 反序列化 RememberMe Cookie 是经典攻击面。

### 检测逻辑
```java
// BAD: ObjectInputStream 直接反序列化
ObjectInputStream ois = new ObjectInputStream(inputStream);
Object obj = ois.readObject();

// BAD: FastJson autoType 未禁用
JSON.parseObject(jsonString);  // @type 可指定任意类

// BAD: Jackson enableDefaultTyping
ObjectMapper mapper = new ObjectMapper();
mapper.enableDefaultTyping(ObjectMapper.DefaultTyping.NON_FINAL);

// BAD: SnakeYAML load
Yaml yaml = new Yaml();
Object obj = yaml.load(yamlString);

// GOOD: ObjectInputFilter 白名单 (Java 9+)
ObjectInputFilter filter = ObjectInputFilter.Config.createFilter("com.example.model.*;!*");
ois.setObjectInputFilter(filter);

// GOOD: FastJson 禁用 autoType
ParserConfig.getGlobalInstance().addAccept("com.example.model.");

// GOOD: SnakeYAML SafeConstructor
Yaml yaml = new Yaml(new SafeConstructor());
```

### 检测模式
**MATCH**: `ObjectInputStream.readObject` → 无 `setObjectInputFilter`；`JSON.parseObject` → 无 `setAutoTypeSupport(false)` 或 `addAccept`；`enableDefaultTyping` → 多态反序列化；`new Yaml()` + `.load(` → 非 `SafeConstructor`

**EXCLUDE**: `ObjectInputFilter` 白名单已配置；Jackson 仅 `readValue(具体类)` 无 `enableDefaultTyping`；FastJson autoType 已关闭或白名单；SnakeYAML `SafeConstructor`

### 修复指引
1. 首选：使用纯数据格式（JSON Schema 验证后的 JSON）替代原生序列化
2. 次选：类型白名单反序列化（ObjectInputFilter / FastJson addAccept / Jackson BasicPolymorphicTypeValidator）
3. 补充：反序列化前签名验证（HMAC）

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | 反序列化调用及类型配置代码 |
| judgment_rationale | MUST | 是否允许任意类型反序列化 |
| data_flow_path | SHOULD | 不可信数据到反序列化入口的路径 |
| sanitizer_analysis | SHOULD | 类型白名单 / ObjectInputFilter 配置 |

## 输出格式
`[Critical][CWE-502] {file}:{line} — 不可信数据反序列化（{framework}）`
