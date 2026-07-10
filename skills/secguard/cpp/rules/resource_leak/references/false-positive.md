# Resource Leak — 误报抑制策略

## 策略 1: goto cleanup 确认

`goto cleanup` 是 C 语言中最常见的资源管理惯用法。如果所有退出路径最终通过 goto 跳转到 cleanup 标签并执行 close，则不报告。

检查清单:
- [ ] cleanup 标签位于函数尾部且在所有 goto 之后
- [ ] cleanup 块包含 `if (fp) fclose(fp)` 或 `if (fd >= 0) close(fd)` 等保护式关闭
- [ ] 所有 goto 语句均在 cleanu[标签之前且不会跳过 cleanup
- [ ] 不存在从 cleanup 之后直接 return 的路径

```c
// 典型的 goto cleanup — 不报告
int func(void) {
    FILE *fp = fopen("path", "r");
    if (!fp) return -1;
    if (error1) goto cleanup;
    if (error2) goto cleanup;
    fclose(fp);
    return 0;
cleanup:
    fclose(fp);
    return -1;
}
```

## 策略 2: close 后置哨兵值

`close(fd)` 后立即设 `fd = -1` 是防御性编程。如果后续有条件检查 `if (fd >= 0)` 后再 close，则不会报告双重关闭。

但在本 skill（资源泄漏）中，哨兵值主要用于确认某个路径确实执行了 close——如果所有路径都有 close 后置哨兵，则无泄漏。

```c
// fd 关闭后置哨兵 — 无泄漏
int func(void) {
    int fd = open("path", O_RDONLY);
    if (fd < 0) return -1;
    int ret = process(fd);
    close(fd);
    fd = -1;       // 哨兵，用于检测二次 close 的防御
    // ... 后续代码不涉及 fd 操作
    return ret;
}
```

## 策略 3: 资源地址逃逸检查

当资源指针的地址被取出并存储到全局变量或传出参数时，不报告泄漏。需确认:

```c
void store_resource(FILE *fp) {
    static FILE *saved = NULL;
    saved = fp;       // 存入静态全局 — 生命周期超出函数
}

// 调用点
FILE *fp = fopen("log", "a");
if (fp) store_resource(fp);
// fp 存储在全局中，不报告函数内泄漏
```

但是: 还需要检查 `store_resource` 的语义 — 如果只是临时使用而不负责资源生命周期，仍应在调用点关闭。

## 策略 4: 环境差异抑制

| 环境因子 | 抑制条件 | 说明 |
|---------|---------|------|
| 文件是 test/ 或 *_test.c | 完全抑制 | 测试代码资源管理宽松 |
| main() 函数中打开的资源 | 可抑制（仅短生命周期 CLI 工具） | 进程退出 OS 回收 |
| daemon/服务器循环中泄漏 | 不抑制 | 累积泄漏导致 DoS |
| 嵌入式中断处理函数 | 不抑制 | 资源受限系统，泄漏立即影响 |

## 策略 5: 指数回退 (Exponential Backoff)

当同一个 fd 变量在多次扫描中重复报告泄漏，但代码审查确认其为误报时，按以下规则降级:

| 重复次数 | 操作 |
|---------|------|
| 第 1 次 | 正常报告（high confidence） |
| 第 2 次 | 降级为 medium，添加注释 "已确认误报？检查所有权移交" |
| 第 3 次 | 降级为 low，添加 suppress 标签 |
| 第 4 次+ | 自动移至 skip list，不报告 |

注意: 指数回退需要持久化状态跟踪。在首次实施时，默认所有 detection 为 full confidence，无回退抑制。

## 策略 6: 硬编码路径抑制

对于文件路径为编译期常量且文件被立即关闭的短期使用模式，可降级:

```c
// 短期打开配置文件读取后关闭 — 可降级为 low confidence
FILE *fp = fopen("/etc/default/config", "r");
if (fp) {
    fgets(buf, sizeof(buf), fp);
    fclose(fp);
}
// 确认: 路径硬编码 + 立即读取 + 立即关闭 → 低风险
```

---

## C++ RAII (Resource Acquisition Is Initialization) 模式

在 C++ 代码或 C 代码中使用 RAII 风格管理资源时，以下模式是安全的，**不得标记为漏洞**：

### 1. 构造函数分配 + 析构函数释放

当资源在构造函数/工厂函数中获取，并由配对的 destroy/release 函数管理生命周期时：

```c
// SUPPRESS: 工厂函数返回分配的资源，调用者通过配对的 destroy 函数释放
ResourceHandle *ResourceHandle_create(size_t size) {
    ResourceHandle *h = (ResourceHandle *)malloc(sizeof(ResourceHandle));
    h->data = malloc(size);  // 安全：ResourceHandle_destroy 负责释放
    h->size = size;
    h->owned = 1;
    return h;
}
void ResourceHandle_destroy(ResourceHandle *h) {
    if (h && h->owned) {
        free(h->data);
        h->data = NULL;
        h->owned = 0;
    }
    free(h);
}
// 用法：process_buffer() 中 create → use → destroy 是完整的 RAII 模式
```

构造函数中的 NULL 检查缺失由 create/destroy 契约管理——调用者负责检查返回值。

### 2. 智能指针所有权

```cpp
// SUPPRESS: unique_ptr 保证单次删除
std::unique_ptr<Resource> ptr = std::make_unique<Resource>();
ptr->use();  // 安全

// SUPPRESS: shared_ptr 保证引用计数后删除
std::shared_ptr<Resource> ptr = std::make_shared<Resource>();
```

### 3. Scope Guard 和自定义删除器

C 风格资源使用 RAII 包装器：

```cpp
// SUPPRESS: 自定义删除器保证 fclose
struct FileCloser { void operator()(FILE* f) { if (f) fclose(f); } };
std::unique_ptr<FILE, FileCloser> file(fopen("x", "r"));
```

```c
// SUPPRESS: GCC cleanup attribute 保证作用域退出时释放
__attribute__((cleanup(free_ptr))) char *buf = malloc(128);
```

### 抑制规则

如果以下任何一项成立，抑制 null_dereference / use_after_free / double_free / memory_leak / resource_leak 的 finding：

- 资源在堆栈对象的构造函数/工厂函数中获取，在配对的 destroy/release 中释放
- 资源由 unique_ptr、shared_ptr 或具有自定义删除器的等价物持有
- 资源作用域与 `}` 后的栈展开（GCC cleanup 属性）或 C++ 析构函数严格关联
- create/destroy 配对函数在同一翻译单元中定义，destroy 函数处理了所有释放路径
