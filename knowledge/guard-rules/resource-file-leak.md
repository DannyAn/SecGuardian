---
detector: resource-file-leak
severity: high
cwe: CWE-775
language: [c, cpp]
tags: [resource, file, leak, fd, resource]
precision: high
confidence: dynamic
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "resource.resource-file-leak",
  "type": "guard-rule",
  "namespace": "resource",
  "severity": "High",
  "cwe": "CWE-775",
  "cvss": 7.5,
  "confidence": "dynamic",
  "precision": "high",
  "languages": [
    "c",
    "cpp"
  ],
  "target_functions": [
    "code_context",
    "do_work",
    "fclose",
    "fopen",
    "freopen",
    "ifs",
    "open",
    "openat",
    "tmpfile"
  ],
  "match_patterns": [
    "fopen\\s*\\(.*\\)(?!.*fclose)       # fopen 无对应 fclose",
    "open\\s*\\(.*\\)(?!.*close\\s*\\()    # open 无对应 close"
  ],
  "exclude_patterns": []
}
```
## 威胁定义 (Threat Definition)

`fopen()`/`open()` 返回的文件句柄未在函数退出前关闭。长时间运行的服务会耗尽文件描述符，导致无法打开新文件或接受新连接（DoS）。`malloc` 未 `free` 属于 `memory.memory-leak`（CWE-401），不在本检测器覆盖范围。

## 检测逻辑 (Detection Logic)

### Step 1: C 标准库 — 搜索文件打开

```c
// BAD: 所有路径都泄漏
FILE* fp = fopen(path, "r");     // 需要 fclose
int fd = open(path, flags);      // 需要 close
int fd = openat(dirfd, path, flags);
FILE* fp = freopen(path, mode, stream);
FILE* fp = tmpfile();
```

### Step 2: 验证无对应关闭

对每次 `fopen`/`open`，搜索同一作用域内的对应 `fclose`/`close`。

```c
// BAD: 错误路径泄漏
FILE* in = fopen(src, "r");
if (!in) return;
FILE* out = fopen(dst, "w");
if (!out) return;                // 'in' leaks!

// GOOD: goto cleanup 模式
FILE* fp = fopen(path, "r");
if (!fp) return;
int ret = do_work(fp);
fclose(fp);
```

### Step 3: C++ 安全替代

```cpp
// GOOD: RAII 自动关闭
std::ifstream ifs(path);         // 析构自动 close
```

## 修复指引 (Remediation Guide)

1. **C**: 使用 `goto cleanup` 或单出口 `fclose` 模式
2. **C++**: 使用 `std::fstream`（RAII）

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `FILE*` 存入全局变量/传出参数 | 生命周期超出函数 | 确认指针被赋值到全局变量或通过参数传出 |
| `fopen` 返回 NULL | 无需关闭 | 确认 fopen 返回 NULL 且分支直接 return |
| C++ `std::fstream` 栈对象 | 析构自动关闭 | 确认为 std::ifstream/std::ofstream 栈分配对象 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

fopen\s*\(.*\)(?!.*fclose)       # fopen 无对应 fclose
open\s*\(.*\)(?!.*close\s*\()    # open 无对应 close
                                                       # → MUST: code_context (fopen/open 所在函数的完整代码)

# === EXCLUDE (不报告) ===
→ fclose|close\s*\(                                    # 存在对应的关闭调用
→ std::ifstream|std::ofstream|std::fstream             # C++ RAII 自动管理
→ return\s+fp|return\s+fd|\*\w+\s*=\s*fp               # 指针传出或全局赋值
→ fopen.*==\s*NULL|fopen.*!\s*\w+\).*return            # NULL 检查后立即返回
```
