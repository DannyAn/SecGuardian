---
category: language
languages: [javascript, typescript]
frameworks: [Express, NestJS, Next.js, React, Vue SSR, Mongoose, Sequelize, Prisma, AWS Lambda]
---

# JavaScript/Node.js 语言安全画像

JavaScript/TypeScript 的安全特性、危险 API 清单和常见反模式。

## 危险 API 清单

### 命令执行
| API | 风险 | 替代 |
|-----|------|------|
| `child_process.exec(cmd)` | Shell 注入（默认 shell=True） | `child_process.execFile(cmd, args)` |
| `child_process.execSync(cmd)` | Shell 注入 | execFileSync |
| `child_process.spawn(cmd, {shell: true})` | Shell 注入 | shell: false + args 数组 |
| `require('child_process').exec(cmd)` | Shell 注入 | execFile |

### 代码注入
| API | 风险 | 替代 |
|-----|------|------|
| `eval(userInput)` | 任意代码执行 | 禁用 |
| `Function(userInput)` | 等价于 eval | 禁用 |
| `new Function(body)` | 动态函数构造 | 禁用 |
| `setTimeout(stringCode)` | 字符串执行 | 只用函数引用 |
| `vm.runInNewContext(userCode)` | 沙箱可绕过 | 严格隔离+超时 |

### NoSQL 注入
| API | 风险 | 替代 |
|-----|------|------|
| `Model.find(req.body)` | 操作符注入 | 显式字段白名单 |
| `Model.findOne(req.query)` | 操作符注入 | 类型校验+过滤 `$` |
| `$where: \`this.field == '${input}'\`` | JS 代码注入 | 禁用 $where |
| `Model.aggregate(req.body.pipeline)` | 管道注入 | 固化管道结构 |
| `$function: {body: input}` | JS 代码执行 | 禁用 |

### 模板注入 (SSTI)
| API | 风险 | 替代 |
|-----|------|------|
| `ejs.render(userTemplate)` | SSTI→RCE | 静态模板文件 |
| `pug.compile(userInput)` | SSTI→RCE | 静态模板 |
| `Handlebars.compile(userInput)` | 有限 SSTI | 静态模板 |
| `nunjucks.renderString(userInput)` | SSTI | 静态模板 |

### 原型污染
| 模式 | 风险 |
|------|------|
| 递归 `for...in` 合并无过滤 | `__proto__` 污染 |
| `_.merge(config, req.body)` | 旧版 lodash 原型污染 |
| `Object.assign(target, userInput)` | 嵌套赋值污染 |
| `qs.parse(url)` + 合并配置 | URL query → 原型污染 |
| 深层路径赋值 `obj[path] = value` | `__proto__` 路径 |

### 路径穿越
| 模式 | 风险 |
|------|------|
| `path.join(base, userPath)` 无 resolve 校验 | ../ 越界 |
| `fs.readFile(req.query.file)` | 任意文件读取 |
| `express.static` 路径可控 | 目录遍历 |
| `adm-zip` / `unzipper` 解压路径可控 | Zip Slip |

### 加密
| API | 风险 | 替代 |
|-----|------|------|
| `crypto.createCipher('aes-128-ecb', key)` | ECB 模式 | `crypto.createCipheriv('aes-256-gcm')` |
| `crypto.createHash('md5')` 安全用途 | 弱哈希 | SHA-256+ |
| `Math.random()` 安全用途 | 非密码学 PRNG | `crypto.randomBytes()` |
| `crypto.createCipheriv` 固定 IV | 密文模式泄露 | `crypto.randomBytes(16)` |

### SSR 安全
| 风险 | 影响 |
|------|------|
| Next.js `getServerSideProps` 返回敏感数据到客户端 | 信息泄露 |
| Vue SSR `asyncData` 泄露 API 密钥 | 凭据泄露 |
| SSR 状态序列化含 `__proto__` | 原型污染 |
| SSR HTML 未转义危险字符 | XSS |

## 框架特别注意

### Express
- `app.set('env', 'production')` — 务必生产环境
- Helmet 中间件推荐（CSP/HSTS/X-Frame）
- `express.json({limit: '1mb'})` — 限制请求体大小
- cookie-session 应使用 `secure: true, httpOnly: true`

### NestJS
- Class-validator 配合 DTO 防止 Mass Assignment
- `@UseInterceptors` + ClassSerializerInterceptor 排除敏感字段
- Swagger/OpenAPI 关闭生产环境

### Next.js
- `next.config.js` 中的 `serverRuntimeConfig` vs `publicRuntimeConfig`
- API Routes 中的输入校验
- `getServerSideProps` 不应泄露内部状态
- CSP 头配置

### Mongoose
- Schema `select: false` 标记密码字段
- `immutable: true` 防止敏感字段被修改
- Virtual 字段不应包含敏感计算

## 前端安全关注点

| 风险 | 说明 |
|------|------|
| `dangerouslySetInnerHTML` | React XSS 入口 |
| `v-html` | Vue XSS 入口 |
| `innerHTML` 赋值用户输入 | DOM XSS |
| `document.write(userInput)` | DOM XSS |
| `eval` / `new Function` | 代码注入 |
| `postMessage` 无 origin 校验 | 跨域消息劫持 |
| `localStorage.setItem('token', jwt)` | Token 窃取风险 |
| Service Worker 缓存敏感数据 | 离线泄露 |
