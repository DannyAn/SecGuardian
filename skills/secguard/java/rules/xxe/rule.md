---
name: secguard-java-xxe
description: "检测 Java XML 外部实体（XXE）注入 — DocumentBuilder / SAXParser / XMLInputFactory 未禁用外部实体"
language: java
topic: [web, xml, injection]
skill_id: java.xxe.insecure-xml
signal_source: call_sites[callee="newDocumentBuilder|parse|DocumentBuilderFactory|SAXParser|XMLReader|TransformerFactory|SchemaFactory"]
severity: high
cwe: CWE-611
trigger_functions: [newDocumentBuilder, newInstance, newSAXParser, parse, setFeature, newXMLReader]
---

# xxe 检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE |
|----------|---------------|-------------------|----------|-----|
| `java.xxe.insecure-xml` | `call_sites[cat="xml"]` | `newDocumentBuilder`, `newSAXParser`, `newInstance`, `parse`, `setFeature` | High | CWE-611 |

## Scenario 1: XML 解析器未禁用 DTD/外部实体

### 威胁定义
XML 解析器启用了外部实体处理，攻击者通过构造恶意 XML 读取本地文件（`file:///etc/passwd`）、发起 SSRF 或触发 DoS。Spring 应用中常使用 `DocumentBuilderFactory` 和 `SAXParserFactory` 解析用户提交的 XML 数据。

### 检测逻辑
```java
// BAD: DocumentBuilderFactory 默认配置
DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
DocumentBuilder builder = factory.newDocumentBuilder();
Document doc = builder.parse(inputStream);  // XXE vulnerable!

// BAD: SAXParser 默认配置
SAXParserFactory spf = SAXParserFactory.newInstance();
SAXParser sp = spf.newSAXParser();

// BAD: XMLInputFactory 默认（StAX）
XMLInputFactory xif = XMLInputFactory.newInstance();

// GOOD: 安全配置
DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
```

### 检测模式
**MATCH**: `XMLInputFactory.newInstance()` 未设 `IS_SUPPORTING_EXTERNAL_ENTITIES=false` / `SUPPORT_DTD=false`；`DocumentBuilderFactory.newInstance().newDocumentBuilder(` 未配置安全 feature；`SAXParserFactory.newInstance().newSAXParser(` 未配置安全 feature

**EXCLUDE**: `setFeature("disallow-doctype-decl", true)` 已配置；`setFeature("external-general-entities", false)` 已配置；`XMLInputFactory` 已禁用外部实体

### 修复指引
1. 启用 `disallow-doctype-decl` / `external-general-entities=false`
2. StAX: `XMLInputFactory.setProperty(IS_SUPPORTING_EXTERNAL_ENTITIES, false)` + `setProperty(SUPPORT_DTD, false)`
3. 全局禁用 DTD，不要在每个解析点单独配置

## 证据收集指引

| 证据类型 | 要求 | 说明 |
|---------|------|------|
| code_context | MUST | XML 解析器实例化及配置代码 |
| judgment_rationale | MUST | 是否禁用 DTD/外部实体 |
| data_flow_path | SHOULD | XML 数据从输入到解析器的路径 |
| sanitizer_analysis | SHOULD | FEATURE_SECURE_PROCESSING 配置分析 |

## 输出格式
`[High][CWE-611] {file}:{line} — XXE（{parser}）`
