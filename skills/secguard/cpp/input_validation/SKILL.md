---
name: secguard-cpp-input_validation
description: "Detects missing or insufficient input validation where external input is used without proper length, type, or NULL checks"
category: language-specific
language: cpp
topic: [security]
signal_source: call_sites[category="exec"]
---

# Input Validation 检视算子

## 元数据

- id: validation.input_validation
- severity: high
- cwe: CWE-20
- category: exec
- signal_source: call_sites[category="exec"]

## 信号预筛

- callee 匹配: getenv, scanf, sscanf, atoi, atol, strtol
- 按信号分组: external_input_calls — 每个输入 API 调用作为检测起点
- index.json 交集: symbols.functions 含上述任一 callee 时激活

## 检视协议

### Step 1: 信号确认

收集 index.json 中所有外部输入 API 调用点：

```c
char *env = getenv("VAR");       // 环境变量输入
scanf("%s", buf);                // 标准输入
sscanf(str, "%s", out);         // 字符串解析
int n = atoi(argv[1]);           // 字符串转整数
long l = atol(input);            // 字符串转长整数
long v = strtol(input, NULL, 10); // 字符串转长整数（有错误检测）
```

记录每个调用点的变量赋值目标（返回值或输出参数）。

### Step 2: 证据链构建 (Source→Propagate→Sink)

对每个外部输入 API 调用点，追踪输入值的使用路径：

- Source: getenv/scanf/sscanf/atoi/atol/strtol 调用点
- Propagate: 变量赋值、类型转换、传递给其他函数
- Sink: 安全敏感操作 — strcpy/sprintf/malloc/snprintf/system/popen/socket/connect/文件路径操作/数组索引

```c
// Source: getenv → Propagate: 变量赋值 → Sink: strcpy 到固定缓冲区
char *input = getenv("HOME");        // Source
char buf[64];
strcpy(buf, input);                  // Sink: 缓冲区溢出可能

// Source: atoi → Propagate: 直接赋值 → Sink: malloc 大小参数
int size = atoi(argv[1]);            // Source
void *ptr = malloc(size);           // Sink: 整数可能为负或零

// Source: scanf → Sink: 无宽度限制直接写缓冲区
scanf("%s", buf);                    // 同时是 Source 和 Sink
```

### Step 3: 参数审计

对每个输入 API 调用点的结果，检查下游使用前是否存在充分验证：

**3.1 getenv 检查**
```c
// BAD: 无 NULL 检查
char *home = getenv("HOME");
strcpy(buf, home);  // home 可能为 NULL → 段错误

// GOOD: NULL 检查 + 长度验证
char *home = getenv("HOME");
if (home == NULL) return -1;
if (strlen(home) >= sizeof(buf)) return -1;
strcpy(buf, home);
```

**3.2 scanf/sscanf 检查**
```c
// BAD: 无宽度限制
scanf("%s", buf);                    // 用户输入超过 buf 大小 → 溢出

// BAD: sscanf 无宽度限制
sscanf(input, "%s", output);         // 无宽度限制

// GOOD: 指定宽度
scanf("%63s", buf);                  // 限制最多读 63 字符 (= sizeof "63 chars" + null)

// GOOD: 缓冲区大小计算
scanf("%" STR(MAX_INPUT-1) "s", buf);
```

**3.3 atoi/atol/strtol 检查**
```c
// BAD: 无范围/错误检查
int n = atoi(argv[1]);
malloc(n);              // 负数 → 漏洞；超大值 → 拒绝服务

// BAD: atoi 无法区分错误
int n = atoi("abc");    // 返回 0，与合法输入 "0" 无法区分

// GOOD: strtol 有错误检测
char *endptr;
long n = strtol(argv[1], &endptr, 10);
if (endptr == argv[1] || *endptr != '\0') return -1;  // 非数字
if (n < 0 || n > MAX_SIZE) return -1;                  // 范围检查
malloc((size_t)n);
```

### Step 4: 跨函数补证 (max depth 1)

当输入变量通过函数参数传递时，追踪目标函数内部是否执行验证。深度 1 层。

见 `references/cross-function.md`。

### Step 4.5: 多信号归并分析

当同一 caller function 内有多个信号时，先聚合再分析：
1. 按行号分组，检查信号间依赖（如 integer_overflow 绕过 → buffer_overflow 失效）
2. 归并后形成统一分析基线（避免重复读取同一段源码）
3. 在证据链中标注 cross_signal_analysis: true

### Step 5: 事实锚定反思（3 问判定矩阵）

必须回答 3 个域专用事实问题。答案必须基于源码证据链中的行号引用。

**Q1**: 输入来自不可信源?
**Q2**: 使用前有验证（长度/格式/范围/类型）?
**Q3**: 验证足够严格（白名单而非黑名单）?

判定矩阵规则:
| Q1 | Q2 | Q3 | 结论 |
|----|----|----|------|
| YES(安全) | YES | YES | SUPPRESS — 三绿灯，安全可证 |
| YES(安全) | YES | NO | informational — 基本安全但有隐患 |
| YES(安全) | NO | — | CONFIRMED — 条件不满足即漏洞 |
| NO(危险) | YES | YES | CONFIRMED — 危险信号已确认 |
| NO(危险) | NO | — | CONFIRMED — 多角度证实漏洞 |
| Mixed | Mixed | Mixed | 强制详细分析后判断 |

## 参考文件

- [规则模式](./references/rule.md) — 脆弱 vs 安全代码模式
- [例外规则](./references/exceptions.md) — 误报抑制规则
- [跨函数追踪](./references/cross-function.md) — 跨函数输入追踪 (max depth 1)
- [误报策略](./references/false-positive.md) — 误报抑制策略
