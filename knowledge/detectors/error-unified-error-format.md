---
detector: error-unified-error-format
severity: medium
cwe: CWE-544
language: [java, python, go, js]
tags: [error, consistency, api-design, response-format]
---

# 错误格式不统一 (Non-Unified Error Format)

## 威胁定义

API 在不同层级返回多种不兼容的错误格式（纯文本/JSON对象/HTML页面），客户端无法统一处理，且某些格式可能包含更多内部信息（堆栈、SQL语句）致泄露。

**核心原则：所有 API 错误响应必须使用统一格式（如 `{"error": "message", "code": "ERR_XXX", "request_id": "..."}`）。**

## 检测逻辑

### Step 1: 同一项目中多种错误格式

检查代码中是否存在多种不同格式的错误返回：

```java
// 格式 1: 字符串
return "User not found";

// 格式 2: JSON Object
return ResponseEntity.status(404).body(Map.of("error", "Not Found"));

// 格式 3: 自定义 ErrorResponse
return new ErrorResponse(404, "Not Found");

// 格式 4: 异常直接抛出（框架默认格式）
throw new NotFoundException("User 123 not found");
```

```python
# 格式 1: 字符串
return "Error: invalid input", 400

# 格式 2: JSON
return jsonify({"error": "Invalid input"}), 400

# 格式 3: Flask-RESTful abort
abort(400, message="Invalid input")

# 格式 4: Django REST 框架格式
return Response({"detail": "Invalid input"}, status=400)
```

### Step 2: 不包含标准错误字段

检测错误响应是否缺少关键字段：
- 缺少 `error_code`（业务错误码，用于客户端区分）
- 缺少 `request_id`/`trace_id`（排查追踪）
- 缺少标准 HTTP 状态码映射

### Step 3: 敏感信息在不同格式间泄露

某些错误格式包含更多内部信息（如自定义 ErrorResponse 类包含堆栈），如果混用可能在某些路径泄露。

## 修复指引

1. 定义统一错误响应格式：`{"error": "message", "code": "ERR_XXX", "request_id": "uuid"}`
2. 使用全局异常处理器统一转换（`@ControllerAdvice` / Flask `errorhandler` / Express error middleware）
3. 禁止在 Controller/Handler 中直接 `return "error string"` 字符串

## 误报排除

| 场景 | 原因 |
|------|------|
| 新旧 API 版本过渡期（v1/v2 格式不同） | 版本演进 |
| 中间件统一包装了最终格式（如 `@ControllerAdvice`） | 有全局处理器 |
| 内部微服务已使用统一错误处理库 | 有共享库 |
| 测试代码 | 非生产 |

## 检测模式汇总

```
# 检测多种错误返回格式共存
return\s+ResponseEntity.*body\(Map\.of
return\s+"             # 字符串返回
throw new \w+Exception  # 异常传播

# 同一 Controller/模块中 ≥2 种不同格式
```
