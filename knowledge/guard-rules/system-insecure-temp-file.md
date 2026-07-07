---
detector: insecure-temp-file
severity: medium
cwe: CWE-377
language: [c, cpp]
tags: [system, filesystem, temp]
precision: high
confidence: dynamic
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "system.insecure-temp-file",
  "type": "guard-rule",
  "namespace": "system",
  "severity": "Medium",
  "cwe": "CWE-377",
  "cvss": 5.5,
  "confidence": "dynamic",
  "precision": "high",
  "languages": [
    "c",
    "cpp"
  ],
  "target_functions": [
    "code_context",
    "data_flow_path",
    "fopen",
    "getpid",
    "judgment_rationale",
    "mkstemp",
    "mktemp",
    "open",
    "sprintf",
    "temp_directory_path",
    "tempnam",
    "tmpfile",
    "tmpnam",
    "variable_state"
  ],
  "match_patterns": [
    "tmpnam|mktemp|tempnam                                  # 废弃/不安全的临时文件名生成",
    "sprintf.*\"/tmp/.*%d\"                                    # 拼接进程ID — 可预测！",
    "open(\"/tmp/fixed_...\", O_CREAT                          # 固定文件名 — 完全可预测",
    "open\\(.*O_CREAT.*0666|open\\(.*O_CREAT.*0777             # 过于宽松的权限"
  ],
  "exclude_patterns": [],
  "required_evidence": [
    "code_context",
    "judgment_rationale"
  ],
  "optional_evidence": [
    "data_flow_path",
    "call_stack"
  ]
}
```
## 威胁定义 (Threat Definition)

临时文件使用可预测的文件名（`/tmp/myapp.tmp`）或非原子的创建方式（先检查再创建），攻击者可提前创建同名文件或符号链接劫持。典型攻击：CWE-377 / 符号链接替换。

**核心原则：使用 `mkstemp()`/`tmpfile()` 等原子化创建函数，且设置严格权限（0600）。禁止使用 `mktemp()`（已被 POSIX 弃用）。**

## 检测逻辑 (Detection Logic)

### Step 1: 搜索临时文件创建 (Identify Temp File Creation)

```c
// BAD: 可预测文件名
char tmp[256];
sprintf(tmp, "/tmp/myapp_%d", getpid());
fd = open(tmp, O_CREAT | O_RDWR, 0600);  // 竞态条件！
```

### Step 2: 危险模式 (Dangerous Patterns)

```c
// BAD: tmpnam 返回可预测名称
char *name = tmpnam(NULL);
fd = open(name, ...);            // 竞态！攻击者可抢占文件名

// BAD: mktemp 已废弃且不安全
char tmpl[] = "/tmp/myapp.XXXXXX";
mktemp(tmpl);                    // 未使用 mkstemp!

// BAD: 非独占创建
fd = open("/tmp/fixed_name", O_CREAT | O_RDWR, 0666);
```

### Step 3: 安全替代 (Safe Alternatives)

```c
// GOOD: mkstemp 原子创建
char tmpl[] = "/tmp/myapp.XXXXXX";
int fd = mkstemp(tmpl);
if (fd < 0) return -1;

// GOOD: tmpfile (自动删除)
FILE *fp = tmpfile();

// GOOD: C++ filesystem
std::filesystem::path tmp = std::filesystem::temp_directory_path() / "myapp.XXXXXX";
```

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：临时文件创建语句的完整代码，包含文件名构造方式（固定字符串/sprintf拼接/tmpnam/mktemp）、创建标志（O_CREAT/O_RDWR/O_EXCL）和权限参数
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析文件名的可预测性——攻击者能否在文件创建前猜测完整路径；分析创建操作的原子性——文件名生成和文件打开是否为原子操作；分析权限设置是否允许其他用户写入目录
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：临时文件路径从构造 → 创建 → 使用（读写）→ 删除的完整生命周期，标注每个环节是否存在竞态窗口
      → findings.evidence.data_flow_path
- [ ] **call_stack**：临时文件创建函数调用栈，确认是否有上层封装函数统一处理安全创建
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：临时文件路径变量的最终值、文件描述符值、umask 值、目录权限（/tmp 是否为 sticky bit 设置）
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否启用 -Wdeprecated-declarations 检测 mktemp 使用、静态分析工具（Coverity/CodeQL）的 TOCTOU 告警
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **C 代码**：使用 `mkstemp(template)` 原子创建（自动生成唯一文件名）
2. **C 代码**：使用 `tmpfile()` — 创建匿名临时文件，关闭时自动删除
3. **禁止**：`mktemp()`（POSIX 已弃用，可预测文件名）
4. **权限**：创建时指定 `0600` 权限，防止其他用户读取

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `mkstemp`/`mkostemp` | 原子操作：一次性生成唯一文件名并创建文件，无竞态窗口 | 确认使用 mkstemp/mkostemp 且检查返回值 |
| `tmpfile()` | 原子创建 + 自动删除：创建匿名文件，关闭或程序退出时自动删除，无文件名可预测问题 | 确认使用 tmpfile() 且无依赖于文件名的后续操作 |
| `O_EXCL` 标志 | 独占创建：若文件已存在则 open() 失败，防止符号链接劫持 | 确认 open() 同时使用 O_CREAT | O_EXCL，且检查失败返回值 |
| `/run/user/$UID/` (Linux) | 用户私有目录：仅当前用户可访问，其他用户无写入权限 | 确认临时文件路径在 /run/user/<uid>/ 下，且权限为 0700 |
| `mkdtemp` + 内部文件 | 先创建唯一目录（原子），再在其中创建文件，外部无法预测目录名 | 确认使用 mkdtemp 创建目录，文件在目录内创建 |
| `O_TMPFILE` (Linux 3.11+) | 创建无名称的临时文件，通过 /proc/self/fd/ 访问，无文件系统可见名称 | 确认使用 open() 的 O_TMPFILE 标志 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# tmpnam/mktemp 使用
tmpnam|mktemp|tempnam                                  # 废弃/不安全的临时文件名生成
                                                        # → MUST: code_context (文件名构造+创建语句)
                                                        # → MUST: judgment_rationale (可预测性+原子性分析)
→ 无 mkstemp 替代                                      # 未使用安全替代

# 可预测的 /tmp 路径
sprintf.*"/tmp/.*%d"                                    # 拼接进程ID — 可预测！
→ open|fopen (无 O_EXCL)                                # 非独占创建 → 竞态
                                                        # → SHOULD: data_flow_path (路径生命周期)

# 固定临时文件名
open("/tmp/fixed_...", O_CREAT                          # 固定文件名 — 完全可预测
→ 无 O_EXCL 标志                                        # → MAY: variable_state (目录权限)
open\(.*O_CREAT.*0666|open\(.*O_CREAT.*0777             # 过于宽松的权限

# === EXCLUDE (不报告) ===
→ mkstemp\(|mkostemp\(                                  # 原子创建，POSIX标准安全API
→ tmpfile\(                                             # 匿名临时文件，自动删除
→ open\(.*O_EXCL                                        # 独占创建标志
→ /run/user/|/var/run/user/                             # 用户私有运行时目录
→ mkdtemp\(                                             # 原子创建唯一目录
→ open\(.*O_TMPFILE                                     # Linux 无名称临时文件
→ open\(.*0600|open\(.*0400                             # 严格的仅所有者读写权限
→ unlink\(.*tmp|remove\(.*tmp                           # 使用后立即删除（缩小窗口）
```
