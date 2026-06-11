---
detector: xxe
severity: critical
cwe: CWE-611
language: [java, python, go]
tags: [web, xml, injection]
precision: high
confidence: dynamic
---

# XML External Entity (XXE) Injection

## 威胁定义 (Threat Definition)

XML 解析器启用了外部实体（External Entity）处理，攻击者通过恶意 XML 读取本地文件（`<!ENTITY xxe SYSTEM "file:///etc/passwd">`）、发起 SSRF、或触发 DoS（Billion Laughs）。

**核心原则：所有 XML 解析器必须禁用 DTD/外部实体。Java: `XMLInputFactory` 设置 `IS_SUPPORTING_EXTERNAL_ENTITIES=false`，Python: `defusedxml`。**

## 检测逻辑 (Detection Logic)

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

## 修复指引 (Remediation)

1. Java: `XMLInputFactory.setProperty(IS_SUPPORTING_EXTERNAL_ENTITIES, false)` + `setProperty(SUPPORT_DTD, false)`
2. Python: 使用 `defusedxml` 库替代标准 `xml.etree`
3. Go: `xml.Decoder` 默认安全，但需确保未启用自定义 Entity
4. 全局禁用 DTD 和外部实体，不要在每个解析点单独配置

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：XML解析器实例化及配置代码
      → findings.evidence.code_context
- [ ] **judgment_rationale**：是否禁用DTD/外部实体
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：XML数据从输入到解析器的路径
      → findings.evidence.data_flow_path
- [ ] **call_stack**：解析器调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：XMLInputFactory/SAXParser配置参数
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否配置了FEATURE_SECURE_PROCESSING
      → findings.evidence.sanitizer_analysis

## 误报排除 (False Positive Exclusion)

| 场景 (Scenario) | 排除依据 (Exclusion Basis) | 证据要求 (Evidence Required) |
|------|------|------|
| DocumentBuilderFactory with XXE protection features set | Secure configuration | 确认disallow-doctype-decl和external-general-entities均已正确配置 |
| XMLReader with FEATURE_SECURE_PROCESSING | JAXP secure processing enabled | 确认setFeature(FEATURE_SECURE_PROCESSING, true)已调用 |
| Go's encoding/xml | Go does not support DTD entities by default | 确认使用标准库encoding/xml且未启用自定义Entity |

## 检测模式汇总 (Detection Pattern Summary)

### 匹配模式 (MATCH)

```
# Java: unsecured XML parsers
newInstance\(\)\.newDocumentBuilder\(\)
→ evidence: code_context (解析器实例化代码)
→ No disallow-doctype-decl or external-entities feature

newInstance\(\)\.newSAXParser\(\)
→ evidence: code_context (SAX解析器实例化)
→ No FEATURE_SECURE_PROCESSING or external-entities feature

# Python: lxml without entity restriction
etree\.parse\(|etree\.XMLParser\(
→ evidence: code_context (解析调用点)
→ without resolve_entities=False

# Go: XML decoder default
xml\.NewDecoder
→ evidence: code_context (解码器创建点)
→ (relatively safe, but worth flagging)
```

### 排除模式 (EXCLUDE)

```
setFeature.*disallow-doctype-decl.*true
→ DTD声明已禁用，无需报告
setFeature.*external-general-entities.*false
→ 外部实体已禁用，无需报告
resolve_entities\s*=\s*False
→ lxml实体解析已禁用，无需报告
defusedxml
→ 已使用安全库defusedxml，无需报告
```
