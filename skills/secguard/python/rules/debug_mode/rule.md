---
name: secguard-python-debug-mode
description: "检测 DEBUG 模式 — Django DEBUG=True / Flask debug=True 生产环境"
language: python
topic: [web, configuration, security]
skill_id: python.debug-mode.django
signal_filter: python.debug-mode.django*
signal_source: call_sites[category="config"]
severity: medium
cwe: CWE-489
trigger_functions: [DEBUG, debug, app.run]
---

# DEBUG 模式检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE | Guard-rule |
|----------|---------------|-------------------|----------|-----|------------|
| `python.debug-mode.django` | `call_sites[cat="config"]` | `DEBUG=True`, `debug=True`, `app.run(debug=True)` | Medium | CWE-489 | — |

## Scenario 1: Django DEBUG 模式生产环境

### 威胁定义
Django `DEBUG=True` 在生产环境会显示完整错误页面（含源码、配置、SQL 查询），导致敏感信息泄露。Flask `app.debug = True` 或 `app.run(debug=True)` 类似风险 + Werkzeug 调试器可执行任意代码。

### 检测逻辑
```python
# BAD: Django DEBUG 生产环境
# settings.py
DEBUG = True  # 生产环境不应为 True

# BAD: Flask debug 模式
app.debug = True  # 或 app.run(debug=True)

# GOOD: 环境区分
import os
DEBUG = os.environ.get('DJANGO_DEBUG', 'False') == 'True'

# GOOD: Flask 条件 debug
if __name__ == '__main__':
    app.run(debug=os.environ.get('FLASK_ENV') == 'development')
```

### 检测模式
- **MATCH**: `DEBUG\s*=\s*(True|'True'|"True")` | `debug\s*=\s*True` | `app\.run\(.*debug\s*=\s*True`
- **EXCLUDE**: `os\.environ\|getenv\|env` 条件判断 | `if __name__ == '__main__'` 包裹 | 仅开发配置文件中

### 修复指引
1. Django: `DEBUG = os.environ.get('DJANGO_DEBUG', 'False') == 'True'`
2. Flask: 使用环境变量控制，`app.run(debug=os.environ.get('FLASK_ENV') == 'development')`
3. 生产环境配置中始终 `DEBUG = False`

## 证据收集指引

| 证据类型 | 要求 |
|----------|------|
| code_context | MUST — DEBUG 赋值行及上下文 |
| judgment_rationale | MUST — 是否为生产环境配置 |
| sanitizer_analysis | SHOULD — 是否有环境变量条件保护 |

## 输出格式

记录为 finding，标注 `severity: medium`，`cwe: CWE-489`。
