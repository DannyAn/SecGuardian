---
name: secguard-cpp-buffer-overflow
description: "检测 C/C++ 代码中通过不安全字符串操作函数导致的缓冲区溢出漏洞，包括 strcpy/strcat/sprintf/memcpy/gets 及安全变体参数误用"
category: language-specific
language: cpp
topic: [memory]
signal_source: call_sites[category="string", category="memory"]
---

# 缓冲区溢出检视算子

## 元数据

- id: memory.buffer-overflow
- severity: critical
- cwe: CWE-120
- category: string + memory
- signal_source: call_sites[category="string", category="memory"]

## 信号预筛

从 index.json 的 call_sites 中筛选：

- callee 匹配: strcpy, strcpy_s, strcat, strcat_s, sprintf, sprintf_s, memcpy, memcpy_s, gets, gets_s, snprintf
- 按信号分组:
  - unsafe 组（无 _s 后缀）: strcpy, strcat, sprintf, memcpy, gets → 高优先级
  - safe 组（有 _s 后缀）: strcpy_s, strcat_s, sprintf_s, memcpy_s, gets_s → 参数审计优先
  - snprintf → 返回值检查优先

## 检视协议

### Step 1: 信号确认

对每个预筛信号:
1. 读取调用点源码（±15 行）
2. 确认调用点真实存在（排除注释/宏/条件编译）
3. 判断调用点属于 unsafe 组还是 safe 组

### Step 2: 证据链构建

构建 Source → Propagate → Sink 证据链:
- Source: 源缓冲区的来源（栈数组/堆分配/函数参数/用户输入）
- Propagate: 数据流转路径中是否有任何长度计算或安全检查
- Sink: 目标缓冲区的大小与源数据长度的关系

### Step 3: 安全变体参数审计

对 `_s` 后缀函数变体执行参数审计：

**strcpy_s(dst, dsize, src)**:
- 检查 `dsize` 是否等于 `sizeof(dst)`
- 若 `dst` 是栈数组: `dsize == sizeof(dst)` → 安全；`dsize < sizeof(dst)` → 截断风险；`dsize > sizeof(dst)` → 逻辑错误
- 若 `dst` 是指针: 检查 `dsize` 参数来源

**memcpy_s(dst, dsize, src, n)**:
- 检查 `dsize >= n`
- `dsize < n` → 缓冲区溢出（违反安全契约）
- 确认 `dsize` 不超过 `dst` 的实际分配大小

**sprintf_s(buf, size, fmt, ...)**:
- 检查 `size == sizeof(buf)`（栈目标）
- 检查 `size >= strlen(fmt)` + 扩展参数长度

**snprintf(buf, size, fmt, ...)**:
- 检查返回值是否 >= size → 截断（非溢出，但数据丢失）

### Step 4: 跨函数补证

当目标缓冲区或源数据来自函数参数时，查询调用图查调用者：
- 深度=1 调用者 → 确认实际传入参数的大小关系
- 深度 > 1 → 降级为 "suspicious"，标记 confidence: medium

### Step 5: 5 轮反思

1. **事实校对**: 证据链中每个断言是否有源码支撑？
2. **因果闭环**: Source→Sink 的因果是否必然？
3. **寻找豁免**: 是否有运行时检查、编译期常量、平台保证？
4. **根因归并**: 同一目标多个问题 → 合并为 1 个 finding
5. **保守定性**: 证据不完整 → 降级；证据完整 → 按严重度定级

## 输出格式

每个 finding 遵循三段式证据链：
```json
{
  "evidence_chain": {
    "source": {"description": "64 字节栈缓冲区 buf 分配于函数入口", "file": "src/parser.c", "line": 40},
    "propagate": {"description": "strcpy 无长度限制，从 user_input 复制", "file": "src/parser.c", "line": 42},
    "sink": {"description": "user_input 可能超过 63 字节导致栈缓冲区溢出", "file": "src/parser.c", "line": 42}
  }
}
```
