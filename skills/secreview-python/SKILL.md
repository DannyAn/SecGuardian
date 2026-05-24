---
name: secreview-python
description: 对 Python 代码进行通用安全规范检视，关注危险函数使用和安全编码规范
category: language-specific
language: python
---


# secreview-python

对 Python 代码进行通用安全规范检视，关注危险函数使用、安全函数规范和代码安全最佳实践。

## 检视范围

### 语义层面
- 是否使用了参数化查询（而非 f-string/% 格式）
- 是否调用了安全的序列化方法（JSON 而非 pickle）
- 是否使用了安全的密码学 API（secrets 而非 random）
- subprocess 调用是否避开了 shell=True

### 规范合规
- Django/Flask DEBUG 模式是否在生产环境关闭
- 模板渲染是否使用了自动编码（render vs render_template_string）
- CORS 配置是否过于宽松
- `JsonResponse` vs 手动 `HttpResponse` JSON 拼接

### 反模式识别
- `except Exception: pass` 吞掉异常
- `hasattr` 安全检查的局限性
- `__getattr__` 劫持攻击面
- 动态 `import_module` 或 `__import__` 滥用
- Monkey patch 导致的安全假设失效

## 与 secguard-python 的区别

| 维度 | secguard（加固排查） | secreview（规范检视） |
|------|---------------------|---------------------|
| 粒度 | 具体 API 调用级 | 函数/模块级语义 |
| 关注点 | 是否存在可利用漏洞 | 是否符合安全编码规范 |
| 输出 | 漏洞位置 + CVSS 级别 | 不合规项 + 修复建议 |
