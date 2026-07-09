# Python 语言特性参考

## 命令执行
| 函数 | 风险 | 替代 |
|------|------|------|
| `os.system(cmd)` | Shell 注入 | `subprocess.run([...], shell=False)` |
| `os.popen(cmd)` | Shell 注入 | subprocess 模块 |
| `subprocess.getoutput(cmd)` | Shell 注入（默认 shell=True） | 显式 shell=False |
| `subprocess.Popen(cmd, shell=True)` | Shell 注入 | shell=False + 参数列表 |
| `eval(cmd)` / `exec(cmd)` | 代码执行 | 禁用 / 严格沙箱 |

## 反序列化
| 函数 | 风险 | 替代 |
|------|------|------|
| `pickle.load(untrusted)` | 任意代码执行 | JSON / msgpack |
| `yaml.load(untrusted)` | 任意代码执行 | `yaml.safe_load()` |
| `marshal.loads(untrusted)` | 内存破坏 | JSON |

## SSTI (模板注入)
| 模式 | 风险 |
|------|------|
| `Jinja2 template.render(user_input)` | SSTI — 沙箱绕过可能导致 RCE |
| `Mako Template(user_input)` | SSTI |
| Django 模板 `{% %}` 用户可控 | 仅变量注入风险 |

## 路径穿越
| 模式 | 风险 |
|------|------|
| `open(user_path)` 直接使用 | 路径穿越 |
| `os.path.join(base, '../etc/passwd')` | 可能需要 canonicalize |
| `tarfile.extractall()` / `shutil.unpack_archive` | Zip Slip |

## SQL 注入
| 模式 | 风险 | 替代 |
|------|------|------|
| `cursor.execute("SELECT ..." % user)` | SQL 注入 | 参数化 `%s` 或 `%(name)s` |
| `cursor.execute(f"SELECT {user}")` | SQL 注入 | 同上 |
| `SQLAlchemy text()` + 字符串拼接 | SQL 注入 | 绑定参数 `:param` |

## 加密安全
| 禁止 | 推荐 |
|------|------|
| `hashlib.md5()` | `hashlib.sha256()` |
| `random.random()` / `random.randint()` | `secrets.token_bytes()` / `os.urandom()` |
| `hashlib.sha1()` | `hashlib.sha256()` |
| 自定义密码哈希 | `bcrypt`, `passlib`, `hashlib.scrypt()` |

## 网络请求
| 模式 | 风险 | 替代 |
|------|------|------|
| `requests.get(user_url)` | SSRF | URL 白名单 + 内网 IP 黑名单 |
| Django `HttpResponse(user_html)` | XSS | 模板渲染自动编码 |

## 框架注意
- Django: `mark_safe()` 跳过自动编码 → 检查是否包含用户数据；`render()` 自动编码 HTML（安全）
- Flask: `render_template_string(user_input)` 存在 SSTI 风险；`app.debug = True` 生产环境风险
- FastAPI: `Response(content=user_html, media_type="text/html")` → 手动编码风险
