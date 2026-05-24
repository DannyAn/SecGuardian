---
name: secguard-python
description: 对 Python 代码进行安全加固项排查，扫描危险函数调用和常见漏洞模式
category: language-specific
language: python
---


# secguard-python

对 Python 代码进行安全加固项排查，扫描代码和 PR 中需要安全加固的问题。

## 执行流程

1. 加载 `knowledge/languages/python.md` 获取 Python 危险函数清单
2. 加载各 `knowledge/concepts/*.md` 获取安全概念和检测逻辑
3. 扫描目标代码，按以下优先级匹配:

### 检查优先级

| 优先级 | 问题类型 | 核心检测逻辑 |
|--------|---------|-------------|
| Critical | 反序列化漏洞 | pickle.load / yaml.load / dill.load 不可信数据 |
| Critical | 命令注入 | os.system / subprocess(shell=True) + 用户输入 |
| Critical | SSTI | Jinja2 render_template_string / Mako Template 用户输入 |
| Critical | 代码注入 | eval / exec / compile / import_module 用户可控 |
| High | SQL 注入 | cursor.execute + 字符串格式 / f-string / % |
| High | 路径穿越 | open(user_path) / tarfile.extractall / shutil |
| High | SSRF | requests.get(user_url) 未验证 |
| High | 弱加密 | hashlib.md5 / random.random / SHA-1 |
| High | 硬编码密钥 | API Key / SECRET_KEY / Password 硬编码 |
| Medium | DEBUG 模式 | Django DEBUG=True / Flask debug=True 生产环境 |
| Medium | XSS | render_template_string vs render_template / mark_safe |

### 框架覆盖
- Django (ORM, 模板, 安全中间件)
- Flask (Jinja2, Flask-Login, WTForms)
- FastAPI (依赖注入, Pydantic, Response)
- SQLAlchemy (ORM, Core, text())
- Celery (任务序列化安全)
