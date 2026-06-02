# 注入攻击检测速查

## SQL 注入检测模式

### 各语言危险模式

| 语言 | 危险模式 | 安全模式 |
|------|---------|---------|
| Java | `Statement.execute("SELECT " + id)` / `"SELECT " + id` | `PreparedStatement ps = conn.prepareStatement("SELECT ?")` |
| Java (MyBatis) | `${userId}` (字符串替换) | `#{userId}` (参数化) |
| Java (JPA) | `entityManager.createNativeQuery("SELECT " + id)` | JPQL 参数绑定 + 输入校验 |
| Go | `db.Query(fmt.Sprintf("...%s", id))` / `db.Exec("..." + id)` | `db.Query("...WHERE id=$1", id)` |
| Go (GORM) | `db.Raw("SELECT * FROM users WHERE id=" + id)` | `db.Raw("SELECT * FROM users WHERE id=?", id)` |
| Python | `cursor.execute(f"SELECT * FROM users WHERE id={uid}")` | `cursor.execute("SELECT * FROM users WHERE id=%s", [uid])` |
| Python (Django) | `Model.objects.raw(f"SELECT * FROM {table}")` | ORM filter/exclude + 参数绑定 |
| JS/Node | `` db.query(`SELECT * FROM users WHERE id=${uid}`) `` | `db.query('SELECT * FROM users WHERE id=?', [uid])` |
| C/C++ | `sprintf(sql, "SELECT * FROM users WHERE id=%s", id)` + `mysql_query(sql)` | 使用预编译语句 API |

## 命令注入检测模式

### 各语言危险模式

| 语言 | 危险模式 | 安全模式 |
|------|---------|---------|
| C | `system(userInput)` / `popen(cmd, "r")` | `execvp(argv[0], argv)` + 参数数组 |
| C++ | `std::system(userString.c_str())` | `boost::process::child` + 参数数组 |
| Go | `exec.Command("sh", "-c", userInput)` | `exec.Command("ping", host)` — 不使用 shell |
| Java | `Runtime.getRuntime().exec("cmd " + userInput)` | `new ProcessBuilder("cmd", userInput)` — 不使用字符串拼接 |
| Python | `os.system(f"ping {host}")` / `subprocess.call(userInput, shell=True)` | `subprocess.run(["ping", host])` — 列表参数 + 不用 shell |
| JS/Node | `exec(userInput)` / `execSync("ls " + dir)` | `spawn('ls', [dir])` / `execFile('ls', [dir])` |

## XSS (跨站脚本) 检测

### 反射型 XSS

搜索将 HTTP 请求参数直接写入 HTTP 响应体而未编码的位置：

| 语言/框架 | 危险模式 | 安全模式 |
|----------|---------|---------|
| Java (JSP) | `<%= request.getParameter("q") %>` | `<c:out value="${param.q}"/>` / `fn:escapeXml()` |
| Java (Servlet) | `response.getWriter().write(userInput)` | `StringEscapeUtils.escapeHtml4(userInput)` |
| Python (Django) | `mark_safe(userInput)` / `{% autoescape off %}` | `render()` 默认编码 / ` |safe` 仅在已净化后使用 |
| Python (Flask) | `render_template_string(userInput)` | `render_template()` 自动编码 |
| Go | `template.HTML(userInput)` | `html/template` 自动编码（默认） |
| JS/Node | `res.send(userInput)` (HTML 内容) / `element.innerHTML = userInput` | `escapeHtml(userInput)` / `element.textContent = userInput` |
| React | `dangerouslySetInnerHTML={{__html: userInput}}` | JSX 默认编码 + DOMPurify |

### 存储型 XSS

检查存储到数据库/缓存后又在下游 HTML 渲染的用户输入：
- 输入是否在存储前净化
- 输出时是否在正确的上下文编码（HTML body / attribute / JavaScript / URL / CSS）

## 路径穿越检测

| 语言 | 危险模式 | 安全模式 |
|------|---------|---------|
| C | `fopen(userPath, "r")` 未调用 `realpath()` | `realpath(userPath, resolved)` + 前缀白名单 |
| C++ | `std::ifstream(userPath)` 未校验 | `std::filesystem::canonical(userPath)` + 白名单 |
| Go | `os.Open(filepath.Join(base, userInput))` | `filepath.Clean()` + 检验前缀包含 `base` |
| Java | `new File(base, userInput)` 未 `getCanonicalPath()` | `file.getCanonicalPath().startsWith(baseCanonical)` |
| Python | `open(os.path.join(base, userInput))` | `os.path.realpath()` + 前缀检查 |
| JS | `fs.readFile(path.join(base, userInput))` | `path.resolve()` + 检验前缀 |

## 注入优先级判定

| 注入类型 | 触发条件 | 严重度 |
|---------|---------|--------|
| 命令注入 (shell=true + 用户输入) | 总是 | Critical |
| SQL 注入 (拼接 + 无参数化) | 总是 | Critical |
| 代码注入 (eval/exec/compile + 用户输入) | 总是 | Critical |
| 路径穿越 (文件操作 + 用户可控路径) | 可写 → Critical, 可读 → High |
| SSTI (模板引擎 + 用户输入) | 总是 | Critical |
| XSS (存储型) | 多用户可见 → High |
| XSS (反射型) | 需要交互 → Medium |
| LDAP / XPath / XML 注入 | 取决于影响范围 |
