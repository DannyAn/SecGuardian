---
detector: resource-exhaustion
severity: medium
cwe: CWE-400
language: [c, cpp, java, python, go]
tags: [web, dos, resource, memory]
precision: medium
confidence: dynamic
---

# 不受控制的资源消耗 (Uncontrolled Resource Consumption)

## 威胁定义 (Threat Definition)

用户可控制的输入导致CPU/内存/磁盘等资源不受限制地消耗，引发拒绝服务。常见模式：用户控制的循环次数、分配大小、递归深度、文件读取量——全部无上限。

**核心原则：所有用户可控的资源消耗操作必须设置硬上限。包括循环max迭代、malloc max size、递归 max depth、文件读取 max bytes。**

## 检测逻辑 (Detection Logic)

### Step 1: 搜索无界循环

```c
// BAD: 用户控制循环次数
for (int i = 0; i < user_count; i++) {
    process(item[i]);  // user_count=10^9 → DoS
}

// BAD: 无退出条件的 while 循环
while (user_input[i] != '\0') {
    process(user_input[i++]);
    // 如果 user_input 极长或无结束符 → 无限循环
}
```

```java
// BAD: 用户输入驱动循环次数
for (int i = 0; i < request.getParameter("count"); i++) {
    expensiveOperation();
}
```

```python
# BAD: 遍历用户提供的列表
for item in user_list:
    expensive_call(item)
```

### Step 2: 搜索无界内存分配

```c
// BAD: 用户控制分配大小
char *buf = malloc(user_size);  // user_size=UINT_MAX → 内存耗尽

// BAD: 循环分配永不释放
while (user_input[i]) {
    char *tmp = malloc(1024);
    // 永不 free(tmp) → 泄漏直到 OOM
}
```

```java
// BAD: 用户控制集合大小
List<byte[]> list = new ArrayList<>();
for (int i = 0; i < count; i++) {
    list.add(new byte[1024 * 1024]);  // count=1000 → 1GB
}
```

### Step 3: 搜索无限制递归

```python
# BAD: 递归深度由用户输入控制
def process_nested(obj):
    for child in obj.get("children", []):
        process_nested(child)  # 深度嵌套 → 栈溢出
```

```go
// BAD: 递归解析用户输入
func parse(input string) {
    if strings.Contains(input, "(") {
        parse(input[1:])  // 深度嵌套 → 栈溢出
    }
}
```

### Step 4: 搜索大文件/大请求处理

```java
// BAD: 读取整个请求体到内存
byte[] body = request.getInputStream().readAllBytes();  // 100MB → OOM

// GOOD: 流式处理
InputStream is = request.getInputStream();
byte[] buf = new byte[8192];
int read;
while ((read = is.read(buf)) != -1) {
    process(buf, read);
}
```

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：用户控制资源消耗的完整代码块，包含外部输入来源（参数/请求体/文件/网络）、资源消耗操作（循环/分配/递归/IO 读取）、以及是否存在上限检查
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析用户输入值是否直接控制资源消耗量且无硬上限——循环次数是否 min(user_val, MAX)、分配大小是否有 if(size > LIMIT) 检查、递归是否有深度计数器限制、IO 操作是否使用流式处理（非 readAllBytes 一次性加载）
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：用户输入从请求参数/请求体 → 变量 → 资源消耗操作（循环计数器/分配大小/递归深度/读取量）的完整数据流
      → findings.evidence.data_flow_path
- [ ] **call_stack**：请求入口 → 中间处理函数 → 资源消耗操作的完整调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：用户输入值（循环次数/分配大小/列表长度/文件大小）、是否存在硬编码上限常量、框架级资源限制配置
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否存在框架级请求大小限制（Spring max-request-size/Nginx client_max_body_size）、是否有超时保护（连接超时/读取超时）、是否有 rate limiting
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **分配上限**：`if (user_size > MAX_ALLOC) return ERR_TOO_LARGE;`
2. **循环上限**：`for (i = 0; i < MIN(user_count, MAX_ITERS); i++)`
3. **文件大小**：`fstat(fd, &st); if (st.st_size > MAX_FILE_SIZE) ...`
4. **递归深度**：增加深度参数 `void recurse(int depth) { if (depth > MAX_DEPTH) return; ... }`
5. **超时保护**：所有外部资源操作设置超时

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| 循环次数有硬编码上限 | 已限制 | 确认循环条件包含 `min(user_val, MAX_CONST)` 或 `if (count > LIMIT) count = LIMIT` |
| 使用流式处理（非一次性加载） | 内存可控 | 确认使用 InputStream 分块读取/缓冲区循环处理，非 readAllBytes/一次性加载 |
| 输入有框架级大小限制（如 Spring max-request-size） | 框架保护 | 确认 Spring Boot 配置 server.tomcat.max-http-form-post-size 或 Nginx client_max_body_size |
| 递归深度有明确的限制检查 | 安全退出 | 确认递归函数有深度参数 `if (depth > MAX_DEPTH) return` 且 MAX_DEPTH 为合理值 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# 用户输入驱动循环 + 无上限
for.*user_count|for.*request\.parameter|while.*user_input
                                                       # → MUST: code_context (用户输入+资源消耗操作)
→ 无 if.*i > MAX|if.*count > LIMIT
                                                       # → MUST: judgment_rationale (上限检查缺失分析)

# 无界内存分配
malloc|calloc|new.*\[user|byte\[\].*userSize|readAllBytes
→ 无 if.*size > MAX|if.*len < LIMIT

# 用户输入 + IO 流无缓冲
read.*all|readLine.*while|readFully
→ 无 缓冲区大小限制

# === EXCLUDE (不报告) ===
→ MIN\(.*MAX|min\(.*LIMIT                           # min 上限保护
→ if\s*\(.*> MAX_|if\s*\(.*>= LIMIT                  # 显式上限检查
→ if\s*\(.*size > MAX_ALLOC\)                         # 分配上限
→ readAllBytes|readFully                               # 可能安全（需结合上下文）
→ InputStream|buffered.*read|chunked                   # 流式处理
→ depth\s*> MAX_DEPTH|depth\s*>=\s*MAX                 # 递归深度限制
→ fstat.*st_size|Content-Length.*<|if.*fileSize        # 文件大小检查
```
