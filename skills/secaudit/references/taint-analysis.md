# Taint Analysis — 污点分析参考

> 追踪不可信数据从 Source（输入点）到 Sink（危险操作）的完整传播路径。

## 何时使用

适用于需要追踪外部输入流向的审计域：
- Input Validation — 追踪用户输入到 SQL 执行/命令执行/XSS 输出
- Authorization — 追踪用户角色/权限参数到访问控制决策点
- Dependency Security — 追踪第三方输入到代码执行

## Source 识别

常见不可信数据源：

| 类别 | 示例 |
|------|------|
| HTTP 请求 | request.body, request.query, request.headers, request.cookies |
| 文件上传 | uploaded file contents, filename, MIME type |
| 外部 API | webhook payload, message queue messages, RPC parameters |
| 环境变量 | process.env, os.environ, system properties |
| 用户输入 | CLI arguments, stdin, form fields |
| 数据库外部数据 | externally-originated records (用户创建的内容) |

## Propagation 追踪

跟踪数据在代码中的流动路径：

- **赋值传播**: `x = source` → `y = x` → `sink(y)`
- **函数调用传播**: `x = source` → `result = process(x)` → `sink(result)`
- **返回值传播**: `source → get_data() → return` → `data = get_data()`
- **集合传播**: source 进入 list/dict/set 后从另一端取出仍是污点
- **拼接传播**: `query = "SELECT * FROM " + table_name`（字符串拼接保留污点）
- **编码/解码**: URL 编码/Base64 编码不消除污点，只改变形式

## Sink 识别

危险操作（不可信数据不应到达此处）：

| 类别 | 模式 |
|------|------|
| SQL 执行 | cursor.execute(), db.query(), session.execute(), raw SQL |
| 命令执行 | os.system(), subprocess.run(), exec(), eval(), Runtime.exec() |
| 文件操作 | open(), write(), FileOutputStream, file_put_contents() |
| HTML 输出 | innerHTML, response.write(), template.render(), dangerouslySetInnerHTML |
| 重定向 | redirect(), sendRedirect(), Location header |
| LDAP 查询 | ldap.search(), DirectorySearcher |
| XML 解析 | parse(), XMLReader, DocumentBuilder (XXE) |
| 序列化 | pickle.loads(), unserialize(), readObject() |

## 执行步骤

1. 枚举当前审计域内所有外部输入点（Source）
2. 对每个 Source，标记其数据变量为"污点"
3. 遍历代码路径，跟踪污点数据的赋值/函数调用/返回值传播
4. 识别污点数据是否到达 Sink
5. 验证 Sink 处是否使用了安全处理（参数化查询、净化、编码等）
6. 输出完整的 Source → Propagation → Sink 链路
