# 空指针解引用假阳性抑制策略 (False Positive Suppression)

## 已知安全包装抑制

### 1. xmalloc 风格的 OOM 处理

在项目中识别并注册已知安全的分配包装函数。通常在 index.json 的 `safe_allocators` 中声明：

```json
{
  "safe_allocators": ["xmalloc", "xcalloc", "xrealloc", "safe_malloc"]
}
```

检测器在信号预筛阶段先检查分配函数是否在安全列表内 → 是则跳过。

### 2. 类型/概念推导抑制

```c
// SUPPRESS: 自定义 new 表达式（C++ 中 throw bad_alloc）
struct Foo *p = new Foo();       // 默认 new 抛异常，永不返回 NULL
p->bar();                        // 安全（除非用 nothrow new）

// SUPPRESS: placement new
new (buf) Foo();                 // 在已有缓冲区构造
```

### 3. 条件编译下的分配

```c
// SUPPRESS IF: #define DEBUG 时无 NULL 检查非问题
#ifdef DEBUG
    char *trace = malloc(1024);
    // debug 模式无 NULL 检查通常用于简化代码
    trace[0] = 0;
#endif
```

## 控制流假阳性

### 1. 间接 NULL 保证

```c
// SUPPRESS: 通过早期 return 隐含保证
char *p = malloc(1024);
if (!p) return -1;
// 以下所有代码都在 p 非 NULL 的路径上
do_work(p);

// SUPPRESS: goto error 模式
char *p = malloc(1024);
if (!p) goto oom;
p[0] = 'a';    // 安全
return 0;
oom:
    log("OOM");
    return -1;
```

### 2. switch/ternary 模式

```c
// SUPPRESS: ternary 保护
char *p = malloc(1024);
char *q = p ? p : fallback_buffer;
q[0] = 'a';  // 无论 q 来自 p 还是 fallback，都是有效的

// SUPPRESS: switch fallthrough 保证
p = malloc(n);
switch (state) {
    case INIT:
        if (!p) return -1;
        // fallthrough
    case READY:
        p[0] = 'a';  // INIT 已检查，READY 继承保证
        break;
}
```

## 抑制决策树

```
发现 malloc/calloc/realloc 调用点
├─ 调用函数在 safe_allocators 列表中 → SUPPRESS (high)
├─ 返回值赋给变量 p
│  ├─ 之后立即有 (p == NULL) 或 (!p) 检查
│  │  ├─ 检查后 return/exit/abort → SUPPRESS (high)
│  │  ├─ 检查后 goto error（error 释放/返回）→ SUPPRESS (high)
│  │  └─ 检查后空语句 / TODO 注释 → CONFIRM (medium)
│  ├─ 之后有 assert(p != NULL)
│  │  ├─ DEBUG 下 / NDEBUG 未定义 → SUPPRESS (medium)
│  │  └─ NDEBUG 已定义 → CONFIRM (high)
│  └─ 之后无任何检查 → 查解引用点
│     ├─ 解引用在分配后 1 行内，且为极小分配 ≤ 8 bytes → SUSPICIOUS (low)
│     ├─ 解引用通过传入子函数（深度 1）
│     │  ├─ 子函数有 NULL 检查 → SUPPRESS
│     │  └─ 子函数无 NULL 检查 → CONFIRM (high)
│     └─ 直接解引用 → CONFIRM (critical)
└─ 返回值未赋值（void 转换或丢弃）
   └─ 可能是 calloc 用于 clearing side effects → SUSPICIOUS (low)
```
