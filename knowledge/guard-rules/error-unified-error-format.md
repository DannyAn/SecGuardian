---
detector: error-unified-error-format
description: Detects inconsistent or unstructured error reporting that hinders debugging
severity: medium
cwe: CWE-703
cvss: 4.5
language: [java, python, go, js]
tags: [error, consistency, api-design, response-format]
precision: very-high
confidence: dynamic
target_functions: [abort, body, code, code_context, errorCode, error_code, json, jsonify, judgment_rationale, requestId, request_id, status, trace_id, variable_state]
match_patterns: [return\s+ResponseEntity.*body\(Map\.of               # JSON Object 格式 (Java), return\s+"                                           # 纯字符串返回（所有语言）, throw new \w+Exception                                # 异常传播（框架默认格式）, jsonify\(|json\.dumps\(|JSON\.stringify\(             # 手动JSON序列化, abort\(|HttpResponseException                         # 框架特定格式]
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

API 在不同层级返回多种不兼容的错误格式（纯文本/JSON对象/HTML页面），客户端无法统一处理，且某些格式可能包含更多内部信息（堆栈、SQL语句）致泄露。

**核心原则：所有 API 错误响应必须使用统一格式（如 `{"error": "message", "code": "ERR_XXX", "request_id": "..."}`）。**

## 检测逻辑 (Detection Logic)

### Step 1: 同一项目中多种错误格式 (Detect Multiple Error Formats)

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

### Step 2: 不包含标准错误字段 (Missing Standard Error Fields)

检测错误响应是否缺少关键字段：
- 缺少 `error_code`（业务错误码，用于客户端区分）
- 缺少 `request_id`/`trace_id`（排查追踪）
- 缺少标准 HTTP 状态码映射

### Step 3: 敏感信息在不同格式间泄露 (Information Leakage Across Formats)

某些错误格式包含更多内部信息（如自定义 ErrorResponse 类包含堆栈），如果混用可能在某些路径泄露。

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：项目中所有不同的错误返回语句及其所在文件/函数，标注每种格式的结构（纯文本/JSON对象/异常对象/框架默认）和使用的HTTP状态码
      → findings.evidence.code_context
- [ ] **judgment_rationale**：列出所有发现的错误格式种类，对比差异（字段名/嵌套层级/内容类型），说明为何这些不一致会导致客户端无法统一解析或导致信息泄露
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：异常/错误对象从抛出点 → 中间件/拦截器 → 最终HTTP响应的处理链，标注各环节是否进行了格式转换或信息追加
      → findings.evidence.data_flow_path
- [ ] **call_stack**：错误产生位置 → 错误处理函数 → 响应序列化器的调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：不同错误路径中响应对象的字段集合（哪些路径包含 trace_id、stack_trace 等敏感字段）
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否存在全局异常处理器（@ControllerAdvice/errorhandler/middleware）统一包装，以及该处理器是否覆盖所有Controller/Handler
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. 定义统一错误响应格式：`{"error": "message", "code": "ERR_XXX", "request_id": "uuid"}`
2. 使用全局异常处理器统一转换（`@ControllerAdvice` / Flask `errorhandler` / Express error middleware）
3. 禁止在 Controller/Handler 中直接 `return "error string"` 字符串

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 新旧 API 版本过渡期（v1/v2 格式不同） | 不同版本 API 有独立的错误格式约定，通过 URL 路径前缀（/v1/、/v2/）区分 | 确认两个格式分别归属于不同 API 版本路径，且客户端文档明确说明差异 |
| 中间件统一包装了最终格式（如 `@ControllerAdvice`） | 虽然 Controller 中返回格式不统一，但全局异常处理器/响应拦截器在出口统一转换 | 确认全局处理器存在且覆盖所有Controller/Handler/Route |
| 内部微服务已使用统一错误处理库 | 共享库/公共包定义了标准 ErrorResponse 类型，所有服务通过该库构造错误响应 | 确认所有错误返回均通过共享库的类型/函数构造 |
| 测试代码 | 测试代码中的错误返回不影响生产环境的一致性 | 确认代码位于 test/、__tests__/、*_test.go 等测试路径 |
| 第三方库边界适配层 | 在第三方库（如支付SDK、OAuth库）的错误格式与应用格式之间的适配层 | 确认该层职责为格式转换，最终输出仍为统一格式 |
| WebSocket/SSE 等非REST端点 | 基于协议的固有错误通知机制，与REST JSON格式不同是协议设计而非缺陷 | 确认端点为 WebSocket/SSE/gRPC 等非REST协议 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# 同一项目/模块中 ≥2 种不同错误格式共存
return\s+ResponseEntity.*body\(Map\.of               # JSON Object 格式 (Java)
return\s+"                                           # 纯字符串返回（所有语言）
                                                      # → MUST: code_context (所有格式汇总)
                                                      # → MUST: judgment_rationale (格式差异分析)

throw new \w+Exception                                # 异常传播（框架默认格式）
jsonify\(|json\.dumps\(|JSON\.stringify\(             # 手动JSON序列化
abort\(|HttpResponseException                         # 框架特定格式

# 缺少标准字段（需结合上下文判断）
→ (无 error_code|code|errorCode 字段)                # 缺少业务错误码
→ (无 request_id|trace_id|requestId 字段)            # 缺少追踪标识
                                                      # → MAY: variable_state (字段集合对比)

# === EXCLUDE (不报告) ===
→ @ControllerAdvice|@ExceptionHandler 存在且覆盖所有 Controller  # Spring 全局异常处理器
→ app\.errorhandler\(|@app\.errorhandler\(            # Flask 全局错误处理器
→ app\.use\(.*error|next\(err\)                       # Express 错误中间件
→ 所有错误返回来自同一 ErrorResponse 工厂方法           # 统一构造点
→ 文件路径匹配 test/|__tests__/|*_test.*              # 测试代码排除
→ WebSocket|EventSource|grpc                           # 非REST协议端点
```
