# Resource Leak — 跨函数追踪 (max depth 1)

## 场景一: fd/fp 作为参数传入被调用函数

当资源作为参数传递给其他函数时，检查被调用函数是否负责关闭该资源。

### 追踪规则

1. 从 `call_graph.edges` 查找到被调用函数（callee）的定义位置
2. 读取被调用函数的参数签名，确认资源参数的角色
3. 在被调用函数体内搜索对该参数的 `close()`/`fclose()` 调用
4. 枚举被调用函数的所有退出路径，验证每条路径是否都关闭了该资源

### 示例: callee 应关闭但未关闭

```c
// caller
void handle_request(int client_sock) {
    char buf[1024];
    read(client_sock, buf, sizeof(buf));
    process_data(client_sock, buf);     // 传入 client_sock
    // caller 假设 callee 会关闭？还是 caller 自己关闭？
    // 如果双方都认为对方关闭 → 泄漏
}

// callee
void process_data(int sock, char *data) {
    // 处理数据，但未 close(sock)
    write(sock, response, len);
    // 函数结束时 sock 未关闭 → 泄漏
}
```

### 示例: callee 负责关闭

```c
// caller — 明确委托清理责任
void handle_connection(int client_fd) {
    serve_client(client_fd);   // serve_client 的约定: 负责关闭 client_fd
    // caller 不再关心 client_fd
}

// callee — 在函数尾部关闭
void serve_client(int fd) {
    char buf[1024];
    int n = read(fd, buf, sizeof(buf));
    if (n <= 0) {
        close(fd);     // 错误路径关闭
        return;
    }
    // ... process ...
    close(fd);         // 正常路径关闭
}
```

## 场景二: 资源通过传出参数返回给调用方

当函数通过传出参数（`*out = fp`）创建资源时，检查调用方是否负责关闭。

```c
// 创建函数 — 通过传出参数返回 fd
int create_temp_file(int *out_fd) {
    int fd = mkstemp("/tmp/XXXXXX");
    if (fd < 0) return -1;
    *out_fd = fd;           // 所有权随传出参数移交
    return 0;
}

// 调用方 — 必须负责关闭
void caller(void) {
    int fd;
    if (create_temp_file(&fd) == 0) {
        // 使用 fd
        write(fd, data, len);
        close(fd);          // 调用方必须关闭
    }
}
```

## 场景三: struct/对象成员资源

```c
typedef struct {
    FILE *log_file;
    int config_fd;
    int initialized;
} Context;

// 资源作为结构体成员创建
int init_context(Context *ctx, const char *log_path, const char *cfg_path) {
    ctx->log_file = fopen(log_path, "a");
    if (!ctx->log_file) return -1;
    ctx->config_fd = open(cfg_path, O_RDONLY);
    if (ctx->config_fd < 0) {
        fclose(ctx->log_file);     // 回滚已打开的资源
        return -1;
    }
    ctx->initialized = 1;
    return 0;
}

// 需要有对应的销毁函数
void destroy_context(Context *ctx) {
    if (!ctx->initialized) return;
    if (ctx->log_file) fclose(ctx->log_file);
    if (ctx->config_fd >= 0) close(ctx->config_fd);
    ctx->initialized = 0;
}
```

## 深度限制说明

本追踪为 max depth 1，即仅追踪直接调用链的一层:
- 不追踪 callee 再调用的 callee（depth 2+）
- 不追踪回调函数或函数指针（静态分析无法确定目标）
- 不追踪虚函数调用（静态分析无法确定目标）

对于 depth 1 无法确认的资源状态，报告 `confidence: low` 并标注"跨函数追踪深度受限，可能存在 callee 内部清理但未被静态分析捕获"。
