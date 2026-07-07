# 错误传播 — 脆弱模式与安全模式

## 模式 A: fopen 返回值未检查

**脆弱模式**:

```c
FILE *fp = fopen(path, "r");
fread(buf, 1, sizeof(buf), fp);  // fp 可能为 NULL → crash / UB
fclose(fp);
```

**安全模式**:

```c
FILE *fp = fopen(path, "r");
if (!fp) {
    fprintf(stderr, "Cannot open %s: %s\n", path, strerror(errno));
    return -1;
}
fread(buf, 1, sizeof(buf), fp);
fclose(fp);
```

## 模式 B: malloc 返回值未检查

**脆弱模式**:

```c
struct config *cfg = malloc(sizeof(*cfg));
cfg->timeout = 30;      // cfg 可能为 NULL → segfault
```

**安全模式**:

```c
struct config *cfg = malloc(sizeof(*cfg));
if (!cfg) {
    return ENOMEM;
}
cfg->timeout = 30;
```

## 模式 C: 显式丢弃返回值

**脆弱模式**:

```c
(void)write(fd, buf, n);  // 返回值被强制 void 丢弃
(void)read(fd, buf, n);   // 可能返回 < 0 或 < n
```

**安全模式**:

```c
ssize_t written = write(fd, buf, n);
if (written < 0) {
    // handle write error
} else if ((size_t)written < n) {
    // partial write — 需要重试
}
```

## 模式 D: 链式检查 vs 分离调用

**安全（链式检查）**:

```c
if (!(fp = fopen(path, "r"))) {
    return -1;
}
```

**脆弱（分离调用且未检查）**:

```c
fp = fopen(path, "r");
// 缺少: if (!fp) ...
fread(buf, 1, n, fp);
```

## 模式 E: 系统调用返回值

```c
// 脆弱
int fd = open(path, O_RDONLY);
read(fd, buf, n);   // open 可能返回 -1

// 安全
int fd = open(path, O_RDONLY);
if (fd < 0) {
    return -1;
}
ssize_t r = read(fd, buf, n);
if (r < 0) {
    close(fd);
    return -1;
}
```

## 模式 F: 构造函数中的错误

```cpp
// 脆弱 — 构造函数无法返回错误码
class FileReader {
    FILE *fp;
public:
    FileReader(const char *path) {
        fp = fopen(path, "r");   // 失败只能通过异常或成员标志
    }
    void read() {
        fread(buf, 1, n, fp);    // fp 可能 NULL
    }
};

// 安全 — 使用工厂方法
class FileReader {
    FILE *fp;
    FileReader(FILE *f) : fp(f) {}
public:
    static std::unique_ptr<FileReader> create(const char *path) {
        FILE *fp = fopen(path, "r");
        return fp ? std::unique_ptr<FileReader>(new FileReader(fp)) : nullptr;
    }
};
```

## C++ 中的特殊考虑

```cpp
// 脆弱: operator new 默认抛出 std::bad_alloc，不返回 NULL
// 但使用 nothrow new 时必须检查
int *p = new (std::nothrow) int[1024];
p[0] = 42;  // p 可能为 nullptr

// 安全: 检查 nothrow new
int *p = new (std::nothrow) int[1024];
if (!p) return;
p[0] = 42;
```
