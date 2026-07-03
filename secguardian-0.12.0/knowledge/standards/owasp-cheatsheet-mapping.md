---
category: standards
standard: OWASP Cheat Sheet Series
version: "2024"
mapped_skills_count: 17
---

# OWASP Cheat Sheet → SecGuardian Skill/Detector 映射

> 来源: [OWASP Cheat Sheet Series](https://cheatsheetseries.owasp.org/)

## 核心 Cheat Sheet 映射

### 输入验证

| OWASP Cheat Sheet | SecGuardian 覆盖 | 类型 |
|-------------------|-----------------|------|
| [Input Validation](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html) | secaudit-input-validation + web.input-validation detector | Skill + Detector |
| [SQL Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html) | web.sql-injection detector + sql-injection concept | Detector + Concept |
| [Cross Site Scripting Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html) | web.xss detector + secaudit-output-encoding | Detector + Skill |
| [DOM based XSS Prevention](https://cheatsheetseries.owasp.org/cheatsheets/DOM_based_XSS_Prevention_Cheat_Sheet.html) | web.xss detector (DOM XSS patterns) | Detector |
| [OS Command Injection Defense](https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html) | system.command-injection detector | Detector |
| [LDAP Injection Prevention](https://cheatsheetseries.owasp.org/cheatsheets/LDAP_Injection_Prevention_Cheat_Sheet.html) | — | ❌ 未覆盖 |
| [Deserialization](https://cheatsheetseries.owasp.org/cheatsheets/Deserialization_Cheat_Sheet.html) | web.deserialization detector | Detector |
| [File Upload](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html) | web.unrestricted-upload detector | Detector |
| [Server Side Request Forgery Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html) | web.ssrf detector | Detector |
| [XML External Entity Prevention](https://cheatsheetseries.owasp.org/cheatsheets/XML_External_Entity_Prevention_Cheat_Sheet.html) | web.xxe detector | Detector |
| [Mass Assignment](https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html) | web.mass-assignment detector ✨新建 | Detector |
| [Prototype Pollution Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Prototype_Pollution_Prevention_Cheat_Sheet.html) | web.prototype-pollution detector ✨新建 | Detector |

### 认证

| OWASP Cheat Sheet | SecGuardian 覆盖 | 类型 |
|-------------------|-----------------|------|
| [Authentication](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html) | secaudit-auth-and-session | Skill |
| [Session Management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) | secaudit-auth-and-session | Skill |
| [Forgot Password](https://cheatsheetseries.owasp.org/cheatsheets/Forgot_Password_Cheat_Sheet.html) | secaudit-auth-and-session | Skill |
| [Multifactor Authentication](https://cheatsheetseries.owasp.org/cheatsheets/Multifactor_Authentication_Cheat_Sheet.html) | secaudit-auth-and-session | Skill |
| [JSON Web Token](https://cheatsheetseries.owasp.org/cheatsheets/JSON_Web_Token_for_Java_Cheat_Sheet.html) | web.jwt-misuse detector | Detector |

### 授权

| OWASP Cheat Sheet | SecGuardian 覆盖 | 类型 |
|-------------------|-----------------|------|
| [Authorization](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html) | secaudit-authorization | Skill |
| [Insecure Direct Object Reference Prevention](https://cheatsheetseries.owasp.org/cheatsheets/Insecure_Direct_Object_Reference_Prevention_Cheat_Sheet.html) | web.idor detector | Detector |
| [Access Control](https://cheatsheetseries.owasp.org/cheatsheets/Access_Control_Cheat_Sheet.html) | secaudit-authorization + web.missing-authorization | Skill + Detector |

### 密码学

| OWASP Cheat Sheet | SecGuardian 覆盖 | 类型 |
|-------------------|-----------------|------|
| [Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html) | secaudit-cryptography + crypto.* detectors | Skill + Detector |
| [Key Management](https://cheatsheetseries.owasp.org/cheatsheets/Key_Management_Cheat_Sheet.html) | secaudit-secrets-management | Skill |
| [TLS Cipher String](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Protection_Cheat_Sheet.html) | secaudit-secure-transport + crypto-tls-version ✨ | Skill + Detector |

### 其他

| OWASP Cheat Sheet | SecGuardian 覆盖 | 类型 |
|-------------------|-----------------|------|
| [Logging](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html) | secaudit-logging-and-monitoring + error-log-sensitive-data ✨ | Skill + Detector |
| [Error Handling](https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html) | error-stack-trace-leak ✨ + error-exception-swallow ✨ | Detector |
| [REST API Security](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html) | secaudit-attack-surface-analysis + web.mass-assignment ✨ | Skill + Detector |
| [Docker Security](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html) | secaudit-infra-hardening | Skill |
| [Kubernetes Security](https://cheatsheetseries.owasp.org/cheatsheets/Kubernetes_Security_Cheat_Sheet.html) | secaudit-infra-hardening | Skill |
| [Dependency Checking](https://cheatsheetseries.owasp.org/cheatsheets/Dependency_Check_Cheat_Sheet.html) | secaudit-dependency-security | Skill |
| [HTTP Security Headers](https://cheatsheetseries.owasp.org/cheatsheets/HTTP_Headers_Cheat_Sheet.html) | secaudit-http-security-headers | Skill |
| [Content Security Policy](https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html) | secaudit-http-security-headers | Skill |

### 覆盖统计

| 分类 | Cheat Sheet 数 | 已覆盖 | 覆盖率 |
|------|--------------|--------|--------|
| 输入验证 | 12 | 11 | 92% |
| 认证 | 5 | 5 | 100% |
| 授权 | 3 | 3 | 100% |
| 密码学 | 3 | 3 | 100% |
| 其他 | 8 | 8 | 100% |

**总计: 30/31 Cheat Sheet 已覆盖 (97%)**

> ✨ 标记为本次 CodePlan 新增
