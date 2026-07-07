---
name: information-exposure
description: 审计敏感信息泄露风险，检测不当的数据暴露、错误信息泄漏、调试端点暴露等场景。当用户请求信息泄露审计、敏感数据暴露检测、错误信息泄漏分析时使用。
category: domain
topic: [web, general]
---


## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "domain.information-exposure",
  "type": "audit-rule",
  "domain_name": "information-exposure",
  "category": "domain",
  "topics": [
    "web",
    "general"
  ],
  "severity": "High",
  "cwe": "CWE-200",
  "cvss": 7.5
}
```

# Information Exposure

## 概述

信息泄露（Information Exposure）指应用程序无意中向未授权方暴露敏感信息。这些信息可能被攻击者利用以进一步攻击系统。

## 检测内容

### 错误信息泄漏
- 详细错误页面暴露堆栈跟踪、SQL 查询、文件路径
- 调试模式在生产环境启用
- 不安全的异常处理导致内部状态泄露

### 敏感数据在响应中暴露
- API 响应中包含内部 IP 地址、文件路径、数据库结构
- 用户 PII 在不必要的场景中被返回
- HTTP 响应头暴露服务器版本、框架信息

### 调试/管理端点暴露
- `/debug`、`/admin`、`/actuator`、`/swagger-ui` 等在无认证下可访问
- 环境信息端点暴露配置详情
- 健康检查端点暴露内部服务拓扑

### 信息泄露渠道
- 日志中记录密码、Token、PII
- URL 参数中包含敏感数据
- Referer 头泄露敏感信息
- 缓存的响应被其他用户访问到

## 参考标准

- OWASP Top 10 A01:2021 — Broken Access Control (信息泄露子集)
- OWASP Top 10 A05:2021 — Security Misconfiguration
- CWE-200: Exposure of Sensitive Information to an Unauthorized Actor
- CWE-209: Generation of Error Message Containing Sensitive Information
- CWE-598: Information Exposure Through Query Strings in GET Request
- CWE-1295: Debug Messages Revealing Unnecessary Information
