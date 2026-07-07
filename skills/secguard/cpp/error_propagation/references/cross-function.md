# 错误传播 — 跨函数追踪

## 追踪规则

对本检测器的 Step 4，最大深度为 1 级。追踪两个方向：

1. **向上追踪** (caller to callee): 当前函数（错误返回值未检查）的 caller 是否在调用前已确保前置条件成立
2. **向下追踪** (callee to callee's callee): 当前函数如果调用了其他函数，这些调用是否隐式处理了错误

## 方向 A: Caller 已保证前置条件

```c
// caller:
void caller() {
    FILE *fp = fopen(path, "r");
    if (!fp) return;
    process_file(fp);    // 调用时 fp 已经确保非 NULL
    fclose(fp);
}

// 被检测函数:
void process_file(FILE *fp) {
    char buf[256];
    fread(buf, 1, sizeof(buf), fp);  // 这里没有检查 fp — 但 caller 已保证
    // 不标记, 或标记但 confidence: low
}
```

对 `process_file` 中的 `fread(buf, 1, n, fp)`：
- 查 `call_graph.edges` 找到所有 caller
- 检查每个 caller 是否在调用 `process_file` 前检查了 `fp != NULL`
- 如果所有 caller 都检查了 → 不标记（或标记 low confidence 记录但可分类为 precondition-based）

## 方向 B: 包装函数内部处理

```c
// 安全包装:
void *checked_malloc(size_t sz) {
    void *p = malloc(sz);
    if (!p) {
        fprintf(stderr, "Out of memory\n");
        exit(EXIT_FAILURE);   // 保证不返回 NULL
    }
    return p;
}

// 调用:
struct config *cfg = checked_malloc(sizeof(*cfg));
cfg->timeout = 30;   // 安全: checked_malloc 保证非 NULL
```

**检测**: 如果 malloc 的调用点位于一个包装函数内，且该包装函数在 NULL 时执行了 `exit()`/`abort()`/`longjmp()`/`throw` → 不标记调用者。

## 方向 C: 包装函数返回的 NULL 未检查

```c
// 不安全的包装 — 内部不处理错误:
FILE *open_config(const char *path) {
    return fopen(path, "r");   // 可能返回 NULL
}

// 调用:
FILE *fp = open_config("config.ini");
fread(buf, 1, n, fp);          // fp 可能为 NULL → 标记
```

**检测**: 对 `open_config` 的调用，查它的定义：如果它透传了 fopen 返回值且内部无 NULL 检查 → 等同于未检查的 fopen，标记。

## 方向 D: 构造/析构函数中的隐式错误

```cpp
class SafeFile {
    FILE *fp;
public:
    SafeFile(const char *path) : fp(fopen(path, "r")) {
        if (!fp) throw std::runtime_error("fopen failed");
    }
    ~SafeFile() { if (fp) fclose(fp); }
    void read(char *buf, size_t n) {
        fread(buf, 1, n, fp);  // fp 由构造保证非 NULL 或已抛出
    }
};
```

**检测**: 构造函数中的 fopen + throw pattern → SafeFile 构造要么成功（fp 有效），要么抛异常（fp 未被构造）。因此 `read()` 中的 `fread` 不需要检查 fp → 不标记。

## 方向 E: 分配函数通过结构体返回

```c
// 调用:
struct mytype *p;
int rc = allocate_mytype(&p);
p->value = 42;   // 分配失败时 p 可能包含未知值

// 函数:
int allocate_mytype(struct mytype **p) {
    *p = malloc(sizeof(**p));
    if (!*p) return -1;
    // 初始化...
    return 0;
}
```

**检测**: 检查 `allocate_mytype` 后 caller 是否检查了 `rc`。如果 caller 完全忽略了 `rc` 就解引用 `p` → 标记为忽略分配错误的变体。这种也是错误传播失败，只是在 Source/Sink 链上多了间接性。
