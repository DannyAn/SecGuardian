# Resource Leak — 规则模式

## 脆弱模式 (Vulnerable Patterns)

### Pattern 1: 错误路径泄漏

最常见的资源泄漏模式：打开资源后，部分错误路径直接 return 而未关闭已打开的资源。

```c
// VULNERABLE: 第二个 fopen 失败时 fp 泄漏
FILE *fp = fopen(path, "r");
if (!fp) return NULL;

FILE *out = fopen(dst, "w");
if (!out) {
    // fp 已打开但未关闭 → 泄漏
    return NULL;
}
fclose(fp);
fclose(out);
```

```c
// VULNERABLE: socket bind 失败后 sock 泄漏
int sock = socket(AF_INET, SOCK_STREAM, 0);
if (sock < 0) return -1;

if (bind(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
    // sock 未关闭 → 泄漏
    return -1;
}
close(sock);
```

### Pattern 2: 多层嵌套错误路径

多层资源分配中，中间层失败的组合泄漏。

```c
// VULNERABLE: 三层资源分配，中间层失败时前面资源泄漏
int fd1 = open(path1, O_RDONLY);
if (fd1 < 0) return -1;

int fd2 = open(path2, O_RDONLY);
if (fd2 < 0) {
    close(fd1);
    return -1;
}

int fd3 = open(path3, O_RDONLY);
if (fd3 < 0) {
    close(fd1);          // 正确
    close(fd2);          // 正确
    // 但如果忘记某个 close，就是泄漏
    return -1;           // 当忘记 close(fd1) 时 → 泄漏
}
close(fd1);
close(fd2);
close(fd3);
```

### Pattern 3: 循环内分配但循环体部分路径泄漏

```c
// VULNERABLE: 循环内出错时跳过关闭
for (int i = 0; i < n; i++) {
    int fd = open(files[i], O_RDONLY);
    if (fd < 0) continue;                     // OK: 无效 fd

    int ret = process_file(fd);
    if (ret < 0) {
        // fd 未关闭 → 泄漏（累积）
        continue;                              // LEAK
    }
    close(fd);
}
```

### Pattern 4: 跨函数资源传递后未关闭

```c
// VULNERABLE: handle_client 内部未关闭 fd
int client = accept(server_fd, (struct sockaddr*)&addr, &len);
if (client < 0) continue;
handle_client(client);       // handle_client 内部无 close(fd) → 泄漏

// VULNERABLE: 函数通过参数接收 fd 但未关闭
void consume_fd(int fd) {
    char buf[1024];
    read(fd, buf, sizeof(buf));
    // 使用完毕后未 close(fd) → 调用方也以为 consume_fd 负责了关闭
}
```

## 安全模式 (Safe Patterns)

### Pattern 1: goto cleanup 统一释放

```c
// SAFE: 所有退出路径汇聚到 cleanup 标签
int safe_function(const char *path) {
    FILE *fp = NULL;
    FILE *out = NULL;
    int ret = -1;

    fp = fopen(path, "r");
    if (!fp) goto cleanup;

    out = fopen(dst, "w");
    if (!out) goto cleanup;

    if (do_work(fp, out) < 0) goto cleanup;

    ret = 0;
cleanup:
    if (fp) fclose(fp);
    if (out) fclose(out);
    return ret;
}
```

### Pattern 2: C++ RAII

```cpp
// SAFE: RAII 自动管理生命周期
#include <fstream>
#include <memory>

void safe_cpp(const std::string &path) {
    std::ifstream ifs(path);     // 构造时打开
    if (!ifs.is_open()) return;

    std::string content;
    ifs >> content;
    // 析构时自动关闭，无需显式 close()
}

// SAFE: unique_ptr 自定义删除器管理 fd
struct FdDeleter {
    void operator()(int *fd) {
        if (fd && *fd >= 0) close(*fd);
        delete fd;
    }
};

void safe_fd() {
    std::unique_ptr<int, FdDeleter> fd(new int(socket(AF_INET, SOCK_STREAM, 0)));
    // 超出作用域时自动 close
}
```

### Pattern 3: 函数内单点 close + 哨兵值保护

```c
// SAFE: close 后置哨兵值，避免双重关闭
int safe_open(const char *path) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) return -1;

    int ret = process(fd);
    close(fd);
    fd = -1;           // 哨兵值

    if (ret < 0) {
        // 后续代码不会再次 close，因为 fd == -1
        return -1;
    }
    return 0;
}
```

### Pattern 4: 所有权移交文档化

```c
// SAFE: 明确所有权移交，调用方负责 close
// @param path  文件路径
// @return 文件描述符（调用方负责 close），失败返回 -1
int open_resource(const char *path) {
    return open(path, O_RDONLY);
}

// 调用方负责关闭
int caller() {
    int fd = open_resource("/etc/config");
    if (fd < 0) return -1;
    // ... use fd ...
    close(fd);       // 调用方关闭
    return 0;
}
```

## 判定参考

| 模式 | 报告 | 说明 |
|------|------|------|
| fopen → fclose（正常路径）但错误路径无 fclose | 报告 | 典型泄漏 |
| fopen 后立即检查 NULL → return | 不报告 | NULL 无需 close |
| socket 后检查 <0 → return | 不报告 | 无效 fd 无需 close |
| 资源赋值给传出参数（*out = fp） | 不报告 | 所有权移交 |
| C++ ifstream 栈对象 | 不报告 | RAII 自动管理 |
| fd 存入全局数组由专用函数清理 | 不报告 | 全局生命周期管理 |
| 短生命 CLI 程序 | 不报告 | 进程退出 OS 回收 |
