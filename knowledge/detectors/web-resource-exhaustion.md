---
detector: resource-exhaustion
severity: medium
cwe: CWE-400
language: [c, cpp, java, python, go]
tags: [web, dos, resource, memory]
---

# 不受控制的资源消耗 (Uncontrolled Resource Consumption)

## 威胁定义

用户可控制的输入导致CPU/内存/磁盘等资源不受限制地消耗，引发拒绝服务。常见模式：用户控制的循环次数、分配大小、递归深度、文件读取量——全部无上限。

**核心原则：所有用户可控的资源消耗操作必须设置硬上限。包括循环max迭代、malloc max size、递归 max depth、文件读取 max bytes。**

## 检测逻辑

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

## 修复指引

1. **分配上限**：`if (user_size > MAX_ALLOC) return ERR_TOO_LARGE;`
2. **循环上限**：`for (i = 0; i < MIN(user_count, MAX_ITERS); i++)`
3. **文件大小**：`fstat(fd, &st); if (st.st_size > MAX_FILE_SIZE) ...`
4. **递归深度**：增加深度参数 `void recurse(int depth) { if (depth > MAX_DEPTH) return; ... }`
5. **超时保护**：所有外部资源操作设置超时

## 误报排除

| 场景 | 原因 |
|------|------|
| 循环次数有硬编码上限 | 已限制 |
| 使用流式处理（非一次性加载） | 内存可控 |
| 输入有框架级大小限制（如 Spring max-request-size） | 框架保护 |
| 递归深度有明确的限制检查 | 安全退出 |

## 检测模式汇总

```
# 用户输入驱动循环 + 无上限
for.*user_count|for.*request\.parameter|while.*user_input
→ 无 if.*i > MAX|if.*count > LIMIT

# 无界内存分配
malloc|calloc|new.*\[user|byte\[\].*userSize|readAllBytes
→ 无 if.*size > MAX|if.*len < LIMIT

# 用户输入 + IO 流无缓冲
read.*all|readLine.*while|readFully
→ 无 缓冲区大小限制
```

## CWE 映射

- CWE-400: Uncontrolled Resource Consumption
- CWE-770: Allocation of Resources Without Limits
- CWE-789: Uncontrolled Memory Allocation
