# JavaScript/TypeScript 语言特性参考

## 命令执行
| API | 风险 | 替代 |
|-----|------|------|
| `child_process.exec(cmd)` | Shell 注入（默认 shell=True） | `child_process.execFile(cmd, args)` |
| `child_process.execSync(cmd)` | Shell 注入 | execFileSync |
| `child_process.spawn(cmd, {shell: true})` | Shell 注入 | shell: false + args 数组 |

## 代码注入
| API | 风险 | 替代 |
|-----|------|------|
| `eval(userInput)` | 任意代码执行 | 禁用 |
| `Function(userInput)` | 等价于 eval | 禁用 |
| `new Function(body)` | 动态函数构造 | 禁用 |
| `setTimeout(stringCode)` | 字符串执行 | 只用函数引用 |
| `vm.runInNewContext(userCode)` | 沙箱可绕过 | 严格隔离+超时 |

## NoSQL 注入
| API | 风险 | 替代 |
|-----|------|------|
| `Model.find(req.body)` | 操作符注入 | 显式字段白名单 |
| `Model.findOne(req.query)` | 操作符注入 | 类型校验+过滤 `$` |
| `$where: \`this.field == '${input}'\`` | JS 代码注入 | 禁用 $where |

## SSTI (模板注入)
| API | 风险 | 替代 |
|-----|------|------|
| `ejs.render(userTemplate)` | SSTI→RCE | 静态模板文件 |
| `pug.compile(userInput)` | SSTI→RCE | 静态模板 |

## 原型污染
| 模式 | 风险 |
|------|------|
| 递归 `for...in` 合并无过滤 | `__proto__` 污染 |
| `_.merge(config, req.body)` | 旧版 lodash 原型污染 |
| `Object.assign(target, userInput)` | 嵌套赋值污染 |

## 路径穿越
| 模式 | 风险 |
|------|------|
| `path.join(base, userPath)` 无 resolve 校验 | ../ 越界 |
| `fs.readFile(req.query.file)` | 任意文件读取 |
| `express.static` 路径可控 | 目录遍历 |

## 加密安全
| API | 风险 | 替代 |
|-----|------|------|
| `crypto.createCipher('aes-128-ecb', key)` | ECB 模式 | `crypto.createCipheriv('aes-256-gcm')` |
| `crypto.createHash('md5')` 安全用途 | 弱哈希 | SHA-256+ |
| `Math.random()` 安全用途 | 非密码学 PRNG | `crypto.randomBytes()` |

## 前端安全
| 风险 | 说明 |
|------|------|
| `dangerouslySetInnerHTML` | React XSS 入口 |
| `v-html` | Vue XSS 入口 |
| `innerHTML` 赋值用户输入 | DOM XSS |
| `eval` / `new Function` | 代码注入 |
| `postMessage` 无 origin 校验 | 跨域消息劫持 |

## 框架注意
- Express: `app.set('env', 'production')` 需设置；Helmet 中间件推荐
- NestJS: `Class-validator` 配合 DTO 防止 Mass Assignment
- Next.js: `getServerSideProps` 不应泄露内部状态
- Mongoose: Schema `select: false` 标记密码字段
