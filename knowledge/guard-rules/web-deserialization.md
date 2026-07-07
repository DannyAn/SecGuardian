---
detector: deserialization
severity: critical
cwe: CWE-502
language: [java]
tags: [web, deserialization, rce]
precision: high
confidence: dynamic
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "web.deserialization",
  "type": "guard-rule",
  "namespace": "web",
  "severity": "Critical",
  "cwe": "CWE-502",
  "cvss": 9.8,
  "confidence": "dynamic",
  "precision": "high",
  "languages": [
    "java"
  ],
  "target_functions": [
    "addAccept",
    "createFilter",
    "enableDefaultTyping",
    "fromXML",
    "getGlobalInstance",
    "load",
    "parseObject",
    "readObject",
    "readValue",
    "setAutoTypeSupport",
    "setObjectInputFilter"
  ],
  "match_patterns": [],
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

攻击者构造恶意序列化数据，在反序列化过程中触发代码执行、对象注入、权限提升。主要影响 Java（ObjectInputStream）、Python（pickle/yaml.load）和 Fastjson/Jackson/XStream 等框架。

**核心原则：不可信数据不可反序列化，尤其是能够实例化任意类型的反序列化机制。**

## 检测逻辑 (Detection Logic)

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

## 修复指引 (Remediation)

1. **首选**：使用纯数据格式（JSON Schema 验证后的 JSON）
2. **次选**：类型白名单反序列化（Look-ahead ObjectInputStream、FastJson autoType 关闭）
3. **补充**：反序列化前签名验证（HMAC）

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：反序列化调用及类型配置
      → findings.evidence.code_context
- [ ] **judgment_rationale**：是否允许任意类型反序列化
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：不可信数据→反序列化入口的路径
      → findings.evidence.data_flow_path
- [ ] **call_stack**：反序列化调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：autoType/DefaultTyping 配置状态
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否配置了类型白名单或 ObjectInputFilter
      → findings.evidence.sanitizer_analysis

## 误报排除 (False Positive Exclusion)

| 场景 (Scenario) | 排除依据 (Exclusion Basis) | 证据要求 (Evidence Required) |
|------|------|------|
| ObjectInputFilter 白名单正确配置 | 已限制可反序列化类型 | 提供 ObjectInputFilter.createFilter 配置及白名单包名 |
| Jackson 仅 readValue(Class) 无 enableDefaultTyping | 安全绑定具体类型 | 确认无 enableDefaultTyping 调用，readValue 第二个参数为具体类 |
| FastJson autoType 已关闭或白名单配置 | 已防护 | 提供 setAutoTypeSupport(false) 或 addAccept 配置代码 |
| SnakeYAML SafeConstructor | 已使用安全构造器 | 确认 new Yaml(new SafeConstructor()) 使用 |
| 仅 JSON 序列化（非原生 Java） | JSON 不执行代码 | 确认 ObjectMapper 仅在 readValue(Class) 模式下使用，无原生 readObject |

## 检测模式汇总 (Detection Pattern Summary)

### 匹配模式 (MATCH)

```
# ObjectInputStream
ObjectInputStream|readObject
→ 无 ObjectInputFilter|setObjectInputFilter
→ evidence: code_context, sanitizer_analysis

# FastJson
JSON.parse|JSON.parseObject
→ 无 setAutoTypeSupport\(false\)|addAccept
→ evidence: code_context, variable_state

# Jackson
enableDefaultTyping|ObjectMapper.enableDefaultTyping
→ 类型的反序列化
→ evidence: code_context, variable_state

# XStream
new XStream\(\)|fromXML
→ 无 addPermission|allowTypes
→ evidence: code_context, sanitizer_analysis

# SnakeYAML
new Yaml\(\)|\.load\(
→ 非 SafeConstructor
→ evidence: code_context, sanitizer_analysis
```

### 排除模式 (EXCLUDE)

```
# ObjectInputFilter 白名单已配置
→ evidence: sanitizer_analysis (已限制可反序列化类型)

# Jackson readValue(具体类) 无 enableDefaultTyping
→ evidence: sanitizer_analysis (安全绑定具体类型)

# FastJson autoType 已关闭或白名单
→ evidence: sanitizer_analysis (autoType 安全配置)

# SnakeYAML SafeConstructor
→ evidence: sanitizer_analysis (安全构造器已使用)

# 仅 JSON 序列化 (ObjectMapper 固定类型)
→ evidence: sanitizer_analysis (纯数据格式，不执行代码)
```
