> **定位**: 外部输入跨函数边界传递时验证状态的追踪规则 | **加载时机**: Phase 2c Counter Evidence | **消费方**: Judge (Step 7)

# 输入验证跨函数追踪

## 规则

当外部输入值通过函数参数传递到目标函数时，追踪目标函数内部是否执行验证。

### 最大深度: 1 层

```c
void handler(char *input) {
    process_input(input);  // 传入被调用函数
}

void process_input(char *data) {
    // 检查 process_input 内部是否有验证
    // 若无验证则报告
    system(data);  // 无验证 → 命令注入
}
```

### 深度上限

超过 depth 1 的调用链 → 降级为 suspicious。

## 验证包装函数模式

### 1. 验证器函数模式（安全 — 不报告）

```c
// 安全：validate_and_sanitize 封装了完整验证
int validate_and_sanitize(const char *input, char *output, size_t out_size) {
    if (!input || strlen(input) > MAX_INPUT) return -1;
    // 白名单过滤：仅允许字母数字
    size_t j = 0;
    for (size_t i = 0; input[i] && j < out_size - 1; i++) {
        if (isalnum(input[i])) output[j++] = input[i];
    }
    output[j] = '\0';
    return 0;
}

void handler(const char *user_input) {
    char safe[256];
    if (validate_and_sanitize(user_input, safe, sizeof(safe)) == 0) {
        // 安全：safe 已被验证和消毒
        use_safe_value(safe);
    }
}
```

### 2. 消毒器传播模式（追踪验证状态）

```c
// 追踪：sanitize 后的值通过返回值传递到调用者
char *sanitize_html(const char *input) {
    char *output = malloc(strlen(input) * 2 + 1);
    // HTML 实体编码消毒
    return output;  // 返回值标记为"已消毒"
}

void render(const char *user_input) {
    char *safe = sanitize_html(user_input);
    printf("%s", safe);  // 安全：safe 来自消毒器
    free(safe);
}
```

### 3. 验证缺失的跨函数模式（报告）

```c
// 报告：handler 将原始输入直接传递给危险操作
void handler(char *input) {
    execute_command(input);  // 未验证直接传递
}

void execute_command(char *cmd) {
    // 检查 execute_command 内部是否有验证
    system(cmd);  // 无验证 → 命令注入（CWE-78）
}
```

### 4. 部分验证的跨函数模式（降级为 suspicious）

```c
// suspicious：上层仅做部分验证，下层依赖未满足
void upper(char *input) {
    if (strlen(input) < 256) {  // 仅长度检查
        lower(input);  // 传递：长度已验证，但内容未过滤
    }
}

void lower(char *data) {
    // 危险操作：假设数据已安全
    execl("/bin/sh", "sh", "-c", data, NULL);  // 命令注入风险
}
```

## 消毒器传播状态追踪

| 消毒器模式 | 传播方式 | 追踪行为 |
|-----------|---------|---------|
| 返回值传递 | `char *safe = sanitize(in);` | 标记 `safe` 为已验证 |
| 输出参数 | `sanitize(in, out, size);` | 标记 `out` 为已验证 |
| 结构体字段 | `ctx->safe_data = sanitize(in);` | 标记字段为已验证 |
| 原地修改 | `sanitize_in_place(buf);` | 标记 `buf` 为已消毒 |

## 常见转移模式

1. **配置文件读取 → 解析函数**: main() → read_config() → parse_value() → 最终使用
2. **网络数据 → 处理链**: recv() → parse_packet() → process_payload() → 最终使用
3. **环境变量 → 工厂函数**: getenv() → create_ctx() → 使用
4. **命令行参数 → 处理函数**: argv[] → validate_args() → business_logic()

## CWE 参考

- **CWE-20**: Improper Input Validation — 核心覆盖
- **CWE-116**: Improper Encoding or Escaping of Output — 消毒器不足
- **CWE-78**: OS Command Injection — 命令执行场景
- **CWE-134**: Use of Externally-Controlled Format String — 格式字符串场景
