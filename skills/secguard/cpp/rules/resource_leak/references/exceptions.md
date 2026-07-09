# Resource Leak — 例外规则

## 例外 1: 所有权移交 (Ownership Transfer)

资源通过 `return` 或传出参数（`*out = fp`）移交给调用方时，不在当前函数报告泄漏。

```c
// EXCEPTION: 所有权通过 return 移交
FILE *open_config(void) {
    FILE *fp = fopen("/etc/config", "r");
    if (!fp) return NULL;
    // fp 通过 return 移交给调用方 — 不报告
    return fp;
}

// EXCEPTION: 所有权通过传出参数移交
int open_file(const char *path, int *out_fd) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) return -1;
    *out_fd = fd;          // 所有权移交 — 不报告
    return 0;
}
```

## 例外 2: 全局/静态存储 (Global/Static Storage)

资源存入全局变量或静态变量，生命周期超出函数范围。需确认存在模块清理机制。

```c
// 全局 fd 数组
static int g_fds[MAX_FDS];
static int g_fd_count = 0;

// EXCEPTION: 存入全局数组
int register_fd(int fd) {
    if (g_fd_count >= MAX_FDS) return -1;
    g_fds[g_fd_count++] = fd;
    return 0;         // fd 存入全局，不报告本函数泄漏
}

// 需要检查是否存在 cleanup_fds() 清理函数
void cleanup_all_fds(void) {
    for (int i = 0; i < g_fd_count; i++) {
        close(g_fds[i]);
    }
    g_fd_count = 0;
}
```

## 例外 3: RAII / 封装库

C++ RAII 或高级库封装管理的资源不由用户代码显式关闭，不报告。

```cpp
// EXCEPTION: std::ifstream RAII
std::ifstream ifs(path);     // 析构自动关闭
std::string line;
std::getline(ifs, line);

// EXCEPTION: Boost.Asio / libuv 等网络库
boost::asio::ip::tcp::socket sock(io_context);
// 库内部管理 socket 生命周期，应用层通过库 API 关闭

// EXCEPTION: unique_ptr 自定义删除器
auto deleter = [](FILE *f) { if (f) fclose(f); };
std::unique_ptr<FILE, decltype(deleter)> fp(fopen(path, "r"), deleter);
```

## 例外 4: 无效资源无需关闭

`open()`/`socket()`/`fopen()` 返回无效值（-1、NULL）时，后续 `return` 不构成泄漏。

```c
// EXCEPTION: 无效 fd（-1）无需 close
int fd = open(path, O_RDONLY);
if (fd < 0) return -1;    // 无需 close，fd 无效

// EXCEPTION: NULL FILE* 无需 fclose
FILE *fp = fopen(path, "r");
if (!fp) return -1;       // 无需 fclose，fp 为 NULL
```

## 例外 5: dup/dup2 创建独立 fd

`dup()`/`dup2()` 创建的是与原 fd 独立的文件描述符，关闭新 fd 不构成对原 fd 的重复关闭。

```c
// EXCEPTION: dup 创建独立 fd
int new_fd = dup(original_fd);
// 关闭 new_fd 不影响 original_fd
close(new_fd);
close(original_fd);
```

## 例外 6: 短生命周期程序

非 daemon/服务器模式的命令行工具，进程退出时 OS 自动回收所有 fd。

```c
// EXCEPTION: main() 中打开的临时 fd，程序很快退出
int main(int argc, char *argv[]) {
    int fd = open("temp.txt", O_RDONLY);
    // 使用 fd 但未显式 close
    // 进程退出后由 OS 回收 — 不报告（仅适用于短暂运行的 CLI 工具）
    return 0;
}
```

注意: 此例外仅适用于运行时间短（< 几秒）、不循环创建新资源的 `main()` 函数。长时间运行的服务或 daemon 即使有 OS 回收保障也必须显式关闭。
