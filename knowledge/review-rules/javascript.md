---
detector: review.javascript
type: review-rule
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "review.javascript",
  "type": "review-rule",
  "language": "javascript",
  "max_severity": "Critical",
  "cwe": "CWE-000",
  "anti_pattern_count": 18
}
```

# JavaScript/Node.js 安全反模式检测矩阵

## 原型污染 (Prototype Pollution)

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| 递归合并无 `__proto__` 过滤 | `for\s*\(.*in\s+source[^}]*target\[` 且无 `__proto__`/`constructor`/`prototype` 检查 | High |
| lodash `_.merge` 旧版本 | `_.merge\([^,]*,\s*req\.(body\|query)` | High |
| `qs.parse` + 对象合并 | `qs\.parse\(.*\)` → `Object\.assign\|_.merge` 使用解析结果 | High |
| 深层路径无过滤设置 | `\.split\(['"\`]\.['"\`]\)` 来自 `req\.body\|query` 的路径 | Medium |

## 异步错误处理

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| Promise 无 catch | `\.then\([^)]+\)$` 无 `.catch` | Medium |
| async 无 try-catch | `async function.*\{` 内部 `await` 且无 `try`/`catch` | Medium |
| catch 空块 | `.catch\(\s*\(\)\s*=>\s*\{\s*\}\)` | Medium |
| Express 未 next(err) | `catch.*\{.*console\.(error\|log).*\}[^n]` | Medium |

## 代码执行

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| `eval()` 使用 | `eval\(` | Critical |
| `new Function()` | `new\s+Function\(` | Critical |
| `setTimeout(string)` | `setTimeout\(['"\`]` | High |
| `vm.runInNewContext` | `vm\.runInNewContext\(.*req\|user` | Critical |

## 前端 XSS

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| `dangerouslySetInnerHTML` | `dangerouslySetInnerHTML\s*=\s*\{.*__html:\s*(?!.*DOMPurify)` | High |
| `v-html` 用户输入 | `v-html\s*=\s*['"\`]` + 外部数据源 | High |
| `innerHTML` 赋值 | `\.innerHTML\s*=\s*(?!.*textContent)` | High |
| `document.write` | `document\.write\(` | High |

## Cookie 安全

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| 缺少 secure 标志 | `cookie\(.*\{[^}]*\)` 且无 `secure:\s*true` | Medium |
| 缺少 httpOnly | cookie 设置无 `httpOnly:\s*true` | Medium |
| sameSite 宽松 | `sameSite\s*:\s*['\"](none\|lax)['\"]` 且无 `secure: true` | Medium |

## Crypto 误用

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| MD5 哈希安全用 | `createHash\(['\"]md5['\"]\)` 且上下文含 `pass\|auth\|sign\|token` | High |
| Math.random() 安全用 | `Math\.random\(\)` 用于 token/session ID 生成 | High |
| 硬编码密钥 | `const\s+\w*(KEY\|SECRET\|PWD\|PASSWORD)\w*\s*=\s*['\"]` | High |
| ECB 模式 | `createCipheriv\(['\"]aes-\d+-ecb` | High |

## 依赖安全

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| 已知漏洞包 | `package.json` 依赖版本在 CVE 范围内 | Critical |
| 未锁定版本 | `package.json` 使用 `*` / `latest` / `^` 无 `package-lock.json` | Medium |
| 已弃用包 | `require\(['\"]` 引入 npm deprecated 包 | Medium |
