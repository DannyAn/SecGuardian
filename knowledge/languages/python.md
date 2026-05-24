---
category: language
languages: [python]
frameworks: [Django, Flask, FastAPI, SQLAlchemy, Celery, Jinja2]
---

# Python 语言安全画像

Python 的安全特性、危险函数清单和框架注意事项。

## 危险函数清单

### 命令执行
| 函数 | 风险 | 替代 |
|------|------|------|
| `os.system(cmd)` | Shell 注入 | `subprocess.run([...], shell=False)` |
| `os.popen(cmd)` | Shell 注入 | subprocess 模块 |
| `subprocess.getoutput(cmd)` | Shell 注入（默认 shell=True） | 显式 shell=False |
| `subprocess.Popen(cmd, shell=True)` | Shell 注入 | shell=False + 参数列表 |
| `eval(cmd)` / `exec(cmd)` | 代码执行 | 禁用 / 严格沙箱 |
| `compile(user_input, ...)` | 代码注入 | 禁止用户输入编译 |

### 代码注入
| 函数 | 风险 | 替代 |
|------|------|------|
| `pickle.load(untrusted)` | 任意代码执行 | JSON / msgpack |
| `yaml.load(untrusted)` | 任意代码执行 | `yaml.safe_load()` |
| `marshal.loads(untrusted)` | 内存破坏 | JSON |
| `dill.load(untrusted)` | 任意代码执行 | 禁用 |
| `importlib.import_module(user_input)` | 任意模块加载 | 白名单 |

### 模板注入 (SSTI)
| 模式 | 风险 |
|------|------|
| `Jinja2 template.render(user_input)` | SSTI — 沙箱绕过可能导致 RCE |
| `Mako Template(user_input)` | SSTI |
| Django 模板 `{% %}` 用户可控 | 仅变量注入风险 |
| `string.Template(user_input).substitute()` | 简单注入 |

### 路径穿越
| 模式 | 风险 |
|------|------|
| `open(user_path)` 直接使用 | 路径穿越 |
| `os.path.join(base, '../etc/passwd')` | 可能需要 canonicalize |
| `tarfile.extractall()` / `shutil.unpack_archive` | Zip Slip |
| `pathlib.Path(user_path)` 未验证 | 路径穿越 |

### SQL
| 模式 | 风险 | 替代 |
|------|------|------|
| `cursor.execute("SELECT ..." % user)` | SQL 注入 | 参数化 `%s` 或 `%(name)s` |
| `cursor.execute(f"SELECT {user}")` | SQL 注入 | 同上 |
| `SQLAlchemy text()` + 字符串拼接 | SQL 注入 | 绑定参数 `:param` |
| Django `raw()` + 字符串格式 | SQL 注入 | 使用 `%s` 占位符 |
| `cursor.execute("SELECT " + order_by)` | SQL 注入 | 白名单校验 ORDER BY |

### 加密
| 禁止 | 推荐 |
|------|------|
| `hashlib.md5()` | `hashlib.sha256()` |
| `random.random()` / `random.randint()` | `secrets.token_bytes()` / `os.urandom()` |
| `hashlib.sha1()` | `hashlib.sha256()` |
| 自定义密码哈希 | `bcrypt`, `passlib`, `hashlib.scrypt()` |

### 网络请求
| 模式 | 风险 | 替代 |
|------|------|------|
| `requests.get(user_url)` | SSRF | URL 白名单 + 内网 IP 黑名单 |
| Django `HttpResponse(user_html)` | XSS | 模板渲染自动编码 |
| `json.dumps(data)` → `HttpResponse` | XSS（浏览器嗅探 MIME） | `JsonResponse` + 正确 Content-Type |

## 框架特性

### Django
- `mark_safe()` 跳过自动编码 → 检查是否包含用户数据
- `render()` 自动编码 HTML，安全
- `DEBUG=True` 生产环境泄露源码
- `SECRET_KEY` 不应硬编码
- Django Admin 路径未修改默认 `/admin`

### Flask
- `render_template_string(user_input)` 存在 SSTI 风险
- `app.debug = True` 生产环境风险
- `app.secret_key` 硬编码
- Flask-Login session 保护检查

### FastAPI
- `Response(content=user_html, media_type="text/html")` → 手动编码
- 依赖注入路径中的认证覆盖检查
- CORS 宽松配置检查

## 检测优先级

1. `pickle.load`/`yaml.load` 不受信数据 → Critical
2. `subprocess(shell=True)` + 用户输入 → Critical
3. SSTI (render_template_string) → Critical
4. `eval`/`exec` + 用户输入 → Critical
5. SQL 字符串拼接 → High
6. DEBUG 模式生产环境 → High
