---
name: secguard-js-info_leak
description: "Detects information leakage through error responses, debug middleware, and non-production environment settings"
language: javascript
topic: [info, leak, exposure]
skill_id: js.info_leak
signal_filter: js.info_leak*
signal_source: call_sites[category="output"]
severity: medium
cwe: [CWE-200]
trigger_functions: [res.send(err), res.json(err), stack trace in response, NODE_ENV, morgan dev, debug middleware]
---

# info_leak 检测规则

## 概要

| 字段 | 值 |
|------|-----|
| skill_id | `js.info_leak` |
| signal_source | `call_sites[cat="output"]` |
| trigger_functions | `res.send(err.stack)`, `NODE_ENV != 'production'`, debug 中间件, verbose error handler |
| severity | Medium |
| CWE | CWE-200 |

## Scenario 1: 错误信息泄露 / 环境配置泄露

### 威胁定义

服务器错误堆栈、调试信息或敏感配置被返回给客户端，攻击者可借此了解系统架构、第三方库版本、文件路径等，为进一步攻击铺路。

### 检测逻辑

```javascript
// BAD: 返回堆栈给客户端
app.use((err, req, res, next) => {
    res.status(500).send(err.stack);  // 泄露文件路径和代码上下文
});

// BAD: NODE_ENV 非 production
if (app.get('env') !== 'production') {
    // 开发模式中间件应在生产环境关闭
    app.use(morgan('dev'));
}

// GOOD: 通用错误处理，不泄露细节
app.use((err, req, res, next) => {
    console.error(err.stack);           // 仅服务端日志
    res.status(500).send('Internal Error');
});
```

### 检测模式

```
# MATCH
\.send\(err|\.json\(err|\.send\(.*stack|\.json\(.*stack
morgan\(['"]dev['"]|morgan\('combined'              # verbose 日志
app\.set\(['"]env['"].*!==\s*['"]production['"]
debug|trace\(.*req\.|verbose.*error

# EXCLUDE
send\(['"]Internal|send\('Error'|send\('error   # 通用错误消息
process\.env\.NODE_ENV\s*===\s*['"]prod    # 条件限定
app\.set\('env',\s*['"]production['"]\)
```

### 修复指引

1. 生产环境设置 `NODE_ENV=production`
2. 通用错误处理，不向前端返回堆栈
3. 关闭 `morgan('dev')` / debug 中间件

## 证据收集指引

- **code_context**: 错误处理中间件或响应构建的完整代码
- **judgment_rationale**: 返回内容是否包含敏感信息（堆栈/路径/依赖版本）

## 输出格式

三段式: Source（服务端错误/调试数据）→ Propagate（错误处理中间件）→ Sink（res.send/res.json 返回到客户端）。
