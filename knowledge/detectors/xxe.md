---
detector: xxe
severity: critical
cwe: CWE-611
language: [java, python, go]
tags: [web, xml, injection]
---

# XML External Entity (XXE) Injection

## 威胁定义

XML 解析器启用了外部实体（External Entity）处理，攻击者通过恶意 XML 读取本地文件（`<!ENTITY xxe SYSTEM "file:///etc/passwd">`）、发起 SSRF、或触发 DoS（Billion Laughs）。

**核心原则：所有 XML 解析器必须禁用 DTD/外部实体。Java: `XMLInputFactory` 设置 `IS_SUPPORTING_EXTERNAL_ENTITIES=false`，Python: `defusedxml`。**

## Detection Logic

### Step 1: Search for unsecured XML parsing

**Java (DocumentBuilderFactory):**
```java
// BAD: default configuration, no XXE protection
DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
DocumentBuilder builder = factory.newDocumentBuilder();
Document doc = builder.parse(inputStream);  // XXE vulnerable!

// GOOD: secure configuration
DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
factory.setFeature("http://xml.org/sax/features/external-general-entities", false);
```

**Java (SAXParser):**
```java
// BAD: default SAXParser
SAXParser parser = SAXParserFactory.newInstance().newSAXParser();
```

**Python (lxml):**
```python
# BAD: lxml with default settings
from lxml import etree
tree = etree.parse(input_file)  # XXE by default!

# GOOD: resolve_entities=False
parser = etree.XMLParser(resolve_entities=False)
tree = etree.parse(input_file, parser)
```

**Go (encoding/xml):**
```go
// BAD: default XML decoder
decoder := xml.NewDecoder(reader)  // Go XML is relatively safe
// Go's encoding/xml does not support DTD by default — but check for external entity usage
```

### Step 2: Check for SAX/StAX configurations

```java
// BAD: SAXParser default
SAXParserFactory spf = SAXParserFactory.newInstance();
SAXParser sp = spf.newSAXParser();  // XXE by default

// BAD: XMLInputFactory default
XMLInputFactory xif = XMLInputFactory.newInstance();
```

## 修复指引

1. Java: `XMLInputFactory.setProperty(IS_SUPPORTING_EXTERNAL_ENTITIES, false)` + `setProperty(SUPPORT_DTD, false)`
2. Python: 使用 `defusedxml` 库替代标准 `xml.etree`
3. Go: `xml.Decoder` 默认安全，但需确保未启用自定义 Entity
4. 全局禁用 DTD 和外部实体，不要在每个解析点单独配置

## False Positive Exclusion

| Scenario | Reason |
|----------|--------|
| DocumentBuilderFactory with XXE protection features set | Secure configuration |
| XMLReader with FEATURE_SECURE_PROCESSING | JAXP secure processing enabled |
| Go's encoding/xml | Go does not support DTD entities by default |

## Detection Pattern Summary

```
# Java: unsecured XML parsers
newInstance\(\)\.newDocumentBuilder\(\)|newInstance\(\)\.newSAXParser\(\)
→ No disallow-doctype-decl or external-entities feature

# Python: lxml without entity restriction
etree\.parse\(|etree\.XMLParser\(  # without resolve_entities=False

# Go: XML decoder default
xml\.NewDecoder  # (relatively safe, but worth flagging)
```
