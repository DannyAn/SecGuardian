---
detector: path-traversal
severity: high
cwe: CWE-22
cvss: 7.5
language: [c, cpp, java, python, go, js]
tags: [system, filesystem, traversal]
precision: very-high
confidence: dynamic
target_functions: [argv, basename, code_context, fopen, input, judgment_rationale, open, openat, opendir, realpath, snprintf, sprintf, stat, strlen, strncmp, unlink, user]
match_patterns: [snprintf|sprintf.*%s.*user|input|argv, fopen|open]
exclude_patterns: []
required_evidence: [code_context, judgment_rationale]
optional_evidence: [data_flow_path, call_stack]
---

## 威胁定义 (Threat Definition)

攻击者使用 `../` 等特殊字符突破预期的文件目录边界，读取或写入任意文件。

**核心原则：文件路径操作中，用户输入不得直接影响路径解析结果。**

## 检测逻辑 (Detection Logic)

### Step 1: 搜索文件操作

```c
fopen(path, mode);
open(path, flags);
stat(path, &buf);
opendir(path);
unlink(path);
```

### Step 2: 检查路径来源

```c
// BAD: 直接拼接用户路径
char full_path[256];
snprintf(full_path, sizeof(full_path), "/var/www/%s", user_file);
FILE *fp = fopen(full_path, "r"); // user_file = "../../etc/passwd"

// BAD: realpath 使用不当（TOCTOU）
char resolved[PATH_MAX];
realpath(user_path, resolved);   // 解析前可能已被替换
fd = open(resolved, O_RDONLY);
```

### Step 3: 安全模式

```c
// GOOD: 验证解析后的路径在允许范围内
char resolved[PATH_MAX];
if (realpath(user_path, resolved) == NULL) return -1;
if (strncmp(resolved, BASE_DIR, strlen(BASE_DIR)) != 0) return -1;
fd = open(resolved, O_RDONLY);

// GOOD: openat + O_NOFOLLOW
int dir_fd = open(BASE_DIR, O_RDONLY);
int file_fd = openat(dir_fd, basename(user_path), O_RDONLY | O_NOFOLLOW);
```

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：文件操作 API（open/fopen/opendir/stat/unlink）的完整代码，包含路径变量来源（请求参数/配置文件/用户输入/命令行参数）、路径构造方式（拼接/sprintf/直接使用）及安全校验代码（realpath/openat/basename）
      → findings.evidence.code_context
- [ ] **judgment_rationale**：分析路径从构造到文件操作的完整链路——是否存在 realpath 解析+前缀校验；是否存在 openat + O_NOFOLLOW；是否存在 basename 提取；若均无安全校验，判断攻击者是否可突破基础目录到达敏感文件（/etc/passwd、/etc/shadow、私钥文件等）
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：用户输入 → 路径拼接/构造（sprintf/strcat/os.path.join/path.join）→ 文件操作 API（open/fopen/opendir）的完整数据流，标注每层是否进行了路径规范化或沙箱校验
      → findings.evidence.data_flow_path
- [ ] **call_stack**：输入接收点（HTTP handler/CLI arg/配置文件读取）→ 路径处理函数 → 文件操作 API 的完整调用链，确认是否存在路径安全校验函数（realpath/openat/basename/路径前缀校验）
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：用户输入的原始值（是否包含 ../ 或 ..\ 或绝对路径前缀）、拼接后的完整路径字符串、基础目录定义（BASE_DIR/rootPath）、文件操作 API 类型及 flags
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否存在 realpath 规范化+前缀匹配、openat+O_NOFOLLOW、basename 提取、白名单文件名映射（UUID/哈希映射）、chroot/sandbox 限制
      → findings.evidence.sanitizer_analysis

## 修复指引 (Remediation Guide)

1. **首选**：不直接用用户输入做文件名，使用 UUID/哈希映射
2. **次选**：获取规范路径后验证父目录匹配（`realpath` + 前缀校验 / `openat` + `O_NOFOLLOW`）
3. **Zip Slip**：解压前验证每个条目的规范路径

## 误报排除 (False Positive Exclusion)

| 场景 | 排除依据 | 证据要求 |
|------|---------|---------|
| `realpath` 解析 + 前缀校验 | 已做沙箱检查 | 确认 realpath 调用存在，且解析后路径与基础目录前缀比较 |
| `openat` + `O_NOFOLLOW` | 限制在基础目录内 | 确认 openat 使用目录 fd + O_NOFOLLOW 标志 |
| `basename()` 提取文件名 | 去除了目录部分 | 确认 basename 调用存在，剥离了路径中的目录部分 |
| 白名单文件名映射 | 用户输入仅作为 key | 确认用户输入仅用于查找预定义的文件名映射表 |

## 检测模式汇总 (Detection Patterns)

```
# === MATCH (触发检测) ===

# 路径拼接无过滤
snprintf|sprintf.*%s.*user|input|argv
→ open|fopen|opendir|stat (同一缓冲区)
                                                       # → MUST: code_context (路径构造+文件操作完整代码)

# ../ 存在且无 realpath 校验
fopen|open
→ 参数含 ..
→ 无 realpath|basename 预处理
                                                       # → MUST: judgment_rationale (路径来源+安全校验分析)

# === EXCLUDE (不报告) ===
→ realpath\(.*\)\s*&&|if.*realpath                      # realpath 解析后检查
→ strncmp.*realpath|strncmp.*resolved                   # 前缀校验（路径沙箱）
→ openat\(.*O_NOFOLLOW                                  # openat + 不跟随符号链接
→ basename\(                                             # basename 剥离目录
→ chroot|sandbox|jail                                    # chroot/sandbox 限制
→ UUID|uuid|hash.*file|file.*hash|map.*path              # 哈希/UUID 文件名映射
```
