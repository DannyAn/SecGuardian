# 缓冲区溢出豁免规则 (Buffer Overflow Exceptions)

## 编译期已知安全模式

以下模式在编译期可判定为安全，应豁免（suppress）：

### 1. 静态数组 + sizeof 推导

```c
// EXCEPTION: dsize == sizeof(dst)，编译期可证明安全
char dst[100];
strcpy_s(dst, sizeof(dst), src);

// EXCEPTION: 同数组地址连续复制
char arr[64];
strcpy_s(arr, sizeof(arr), "hello");  // 字符串字面量已知长度 < 64
```

### 2. 编译期常量长度

```c
// EXCEPTION: 源字符串为编译期常量
char buf[32];
strcpy(buf, "fixed_string");  // 11 字节 < 32，安全

// EXCEPTION: 长度在编译期可计算
#define MAX_NAME 32
char name[MAX_NAME];
snprintf(name, sizeof(name), "%s", get_short_string());
```

### 3. 同函数内预检查模式

```c
// EXCEPTION: 调用前有长度检查
char buf[256];
if (strlen(input) < sizeof(buf)) {
    strcpy(buf, input);  // 已确保 input < buf
}
```

### 4. 安全的 strncpy 用法

```c
// EXCEPTION: strncpy + 手动 null 终止
char buf[64];
strncpy(buf, src, sizeof(buf) - 1);
buf[sizeof(buf) - 1] = '\0';
```

## 平台特性豁免

### 1. Windows 安全 CRT 全局

当项目设置 `_CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES=1` 时，部分编译器会自动将 `strcpy` 重载为安全版本，但 `memcpy` 不被覆盖。

### 2. Fortify Source

```c
// 当 -D_FORTIFY_SOURCE=2 生效时，以下调用会被编译期替换
// 但 GCC 的 fortify 只对编译期已知大小有效
char buf[100];
strcpy(buf, src);  // FORTIFY_SOURCE 会在运行时检测溢出
```

### 3. ASLR + NX + Stack Canary

现代编译器在启用以下标志时提供运行时保护，**但这不应作为豁免依据**：
- `-fstack-protector-strong`
- `-fstack-clash-protection`
- ASLR、NX、PIE

## 假阳性样本

### FP-1: 目标缓冲区实际大于拷贝长度

```c
char path[PATH_MAX];  // 4096 一般是足够的
sprintf(path, "/tmp/%s", name);  // 如果 name 受限制则为安全
```
判定：需要确认 name 是否已在前置逻辑中做了长度限制。有则豁免。

### FP-2: 堆分配与使用匹配

```c
size_t n = get_exact_size();
char *buf = (char*)malloc(n);
memcpy(buf, src, n);  // 如果 get_exact_size() 精确匹配则为安全
```
判定：需要确认 `get_exact_size()` 的返回值语义。若非精确匹配，则不可豁免。

## 非豁免情况

以下看似安全但实际不可豁免：

```c
// NOT AN EXCEPTION: 指针 sizeof 陷阱
char *p = (char*)malloc(64);
strcpy_s(p, sizeof(p), src);  // sizeof(p) == 8（64位），非 64

// NOT AN EXCEPTION: strlen 在溢出后
char buf[64];
strcpy(buf, input);          // 溢出发生在此时
size_t len = strlen(buf);    // strlen 读到溢出后的数据

// NOT AN EXCEPTION: 重新分配但未更新大小
char *buf = (char*)malloc(64);
buf = (char*)realloc(buf, 128);
strcpy_s(buf, 64, src);     // 64 != 128，但实际不会溢出（保守仍标记）
```
