---
description: 安全编码规范审查 — 反模式识别 + 最佳实践合规
---

# /secreview — 安全编码规范审查

检视危险函数使用、安全函数规范、代码反模式和最佳实践合规。

## 使用方式

```
/secreview ./src
/secreview ./src java
/secreview ./src python
/secreview ./src cpp
/secreview ./src go
```

## 检视范围

- 规范合规: 密码学 API、HTTP 安全头、认证授权
- 反模式识别: 吞异常、DEBUG 泄露、类型安全破坏、资源管理违规
- 最佳实践: 框架安全配置、语言特性陷阱、并发安全模式

## 自动语言检测

根据 path 下文件扩展名分布:
- .java → skill secreview-java
- .py → skill secreview-python
- .c .cpp → skill secreview-cpp
- .go → skill secreview-go
