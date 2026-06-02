---
name: secreview-python
description: 对 Python 代码进行通用安全规范检视，关注危险函数使用和安全编码规范。当用户请求Python代码规范检视、Python反模式识别、Python安全编码规范、Django/Flask最佳实践时使用。
category: language-specific
language: python
topic: [web, crypto, system]
---

# 安全规范检视 — Python

对 Python 代码进行通用安全规范检视，关注危险函数使用、安全函数规范和代码安全最佳实践。

> **前置**: Command 层面已执行 `secguardian-index` 生成 `index.json`。检视时优先利用符号表定位目标，而非逐个文件遍历。

## 执行流程

### Phase 1: 加载上下文

1. 读取 `index.json`，获取 `files`、`symbols.functions`、`call_graph.edges`
2. 加载 `knowledge/languages/python.md` 获取 Python 危险函数清单

### Phase 2: 语义层面检视

| # | 检查项 | 检测方法 | 示例：不合规 |
|---|--------|---------|-------------|
| 1 | SQL 参数化 | 搜索 `cursor.execute`/`.raw()` → SQL 字符串是否使用 f-string/%/.format 拼接 | `cursor.execute(f"SELECT * FROM users WHERE id={uid}")` → 应使用 `cursor.execute("SELECT ... WHERE id=%s", [uid])` |
| 2 | 序列化安全 | 搜索 `pickle.load`/`yaml.load`/`dill.load` → 数据源是否可信 | `pickle.loads(request.data)` → 使用 `json.loads()` 替代 |
| 3 | 密码学安全 | 搜索 `random.randint`/`random.choice` → 是否用于安全场景 | `random.randint(0, 999999)` 做验证码 → 使用 `secrets.randbelow()` |
| 4 | subprocess 安全 | 搜索 `os.system`/`subprocess.call` → `shell` 参数 + 用户输入 | `subprocess.call(f"ping {host}", shell=True)` → 使用 `subprocess.call(["ping", host])` |

### Phase 3: 规范合规检视

| # | 检查项 | 检测方法 | 修复指引 |
|---|--------|---------|---------|
| 1 | DEBUG 模式 | 搜索 `DEBUG = True` → 是否在生产配置中 | 生产环境 `DEBUG = False`，使用环境变量或独立 settings 模块控制 |
| 2 | 模板安全 | 搜索 `render_template_string`/`render` → 是否对用户输入自动编码 | 使用 `render_template`（自动编码），避免 `render_template_string(user_input)` |
| 3 | CORS 配置 | 搜索 `CORS_ORIGIN_ALLOW_ALL`/`allow_origins` → 是否过宽 | 白名单指定 origin，禁用 `allow_origins=['*']` |
| 4 | JSON 响应 | 搜索 `HttpResponse(json.dumps(data))` → 手动拼接 JSON | 使用 `JsonResponse(data)` 确保 Content-Type 正确且自动编码 |

### Phase 4: 反模式识别

| # | 反模式 | 检测特征 | 修复方案 |
|---|--------|---------|---------|
| 1 | 裸 except 吞异常 | `except Exception: pass` / `except: pass` | 至少记录日志 `logger.exception()`，明确捕获的异常类型 |
| 2 | hasattr 安全检查局限性 | `if hasattr(obj, 'is_admin')` 做权限校验 | 使用显式属性字典或访问控制列表（ACL），不依赖属性存在性 |
| 3 | __getattr__ 劫持 | 自定义 `__getattr__` 无管控地返回动态属性 | 限制 `__getattr__` 返回的属性范围，对安全敏感属性额外校验 |
| 4 | 动态导入滥用 | `importlib.import_module(user_input)` / `__import__(user_input)` | 禁止基于用户输入的动态导入，使用注册表/映射表替代 |
| 5 | Monkey Patch 安全假设 | 运行时替换模块函数导致安全逻辑失效 | 关键安全函数标记为不可 monkey patch，使用 `wrapt.decorator` 做包装 |

### Phase 5: 输出

按 `knowledge/protocols/scan-output.md` 生成报告（`report.md` + `results.sarif` + `summary.json`）。

## 与 secguard-python 的区别

| 维度 | secguard（加固排查） | secreview（规范检视） |
|------|---------------------|---------------------|
| 粒度 | 具体 API 调用级 | 函数/模块级语义 |
| 关注点 | 是否存在可利用漏洞 | 是否符合安全编码规范 |
| 输出 | 漏洞位置 + CVSS 级别 | 不合规项 + 修复建议 |
| 覆盖 | CWE Top 25 + 检测器 | OWASP + Python 安全最佳实践 |
