---
name: secguard-js-path_traversal
description: "Detects path traversal where user input controls file system paths"
language: javascript
topic: [path, traversal, filesystem]
skill_id: js.path_traversal
signal_filter: js.path_traversal*
signal_source: call_sites[category="fs"]
severity: high
cwe: [CWE-22]
trigger_functions: [fs.readFile, fs.readFileSync, fs.writeFile, fs.createReadStream, path.join, express.static, adm-zip, unzipper]
---

# path_traversal 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `js.path_traversal` |
| signal_source | `call_sites[cat="fs"]` |
| trigger_functions | `fs.readFile(userPath)`, `path.join(base, userPath)`, `express.static` 路径可控 |
| severity | High |
| CWE | CWE-22 |

## Scenario 1: 任意文件读取 / 路径穿越

### 威胁定义

攻击者通过 `../` 路径遍历读取服务器上的任意文件（`/etc/passwd`、配置文件、源码）。常见于文件下载 API 和静态文件服务器。

### 检测逻辑

```javascript
// BAD: 直接使用用户输入作为文件路径
fs.readFile('/app/data/' + req.query.file, (err, data) => {
    res.send(data);  // 攻击: ?file=../../etc/passwd
});

// BAD: path.join 无 resolve 校验
const filePath = path.join('/app/data', req.params.filename);
fs.createReadStream(filePath).pipe(res);

// GOOD: resolve + 前缀校验
const resolved = path.resolve('/app/data', req.params.filename);
if (!resolved.startsWith('/app/data/')) throw new Error('Invalid path');
fs.createReadStream(resolved).pipe(res);
```

### 检测模式

```
# MATCH
fs\.readFile(?:Sync)?\(.*req\.|fs\.readFile\(.*query|body|params
path\.join\(['"][^'"]+['"]\s*,\s*req\.|req\.|user|input
express\.static\(.*req\.|createReadStream\(.*req\.
adm-zip|unzipper.*extract.*req\.

# EXCLUDE
path\.resolve\(.*\) 且 startsWith 校验
path\.join\(.*['"][^'"]*['"]\)               # 仅拼接常量
\.startsWith\(['"][^'"]+['"]                # 前缀校验
isPathAllowed|sanitizePath|ALLOWED_DIRS
```

### 修复指引

1. `path.resolve()` + 强制 `startsWith` 白名单前缀校验
2. 禁止使用 `path.join()` 拼接用户输入而不做 resolve 校验
3. 解压库（adm-zip / unzipper）必须限制解压路径

## 证据收集指引

- **code_context**: 文件读取的完整代码及路径构造方式
- **judgment_rationale**: 路径是否来自用户输入，路径规范化+校验是否存在

## 输出格式

三段式: Source（req.query.file/req.params.filename）→ Propagate（path.join/字符串拼接）→ Sink（fs.readFile/createReadStream）。
