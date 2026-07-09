# 缓冲区溢出跨函数追踪规则 (Cross-Function Tracing)

## 原则

跨函数追踪最大深度为 **1 层调用者**。当事涉 2 层及以上调用链时，降级为 "suspicious" 并标记 `confidence: medium`。

## 场景 1: 目标缓冲区来自调用者

```
void caller() {
    char buf[64];
    callee(buf);
}

void callee(char *p) {
    strcpy(p, user_input);  // ← 检测点
}
```

**追踪规则**:
1. 在 index.json 的 `call_graph.edges` 中查找 `callee` 的调用者
2. 找到 `caller` 后，读取 `caller` 中调用 `callee(buf)` 附近（±10 行）的代码
3. 确认 `buf` 在 caller 中的分配大小（`char buf[64]` → 64 字节）
4. 若 `buf` 大小 < 可能输入长度 → 判定为溢出
5. 若无法确认分配大小（如 buf 本身也是参数）→ 深度 > 1，降级

## 场景 2: 源数据来自调用者

```
void caller() {
    char huge[1024];
    callee(huge);
}

void callee(char *src) {
    char buf[64];
    strcpy(buf, src);  // ← 检测点
}
```

**追踪规则**:
1. 查调用图找到 caller
2. 读取 caller 调用点的上下文
3. `src` 来自 caller 的 1024 字节数组 → buf(64) < src(1024) → 溢出
4. 返回 Step 5 定性

## 场景 3: 调用者提供大小参数

```
void caller() {
    char buf[256];
    secure_copy(buf, sizeof(buf), user_input);
}

void secure_copy(char *dst, size_t dsize, const char *src) {
    strcpy_s(dst, dsize, src);  // ← 检测点
}
```

**追踪规则**:
1. 查调用图找到 caller
2. 读取 caller 中 `secure_copy(buf, sizeof(buf), ...)` 的参数
3. `dsize = sizeof(buf) = 256` → 与 dst 分配大小一致 → 安全
4. 若调用者传入 `sizeof(指针)` → 标记

## 场景 4: 包装函数模式

```c
// VULNERABLE WRAPPER
void my_copy(char *dst, const char *src) {
    strcpy(dst, src);  // 完全无保护，调用者需自行保证
}

// SAFE WRAPPER
void my_copy_s(char *dst, size_t dsize, const char *src) {
    strcpy_s(dst, dsize, src);  // 传入大小参数
}
```

**追踪规则**:
1. 对于无大小参数的包装函数 → 审查所有调用者传入的 dst 大小
2. 只要有一个调用者传入的缓冲区可能不足 → 标记该包装函数为不安全
3. 对于有大小参数的包装函数 → 审计每个调用点的大小参数

## 边界: 多级调用链

```c
void level1() {
    char buf[64];
    level2(buf);
}

void level2(char *b) {
    level3(b);
}

void level3(char *b) {
    strcpy(b, huge_input);  // 深度=2（caller 是 level2，level2 的 caller 是 level1）
}
```

**处理**: 深度 > 1 → 标记为 "suspicious"（confidence: medium）
- 报告 evidence: strcpy 处检测到无边界拷贝
- 附加信息: `b` 的来源可追溯到 level1 的 64 字节栈数组，但存在间接调用链
- 不判定为 confirmed，建议人工审查

## 不可追踪的情况

1. **函数指针**: 调用图无法确定具体被调函数 → 跳过
2. **虚函数**: C++ 虚函数的分发在编译期不明确 → 跳过
3. **取地址传参**: `callee(&buf[offset])` → 标记为 suspicious（偏移量不确定）
