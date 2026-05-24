# Python 安全速查表

SecGuard 快速参考：Python 常见漏洞模式速查。

## Top 10 检测信号

| # | 检测信号 | 严重度 | 关联概念 |
|---|---------|--------|---------|
| 1 | `pickle.load(untrusted)` | Critical | deserialization |
| 2 | `yaml.load(untrusted)` 非 `safe_load` | Critical | deserialization |
| 3 | `eval(user_input)` / `exec(user_input)` | Critical | code-injection |
| 4 | `os.system(cmd)` / `subprocess(shell=True)` + 用户输入 | Critical | command-injection |
| 5 | `cursor.execute(f"...{user}...")` f-string | Critical | sql-injection |
| 6 | `render_template_string(user_input)` | Critical | ssti |
| 7 | `hashlib.md5()` 安全用途 | High | weak-cryptography |
| 8 | `random.random()` 安全用途 | High | weak-cryptography |
| 9 | `requests.get(user_url)` 未验证 | High | ssrf |
| 10 | `DEBUG=True` 生产环境 | High | information-leakage |

## Django 常见问题

- `SECRET_KEY` 硬编码
- `DEBUG=True` 未关闭
- `mark_safe()` 包含用户数据
- Admin 路径使用默认 `/admin`

## Flask/FastAPI 常见问题

- `app.debug = True` 生产环境
- `render_template_string()` 用户模板
- CORS `allow_origins=["*"]`
- Response 手动拼接 HTML 未编码
