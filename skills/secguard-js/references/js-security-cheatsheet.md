# JavaScript/Node.js 安全检测速查表

## 命令注入检测

| 危险模式 | 示例 | 安全替代 |
|---------|------|---------|
| `exec(cmd)` 含用户输入 | `exec('ls ' + userDir)` | `execFile('ls', [userDir])` |
| `execSync(cmd)` 含用户输入 | `execSync('git log ' + branch)` | `execFileSync('git', ['log', branch])` |
| `spawn(cmd, {shell: true})` | `spawn(userCmd, {shell: true})` | `spawn(cmd, args, {shell: false})` |
| `require('child_process').exec` | 同上 | execFile |

## NoSQL 注入检测

| 危险模式 | 示例 | 安全替代 |
|---------|------|---------|
| `Model.find(req.body)` | 操作符 `$ne`/`$gt` 可注入 | `Model.find({username: req.body.username})` |
| `Model.findOne(req.query)` | query 参数注入 | 显式字段 + 类型校验 |
| `$where: 模板字符串` | `` $where: `this.name=='${name}'` `` | 禁用 $where |
| `$function: {body: input}` | MongoDB 4.4+ JS 执行 | 禁用 $function |
| `aggregate(req.body.pipeline)` | 管道完全可控 | 固化管道结构 |

## 原型污染检测

| 危险模式 | 示例 | 安全替代 |
|---------|------|---------|
| 递归合并无过滤 | `function merge(t,s){for(k in s)t[k]=s[k]}` | 过滤 `__proto__` |
| lodash `_.merge` | `_.merge(config, req.body)` | 升级 lodash >= 4.17.21 |
| `Object.assign` | `Object.assign(target, userData)` | 浅合并 + 过滤 |
| 深层路径赋值 | `obj[path] = value` (path 可控) | 路径白名单 |
| `qs.parse` + 合并 | 解析 `?__proto__[x]=y` | 过滤 `__proto__` |

## 路径穿越检测

| 危险模式 | 示例 | 安全替代 |
|---------|------|---------|
| `fs.readFile(userPath)` 无校验 | `fs.readFile(req.query.file)` | `path.resolve` + 前缀校验 |
| `path.join(base, userPath)` 无 resolve | `path.join('/var/www', '../etc')` | resolve 后前缀检查 |
| `express.static(dir)` 目录遍历 | `app.use('/files', express.static(userDir))` | 固定目录 |
| ZIP 解压路径无校验 | `entry.path` 含 `../` | 检查解压目标路径 |

## 加密误用检测

| 危险模式 | 示例 | 安全替代 |
|---------|------|---------|
| ECB 模式 | `createCipheriv('aes-128-ecb')` | `createCipheriv('aes-256-gcm')` |
| MD5 安全用途 | `createHash('md5')` 存密码 | `bcrypt.hash()` |
| `Math.random()` 安全用途 | 生成 token/session ID | `crypto.randomBytes()` |
| 固定 IV | `const iv = Buffer.from('0123456789abcdef')` | `crypto.randomBytes(16)` |
| 硬编码密钥 | `const KEY = 'my-secret-key'` | `process.env.SECRET_KEY` |

## 信息泄露检测

| 危险模式 | 示例 |
|---------|------|
| `res.send(err.stack)` | 堆栈返回客户端 |
| `app.set('env', 'development')` 生产环境 | Express 开发模式 |
| `NODE_ENV=development` 生产环境 | Node 环境变量 |
| `app.use(morgan('dev'))` 生产环境 | 开发日志格式 |
| `require('inspector').open()` | 调试器端口暴露 |
