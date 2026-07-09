# 空指针解引用跨函数追踪规则 (Cross-Function Tracing)

## 原则

最大追踪深度 1 层。当分配发生在函数 A 而解引用发生在 A 调用的函数 B，或反之。

## 场景 1: 分配在调用者，解引用在被调者

```c
void caller() {
    char *p = (char*)malloc(256);
    if (p == NULL) return;     // ← NULL 检查在 caller
    use_buffer(p);             // ← p 传入 use_buffer
}

void use_buffer(char *p) {
    p[0] = 'a';                // ← 解引用，但调用者已检查
}
```

**追踪规则**:
1. 检测到 `use_buffer(p)` 调用，参数 p 来自 malloc
2. 在 caller 中检查 p 的 NULL 检查路径
3. 调用者已有 NULL 检查 → 安全，豁免
4. 调用者无 NULL 检查 → 标记 use_buffer 内解引用为可疑

## 场景 2: 分配在被调者，调用者使用

```c
void caller() {
    char *p = NULL;
    if (!allocate_buffer(&p, 256)) return;
    p[0] = 'a';                // ← 使用
}

int allocate_buffer(char **out, size_t sz) {
    *out = (char*)malloc(sz);
    if (*out == NULL) return -1;  // ← NULL 检查在 callee
    return 0;
}
```

**追踪规则**:
1. 查调用图找到 `allocate_buffer` 定义
2. 确认 callee 内部有 NULL 检查并返回状态
3. 检查 caller 是否检查了返回值
4. 检查通过 → 安全

## 场景 3: 分配后立即传给子函数无检查

```c
void caller() {
    char *p = (char*)malloc(256);
    // 没有 NULL 检查
    process(p);                // p 可能为 NULL
}

void process(char *p) {
    p[0] = 'a';                // 无 NULL 检查的解引用
}
```

**追踪规则**:
1. 检测到 caller 中 malloc 无 NULL 检查
2. process(p) 将 p 传入子函数
3. 读取 process 定义，确认入口无 NULL 检查
4. → 最终判定: 空指针解引用 (critical)

## 场景 4: 多级传入

```c
void level1() {
    level2(malloc(256));
}

void level2(char *p) {
    level3(p);
}

void level3(char *p) {
    p[0] = 'a';  // 深度 > 1
}
```

**处理**: 深度 > 1 → 标记为 suspicious（confidence: medium）。证据链记录分配和最终解引用位置，但补充说明跨 2 层调用无法确认中间处理。

## 不可追踪情况

1. **全局变量分配**: `global_ptr = malloc(256)` → 无法追踪所有解引用点
2. **容器/结构体成员**: `cfg->buffer = malloc(256)` → 内部指针，路径复杂
3. **回调函数**: 通过函数指针传入 → 运行时绑定，编译期不可追踪
