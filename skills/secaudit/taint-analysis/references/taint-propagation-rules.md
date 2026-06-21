# 污点传播规则参考

## 污染源 (Taint Source) 速查

### 通用污染源

| 来源类型 | C/C++ | Go | Java | Python | JavaScript/Node.js |
|---------|-------|-----|------|--------|-------------------|
| HTTP Query | `getenv("QUERY_STRING")` | `r.URL.Query()` | `request.getParameter()` | `request.GET`/`request.args` | `req.query` / `URLSearchParams` |
| HTTP Body | CGI `stdin` 读取 | `r.Body` / `r.FormValue()` | `request.getInputStream()` | `request.POST`/`request.json` | `req.body` / `req.json()` |
| HTTP Headers | `getenv("HTTP_*")` | `r.Header.Get()` | `request.getHeader()` | `request.META`/`request.headers` | `req.headers` / `req.get()` |
| Cookies | `getenv("HTTP_COOKIE")` | `r.Cookie()` | `request.getCookies()` | `request.COOKIES` | `req.cookies` / `document.cookie` |
| URL Path | CGI `PATH_INFO` | `r.URL.Path` / mux vars | `@PathParam` / `@PathVariable` | URL dispatcher params | `req.params` / `:id` routes |
| CLI Args | `argv[]` / `argc` | `os.Args` | `main(String[] args)` | `sys.argv` / `argparse` | `process.argv` |
| 环境变量 | `getenv()` | `os.Getenv()` | `System.getenv()` | `os.environ` / `os.getenv()` | `process.env` |
| 文件内容 | `fread()` / `read()` | `os.ReadFile()` | `Files.readString()` | `open().read()` | `fs.readFileSync()` |
| 数据库结果 | SQL 查询结果 | `rows.Scan()` | `ResultSet.getString()` | `cursor.fetchone()` | `db.query()` 结果 |
| 第三方 API | libcurl 响应 | `http.Get()` 响应 | `HttpClient.execute()` | `requests.get()` / `urllib` | `fetch()` / `axios()` 响应 |

## 危险操作点 (Sink) 速查

| Sink 类型 | C/C++ | Go | Java | Python | JavaScript/Node.js |
|----------|-------|-----|------|--------|-------------------|
| SQL 执行 | `mysql_query()` / SQLite | `db.Query()` / `db.Exec()` | `Statement.execute()` / JPA | `cursor.execute()` | `db.query()` / `db.run()` |
| 命令执行 | `system()` / `popen()` / `exec*()` | `exec.Command()` / `os.exec` | `Runtime.exec()` / `ProcessBuilder` | `os.system()` / `subprocess` | `child_process.exec()` / `execSync()` |
| 代码执行 | `dlopen()` + dlsym | `plugin.Open()` | `ScriptEngine.eval()` | `eval()` / `exec()` / `compile()` | `eval()` / `new Function()` / `vm.runInNewContext()` |
| 文件操作 | `fopen()` / `open()` / `rename()` | `os.Open()` / `os.Create()` | `FileInputStream` / `Files.write` | `open()` / `shutil` | `fs.writeFile()` / `fs.createWriteStream()` |
| 模板渲染 | — | `template.Execute()` | `Thymeleaf` / `FreeMarker` | `render_template()` / Jinja2 | `ejs.render()` / `pug.compile()` |
| 反序列化 | — | `json.Unmarshal()` + interface | `ObjectInputStream.readObject()` | `pickle.load()` / `yaml.load()` | `JSON.parse()` + eval |
| LDAP 查询 | `ldap_search()` | `ldap.Search()` | `DirContext.search()` | `ldap3` / `python-ldap` | `ldapjs` |
| XPath 查询 | `xmlXPathEval()` | `xmlpath` | `XPath.evaluate()` | `lxml.etree.XPath` | `xpath` / `DOMXPath` |
| HTTP 重定向 | — | `http.Redirect()` 拼接 | `response.sendRedirect()` | `redirect()` / `HttpResponseRedirect` | `res.redirect()` |
| 日志输出 | `syslog()` | `log.Printf()` | `log.info()` / `logger` | `logging.info()` / `loguru` | `console.log()` / `winston` |

## 净化函数 (Sanitizer) 速查

| 净化目标 | C/C++ | Go | Java | Python | JavaScript |
|---------|-------|-----|------|--------|-----------|
| HTML XSS | — | `html.EscapeString()` | `StringEscapeUtils.escapeHtml4()` | `html.escape()` / `markupsafe` | `DOMPurify.sanitize()` |
| SQL 注入 | 参数化查询 | 占位符 `$1`/`?` | `PreparedStatement` | 参数化 `%s` | 参数化查询 |
| Shell 注入 | `execvp()` 而非 `system()` | 无 shell 模式 | 数组形式 ProcessBuilder | `subprocess.run([...])` | `spawn()` 而非 `exec()` |
| 路径穿越 | `realpath()` | `filepath.Clean()` + 前缀检查 | `Paths.get().normalize()` + 前缀检查 | `os.path.realpath()` + 白名单 | `path.resolve()` + 前缀检查 |
| LDAP 注入 | `ldap_escape_filter()` | RFC 4515 转义 | `LdapEncoder.filterEncode()` | `ldap3.utils.dn.escape_filter_chars()` | `ldap-escape` |
| 日志注入 | 拒绝 `\n` `\r` 字符 | `strings.ReplaceAll(s, "\n", "")` | 过滤换行符 | `s.replace('\n', '')` | `s.replace(/\n/g, '')` |

## 传播规则汇总

| 操作 | 传播行为 | 说明 |
|------|---------|------|
| 直接赋值 `b = a` | 污染传播 | a 被污染 → b 被污染 |
| 字符串拼接 `"prefix" + tainted` | 污染传播 | 拼接结果被污染 |
| 字符串格式化 `f"{tainted}"` | 污染传播 | 格式化结果被污染 |
| 数组索引 `arr[tainted]` | 污染传播到值 | 取出的元素被污染 |
| 字段访问 `obj.taintedField` | 污染传播 | 字段值被污染 |
| 函数返回值 `y = f(tainted)` | 传播（保守假设） | 除非已知 f 是净化函数 |
| 白名单校验 `if x in safe_set` | **净化** | 枚举验证通过后安全 |
| 类型转换 `int(tainted)` | 部分净化 | 防止注入但值仍可能不可信 |
| 显式转义 `html.escape(tainted)` | **净化** | 上下文特定的净化 |
| 参数化查询 `execute(sql, [tainted])` | **Sink 安全** | 数据不影响 SQL 语义 |
| 哈希 `sha256(tainted)` | **净化** | 不可逆，安全 |
