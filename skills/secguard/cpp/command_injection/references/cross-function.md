# Command Injection — 跨函数追踪 (max depth 1)

## 场景一: 用户输入跨函数传递至 system/popen

当用户输入在某个函数中获取，通过函数参数传递到另一个函数中的 system/popen，追踪参数构造链。

### 追踪规则

1. 从 call_graph.edges 查找 system/popen 所在函数的调用者
2. 检查调用者传入的参数是否来自外部输入（argv/getenv/scanf/socket）
3. 读取中间函数中参数的拼接/变换方式
4. 确认跨函数传递中是否有验证过滤

### 示例: 函数链传递用户输入

```c
// Layer 3: sink — 接收参数后执行
int execute(const char *cmd) {
    return system(cmd);       // Sink
}

// Layer 2: 拼接
void run_backup(const char *target) {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "tar czf backup.tar.gz %s", target);
    execute(cmd);             // 传入 Layer 3
}

// Layer 1: source — 用户输入入口
int main(int argc, char *argv[]) {
    run_backup(argv[1]);      // argv[1] 传入 Layer 2
    return 0;
}
```

追踪路径: `main(argv[1]) → run_backup(cmd) → execute(cmd) → system()`

### 示例: 跨函数拼接再执行

```c
// 构造命令字符串
char *build_command(const char *user_input) {
    static char cmd[1024];
    snprintf(cmd, sizeof(cmd), "process_data %s", user_input);
    return cmd;
}

// 执行
void run_processor(const char *input) {
    char *cmd = build_command(input);   // 拼接
    system(cmd);                        // 执行
    // 追踪: input → build_command → cmd → system
    // input 为外部传入 → 报告
}
```

## 场景二: 从环境变量获取后传入执行函数

```c
// Layer 2
int safe_env_exec(const char *var_name) {
    const char *val = getenv(var_name);
    if (!val) return -1;
    return run_cmd(val);          // 传入 Layer 1
}

// Layer 1
int run_cmd(const char *cmd) {
    return system(cmd);           // Sink — 环境变量值经过的路径
}
```

追踪路径: `getenv(VAR) → val → run_cmd(val) → system()`
判定: getenv 返回不可信外部输入 → 报告

## 场景三: 拼接前有验证过滤

```c
int validate_and_exec(const char *user_arg) {
    // 验证
    if (!validate_input(user_arg)) {
        return -1;
    }

    char cmd[256];
    snprintf(cmd, sizeof(cmd), "ping -c 4 %s", user_arg);
    return system(cmd);           // system 前已验证
}
```

验证函数内容:
```c
int validate_input(const char *input) {
    // 白名单检查
    for (const char *p = input; *p; p++) {
        if (!isalnum(*p) && *p != '.' && *p != '-' && *p != '_') {
            return 0;
        }
    }
    return strlen(input) > 0 && strlen(input) < 256;
}
```

判定: 存在白名单验证 → 降级为 low confidence 或抑制

## 深度限制说明

- max depth 1: 仅追踪 system/popen 的直接调用者。不追踪调用者的调用者（depth 2+）。
- 如果 depth 1 无法确定参数来源（例如通过深度嵌套的配置解析链到达），报告 `confidence: low`。
- 对于回调/函数指针的间接调用，无法静态追踪，不在本 skill 范围内。
