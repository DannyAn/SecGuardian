---
name: secguard
description: "EPIC-3 Dispatcher — 信号驱动的安全加固扫描，15 个 C/C++ Skill 覆盖 memory/string/exec/io/sync/crypto/error 7 大安全分类"
---

# /secguard — Dispatcher Protocol v2 (EPIC-3)

## Command Layer

对源码执行安全加固扫描。采用 Dispatcher-Worker 架构：Dispatcher 读取索引信号 → 按 Skill 分派 Worker → Worker 只看相关代码执行 5 步检视协议。

支持全量扫描和 Git diff 增量扫描。

### 使用方式

```
# ★ 零参数缺省调用（推荐）
/secguard                                            # 扫描当前目录，自动检测语言，运行所有 Skill

# 显式指定路径和语言
  /secguard ./src cpp                                # C/C++ 全量
  /secguard ./src python                             # Python 全量
  /secguard ./src java                               # Java 全量

# Skill 过滤:
  /secguard ./src cpp memory.*                       # 仅内存安全 Skill
  /secguard ./src cpp memory.buffer_overflow         # 单个 Skill
  /secguard ./src cpp memory.*,exec.*,crypto.*       # 多组合（逗号并集）
  /secguard ./src python crypto.*                    # 仅加密 Skill

# 增量扫描:
  /secguard ./src cpp git diff                       # 工作区变更
  /secguard ./src cpp git diff HEAD~1                # 最近一次提交
  /secguard ./src cpp git diff main                  # 当前分支 vs main
  /secguard ./src cpp git diff main...feature        # 分支差异

# SARIF 输出 (CI/CD 集成):
  /secguard ./src python --sarif                     # 附加 SARIF 2.1.0 输出
  /secguard ./src cpp memory.* --sarif               # 过滤 + SARIF
```

### 输出路径约定

> 扫描输出的 `.codeagent/` 目录必须放在**用户项目根目录**下，不能放在 SecGuardian 项目根。
>
> 从 `<path>` 参数确定用户项目根目录：
> - 将 `<path>` 解析为绝对路径，取其**父目录**作为用户项目根
> - 例如 `/secguard examples/myapp/src cpp` → 用户项目根 = `examples/myapp/`
> - 所有输出路径使用 `<user-project>/.codeagent/` 前缀（包括索引器、Worker 输出、渲染器）
> - 不要使用相对路径 `.codeagent/`（会跑到 SecGuardian 项目下）

### 输出

遵循 [Scan Output Protocol 8.0](../knowledge/protocols/scan-output.md)。人读/机读分离。

```
.codeagent/secguardian/secguard/scans/<scan-id>/
├── human/                       # ★ v7.0: 统一入口
│   └── executive-summary.md      一页仪表盘 + 发现分布 + 导航
├── findings/                    # 按检测器组织的发现目录树（所有 Worker 汇总）
├── ai/                          # ★ v7.0: AI 可消费
│   └── remediation-pack.json     AI 修复包（含关联发现）
├── workers/                     # ★ v2: Worker 执行产物（调试用）
│   └── <skill_id>/              每个 Worker 的执行日志、盲区报告、中间产物
├── report.md                    # ★ 人读审计报告 (精简 5 节)
├── dashboard.html                  # ★ v7.0: 管理层仪表盘
├── results.sarif                # 机读: SARIF 2.1.0 (CI/CD)
├── summary.json                 # 仪表盘统计
├── manifest.json                # 扫描元数据 + 检出索引
├── status.json                  # CI 门禁
├── delta.json                   # 增量对比 (vs 上次扫描)
└── worker_manifest.json         # ★ v2: Worker 调度清单 + 盲区汇总
```

> **全路径权限弹窗优化**: 完成 `cd "$USER_PROJECT"` 后，所有项目内文件路径使用**相对路径**。
> 仅 `$SECGUARDIAN_HOME` 引用使用全路径（脚本和二进制在插件目录，不可避免）。
> 全路径操作触发 AI CLI permission system 逐项确权弹窗，中断扫描流程。

---

## Engine Layer — Dispatcher Protocol v2

> 本协议实现 EPIC-3 架构重构。从"LLM 全权扫描"（加载 67 规则 × 遍历 642 文件）转变为"信号驱动的 Worker 调度"（索引器预扫描 → Dispatcher 按信号分派 → Worker 只看相关代码）。
>
> 所有共享架构信息以 [`AGENTS.md`](../AGENTS.md) 为准。
>
> **隔离约束**: Dispatcher 只能加载 `$SECGUARDIAN_HOME/skills/secguard/` 下的 Skill，禁止加载 `skills/secaudit/` 或 `skills/secreview/` 下的任何文件。知识文件从 `$SECGUARDIAN_HOME/knowledge/` 用 bash `cat` 按需读取。
>
> 🚫 **不要使用 `todowrite` 工具。** 使用原生 task 系统追踪进度。
> 🚫 **不要硬编码 `RECORDER` 路径。** 必须使用 `$SECGUARDIAN_HOME/scripts/record-finding.py`。
> 🚫 **禁止用 `read` 工具读取 `$SECGUARDIAN_HOME/scripts/` 下的脚本文件。** 所有脚本通过 `Bash` 工具执行。

### 调度架构概览

```
┌──────────────────────────────────────────────────────────────┐
│                    Dispatcher (本协议)                          │
│                                                               │
│  Phase 1: 索引与信号生成                                       │
│    1. secguardian-index --path → index.json (含 call_sites)    │
│    2. 从 call_sites 提取信号，按 category 分组                  │
│    3. 生成 Worker 任务清单                                     │
│                                                               │
│  Phase 2: Worker 调度                                          │
│    对每个有信号的 Skill，启动 Worker (subagent):                │
│      - 输入: 信号清单 + SKILL.md + references/                  │
│      - Worker 执行 5 步检视协议 + 5 轮反思                      │
│      - 输出: findings 文件 + 盲区报告                            │
│                                                               │
│  Phase 3: 汇总与渲染                                           │
│    1. 合并所有 Worker findings                                  │
│    2. 去重（同一调用点多 Skill → 最高严重度）                    │
│    3. 渲染 report.md + SARIF + summary.json + status.json       │
└──────────────────────────────────────────────────────────────┘
```

### 信号 → Skill 映射表

```
call_sites category  →  Skill(s)
─────────────────────────────────────────────────
string               →  buffer_overflow
                        must_check
                        api_semantic_misuse

memory               →  buffer_overflow
                        null_dereference
                        memory_leak
                        double_free
                        use_after_free
                        integer_overflow
                        ownership_transfer
                        must_check
                        api_semantic_misuse

io                   →  resource_leak
                        must_check

exec                 →  command_injection
                        input_validation

sync                 →  lock_misuse

crypto               →  hardcoded_secrets

* (all)              →  error_propagation
```

**特殊 Skill（非 call_site 驱动）:**
- `hardcoded_secrets` — 扫描源码中的字符串/密钥模式（不依赖 call_sites 信号）
- `error_propagation` — 扫描被忽略的函数返回值（扫描 `must_check` 标记函数的调用点，不依赖 call_sites 信号）

这两类 Skill 始终参与 Worker 调度，即使 Phase 1 未产出对应 category 的信号。

---

## Phase 1: 索引与信号生成

> Dispatcher 直接执行的阶段。所有 bash 调用遵循跨 Shell 状态传递规则。

### Step 1: 初始化（仅一次 bash 调用）

> **这是唯一一次预初始化 bash 调用**，必须一次性完成：自动发现 → 健康检查 → 路径确认 → 建目录 → 写入 `.scan_state.secguard`。
> **禁止**在 Step 1 前后插入任何独立的 bash 命令。
> `$SECGUARDIAN_HOME/scripts/` 已在自动发现中验明存在，无需冗余 `ls` 确认。

- **⏳ 首先生成 scan_id**（格式: `sc-YYYYMMDD-HHMMSS-xxxx`，`xxxx` 为随机 4 位字符）。
- **scan_id 一旦生成，后续所有路径必须使用此 scan_id。**

```bash
# ===== 阶段 A: SECGUARDIAN_HOME 自动发现 =====
if [ -z "$SECGUARDIAN_HOME" ] || [ ! -d "$SECGUARDIAN_HOME/scripts" ]; then
    for candidate in \
        "/root/.config/opencode/extensions/secguardian" \
        "$HOME/.config/opencode/extensions/secguardian" \
        "$HOME/.claude/plugins/secguardian" \
        "$HOME/.gemini/extensions/secguardian" \
        "."; do
        if [ -f "$candidate/scripts/record-finding.py" ]; then
            export SECGUARDIAN_HOME="$candidate"
            echo "SECGUARDIAN_HOME=$SECGUARDIAN_HOME"
            break
        fi
    done
fi
if [ -z "$SECGUARDIAN_HOME" ] || [ ! -d "$SECGUARDIAN_HOME/scripts" ]; then
    echo "FATAL: Cannot locate secguardian installation (no SECGUARDIAN_HOME with scripts/)"
    echo "  Tried: /root/.config/opencode/extensions/secguardian, ~/.config/opencode/extensions/secguardian, ..."
    exit 1
fi

# ===== 阶段 B: 索引器健康检查 =====
if ! "$SECGUARDIAN_HOME/scripts/secguardian-index" --health; then
    echo "FATAL: secguardian-index health check failed"
    exit 1
fi

# ===== 阶段 C: 扫描路径确认 =====
test -d "<path>" || { echo "FATAL: scan path <path> not found"; exit 1; }

# ===== 阶段 D: 创建扫描目录 =====
SCAN_ID="sc-$(date +%Y%m%d-%H%M%S)-$(openssl rand -hex 2)"
SCAN_DIR="$USER_PROJECT/.codeagent/secguardian/secguard/scans/$SCAN_ID"
mkdir -p "$SCAN_DIR"

# ===== 阶段 E: 创建 Worker 输出目录 =====
mkdir -p "$SCAN_DIR/workers"

# ===== 阶段 F: 持久化状态 =====
cat > ".codeagent/secguardian/.scan_state.secguard" << STATEEOF
USER_PROJECT="$USER_PROJECT"
SCAN_ID="$SCAN_ID"
SCAN_DIR="$SCAN_DIR"
SECGUARDIAN_HOME="$SECGUARDIAN_HOME"
RECORDER="$SECGUARDIAN_HOME/scripts/record-finding.py"
STATEEOF
echo "SCAN_DIR=$SCAN_DIR"
```

### 🔒 跨 Shell 状态传递规则

> **每个 bash 调用都是独立 shell，变量不共享。禁止用 `/tmp/` 或任何系统临时目录传状态。**

Step 1 已在 `.scan_state.secguard` 中持久化 `SCAN_ID`、`SCAN_DIR`、`USER_PROJECT`、`SECGUARDIAN_HOME`、`RECORDER`。
从后续所有 bash 调用开始，**每个 bash 调用第一行必须是**:
```bash
source .codeagent/secguardian/.scan_state.secguard
```
此后 `$SCAN_DIR`、`$SCAN_ID`、`$USER_PROJECT`、`$SECGUARDIAN_HOME`、`$RECORDER` 均可直接使用。

> **知识库读取**: 知识库文件存储在 `$SECGUARDIAN_HOME/knowledge/`，使用 bash `cat` 按需读取，不拷贝到项目目录。
> - 协议文件：`cat "$SECGUARDIAN_HOME/knowledge/protocols/{name}.md"`
> - language-index：`cat "$SECGUARDIAN_HOME/knowledge/language-index.md"`
> - 语言画像：`cat "$SECGUARDIAN_HOME/knowledge/languages/{lang}.md"`
> - Skill 定义：`cat "$SECGUARDIAN_HOME/skills/secguard/{lang}/{skill}/SKILL.md"`
> - 禁止使用 `read` 工具读 `$SECGUARDIAN_HOME/` 下的文件（触发 OpenCode 外部目录权限弹窗）。使用 bash `cat` 读取不会触发权限弹窗。

### Step 2: 构建语义索引（不可跳过）

> 索引器产出 `call_sites`（库函数调用点 + 参数摘要），作为 Phase 2 Worker 的任务信号清单。**不执行此步骤将导致 Worker 没有信号指引。**
> 索引自动复用同路径缓存。加 `--force` 强制重建。

```bash
source .codeagent/secguardian/.scan_state.secguard

INDEXER="$SECGUARDIAN_HOME/scripts/secguardian-index"
if [ ! -f "$INDEXER" ]; then
    echo "FATAL: secguardian-index not found at $INDEXER"
    exit 1
fi
echo "Using: $INDEXER"
# 超时保护: timeout 30s
if command -v timeout &>/dev/null; then
    timeout 30 "$INDEXER" --lang <language> --path <path> --output "$USER_PROJECT/.codeagent/secguardian/index.json" || {
        echo "FAIL: Indexer timed out after 30s or failed — cannot continue"
        echo "  macOS: brew install coreutils  (provides 'timeout' command)"
        exit 1
    }
elif command -v gtimeout &>/dev/null; then
    gtimeout 30 "$INDEXER" --lang <language> --path <path> --output "$USER_PROJECT/.codeagent/secguardian/index.json" || {
        echo "FAIL: Indexer timed out after 30s or failed — cannot continue"
        exit 1
    }
else
    echo "WARNING: 'timeout' not found — indexer runs without timeout protection"
    "$INDEXER" --lang <language> --path <path> --output "$USER_PROJECT/.codeagent/secguardian/index.json"
fi
if [ ! -f "$USER_PROJECT/.codeagent/secguardian/index.json" ]; then
    echo "FATAL: Indexer failed — cannot continue"
    exit 1
fi
```

### Step 3: 验证索引完整性

```bash
source .codeagent/secguardian/.scan_state.secguard

python3 "$SECGUARDIAN_HOME/scripts/validate-index.py" \
    --index .codeagent/secguardian/index.json \
    --scan-id "$SCAN_ID"
```

若返回非 0，**立即终止扫描**并向用户报告索引生成出错。

### Step 4: 解析 call_sites 并生成 Worker 任务清单

**此步骤由 Dispatcher 在上下文中直接执行（无 bash 调用）—— 读取 index.json 的 `call_sites` 字段，按 category 分组，映射到 Skill 清单。**

#### 4a. 读取 index.json

读取 `$USER_PROJECT/.codeagent/secguardian/index.json`，提取关键字段：

```json
{
  "call_sites": [
    {
      "caller": "idm_portal_auth",
      "callee": "strcpy_s",
      "file": "src/ctrlplane/portal/idm_portal_auth.c",
      "line": 142,
      "arguments": ["dst", "sizeof(dst)", "src"],
      "safe_variant": true,
      "category": "string"
    },
    {
      "caller": "idm_hwd_rsp_parse",
      "callee": "calloc",
      "file": "src/ctrlplane/pdt/hwd/idm_hwd_rsp_parse.c",
      "line": 100,
      "arguments": ["1", "in_len"],
      "safe_variant": false,
      "category": "memory"
    }
  ],
  "symbols": { "functions": [...] },
  "call_graph": { "edges": [...] },
  "alloc_free": { "pairs": [...] }
}
```

#### 4b. 按 category 分组

```
string  → [call_sites where category="string"]
memory  → [call_sites where category="memory"]
io      → [call_sites where category="io"]
exec    → [call_sites where category="exec"]
sync    → [call_sites where category="sync"]
crypto  → [call_sites where category="crypto"]
```

#### 4c. 生成 Worker 任务清单

对每个有信号的 category，按映射表关联到对应 Skill。每个 Worker 任务包含：

```json
{
  "skill_id": "buffer_overflow",
  "category": "string",
  "severity": "critical",
  "cwe": "CWE-120",
  "signal_count": 3,
  "signals": [
    {
      "caller": "idm_portal_auth",
      "callee": "strcpy_s",
      "file": "src/ctrlplane/portal/idm_portal_auth.c",
      "line": 142,
      "arguments": ["dst", "sizeof(dst)", "src"],
      "safe_variant": true,
      "category": "string"
    }
  ],
  "skill_path": "$SECGUARDIAN_HOME/skills/secguard/cpp/buffer_overflow/",
  "source_root": "$USER_PROJECT"
}
```

#### 4d. 写入 Worker 任务清单到文件（可选的持久化）

```bash
source .codeagent/secguardian/.scan_state.secguard

# Dispatcher 将 Worker 任务清单写入 workers/ 目录
# 格式: workers/<skill_id>/task.json
```

#### 4e. 脱敏答案卡标注（如果 index.json 包含源码行）

> 源码中可能存在 `// VULNERABILITY [CWE-xxx]`、`// CWE-xxx`、`// BAD:` 等标注注释。
> Worker 直接读源码时会看到这些标注，影响独立判断。必须预先脱敏。

```bash
source .codeagent/secguardian/.scan_state.secguard

python3 "$SECGUARDIAN_HOME/scripts/strip-answer-cards.py" \
  --index .codeagent/secguardian/index.json \
  --source-root "$USER_PROJECT" \
  --output-dir "$USER_PROJECT/.codeagent/secguardian/stripped/"
```

若输出 "no answer cards found"，记录 INFO（非错误）。后续 Worker 从脱敏副本读取源码。

---

## Phase 2: Worker 调度

> **核心执行阶段**。Dispatcher 为每个有信号的 Skill 启动一个 Worker（subagent），Worker 独立执行 5 步检视协议，输出 findings。
>
> **Worker 是独立 subagent**，由 Dispatcher 通过 Agent 工具启动。每个 Worker 接收：
> 1. 信号清单（来自 Phase 1 的 call_sites 分组）
> 2. SKILL.md 路径（描述检视协议）
> 3. references/ 目录路径（规则细节、豁免、误报抑制）
> 4. 源码根路径（Worker 直接读取实际代码）

### 5.1 Worker 启动协议

Dispatcher 为每个有信号的 Skill 执行以下操作：

```
FOR EACH skill WITH signals:

  1. 加载 SKILL.md:  cat "$SECGUARDIAN_HOME/skills/secguard/cpp/{skill}/SKILL.md"
  2. 加载 references/ 下的文件:
     - cat "$SECGUARDIAN_HOME/skills/secguard/cpp/{skill}/references/rule.md"
     - cat "$SECGUARDIAN_HOME/skills/secguard/cpp/{skill}/references/exceptions.md"
     - cat "$SECGUARDIAN_HOME/skills/secguard/cpp/{skill}/references/cross-function.md"
     - cat "$SECGUARDIAN_HOME/skills/secguard/cpp/{skill}/references/false-positive.md"
  3. 构造 Worker 输入（信号清单 + Skill 定义 + 源码路径）
  4. 启动 Worker (subagent)
```

**Worker 输入结构：**

```json
{
  "dispatcher_context": {
    "scan_id": "sc-20260707-143000-a1b2",
    "scan_dir": ".codeagent/secguardian/secguard/scans/sc-20260707-143000-a1b2",
    "source_root": "/path/to/user/project",
    "stripped_root": "/path/to/user/project/.codeagent/secguardian/stripped",
    "index_json": ".codeagent/secguardian/index.json",
    "recorder": "$SECGUARDIAN_HOME/scripts/record-finding.py",
    "reporter": "$SECGUARDIAN_HOME/scripts/render-report.py"
  },
  "skill": {
    "id": "buffer_overflow",
    "severity": "critical",
    "cwe": "CWE-120",
    "category": "string",
    "skill_md": "... SKILL.md 内容 ...",
    "references": {
      "rule": "... rule.md 内容 ...",
      "exceptions": "... exceptions.md 内容 ...",
      "cross_function": "... cross-function.md 内容 ...",
      "false_positive": "... false-positive.md 内容 ..."
    }
  },
  "signals": [
    {
      "caller": "idm_portal_auth",
      "callee": "strcpy_s",
      "file": "src/ctrlplane/portal/idm_portal_auth.c",
      "line": 142,
      "arguments": ["dst", "sizeof(dst)", "src"],
      "safe_variant": true,
      "category": "string"
    }
  ]
}
```

### 5.2 Worker 执行协议（5 步）

每个 Worker 按以下 5 步协议独立执行。**必须在 5 轮反思通过后才能输出 finding。**

#### Step W1: 信号确认

对每个预筛信号:

1. 读取调用点源码（±15 行，从脱敏副本读取）
2. 确认调用点真实存在（排除注释、宏、条件编译中的误匹配）
3. 记录: `confirmed` / `false_signal`（如为 false_signal 则跳过，记入抑制统计）

```bash
# Worker 内的 bash 调用示例
cat "$STRIPPED_ROOT/$FILE" | head -n $((LINE + 15)) | tail -n 31
```

#### Step W2: 证据链构建

构建 Source → Propagate → Sink 三段式证据链:

- **Source**: 危险操作的源（如缓冲区目标 `dst` 的声明和大小，命令注入中的外部输入）
- **Propagate**: 数据从源到汇的传递路径（如外部输入经函数参数传递到危险调用）
- **Sink**: 实际危险操作点（如 `strcpy_s(dst, dsize, src)` 的写入操作）

**证据链示例 (buffer_overflow):**
```
Source:  dst 声明为 char dst[64]  at file.c:130
         src 来自函数参数 const char* input, 无长度校验 at file.c:135
Propagate:  input 作为参数传入 idm_portal_auth() at file.c:140
Sink:  strcpy_s(dst, sizeof(dst), input) at file.c:142
       → sizeof(dst) = 64, input 长度未知
```

**证据链示例 (command_injection):**
```
Source:  HTTP query param "cmd" 来自用户输入 at handler.c:50
Propagate:  未经验证传入 execute_command()  at handler.c:55
Sink:  system(user_input)  at executor.c:80
```

**跨函数追踪约束:**
- 如果 Sink 函数的缓冲区来自调用者，沿 index.json 调用图向上追踪 **最多 1 层**
- 超过 1 层 → 降级为 **suspicious**（不在最终报告中报告为确认漏洞，计入抑制统计）
- 注: 个别 Skill 的 `cross-function.md` 可定义更严格的 depth 限制（如 0），但不允许放松

#### Step W3: 安全变体参数审计

对 `_s` 安全变体调用（`safe_variant: true`），检查参数正确性——**安全变体不意味着自动安全**:

| 函数 | 审计项 |
|------|--------|
| `strcpy_s(dst, dsize, src)` | `dsize` 是否 `== sizeof(dst)`? `dst` 是否为数组（而非指针参数）? |
| `strcat_s(dst, dsize, src)` | `dsize` 是否考虑已有内容? `sizeof(dst) - strlen(dst) >= strlen(src)`? |
| `memcpy_s(dst, dsize, src, n)` | `dsize >= n`? `dsize == sizeof(dst)`? |
| `sprintf_s(buf, size, fmt, ...)` | `size == sizeof(buf)`? `fmt` 含 `%s` 时对应参数是否受控? |
| `snprintf(buf, size, fmt, ...)` | 返回值是否被检查（截断检测）? |

非 `_s` 变体直接进入 Step W4。

#### Step W4: 跨函数补证

沿调用图向上追踪 1 层，确认调用者传入的缓冲区大小或数据源:

1. 在 index.json 中查找调用者函数定义
2. 读取调用者源码（±10 行上下文）
3. 检查调用者是否:
   - 传入已知大小的缓冲区（`char buf[64]` → `process_data(buf, sizeof(buf))`）
   - 传入已检查长度的数据（`if (strlen(src) < MAX)` → `strcpy(dst, src)`）
   - 传入未检查的用户输入（`strcpy(dst, argv[1])` → 直接报告）
4. **depth > 1**（即调用者的调用者）→ 降级为 `suspicious`，不计入确认发现

#### Step W5: 5 轮反思

**必须完成全部 5 轮才能输出 finding。每轮通不过则降级严重度或抑制。**

| 轮次 | 名称 | 问题 | 不通过则 |
|------|------|------|---------|
| 1 | 事实校对 | 证据链中每个断言是否有源码行支撑? | 降一级严重度 |
| 2 | 因果闭环 | Source 大小 < Sink 写入大小 → 是否必然溢出? | 降级为可疑 |
| 3 | 寻找豁免 | 是否有运行时检查、编译期常量、平台保证? | 抑制 |
| 4 | 根因归并 | 同一缓冲区的多个 Sink → 合并为 1 个 finding | 去重 |
| 5 | 保守定性 | 证据不完整 → 降级; 证据完整 → 按规则定级 | 最终定级 |

**详细说明:**

**轮次 1 — 事实校对:**
- 证据链中的每行代码引用是否有对应的源码内容?
- `sizeof(dst)` 的值是否被确认（手动计算或跟踪）?
- 调用的行号是否精确匹配源码位置?
- ❌ 不通过: 证据链中任一断言无法被源码行直接支撑 → 降一级严重度（Critical→High, High→Medium, 等）

**轮次 2 — 因果闭环:**
- Source 的大小 < Sink 写入大小 → 是否必然导致溢出? 有没有中间校验?
- 对于 `strcpy_s(dst, sizeof(dst), src)`，`sizeof(dst)` 真的是 `dst` 的大小吗（指针 vs 数组）?
- 是否有中间代码截断或检查了长度?
- ❌ 不通过: 因果关系不闭合（"可能"溢出但不是"必然"溢出）→ 降级为可疑

**轮次 3 — 寻找豁免:**
- 是否存在运行时检查? (e.g., `if (strlen(src) < sizeof(dst)`)
- 是否存在编译期常量保证? (e.g., `char dst[64]`, `src` 总是 `char[8]`)
- 平台是否有自动保护? (e.g., FORTIFY_SOURCE, Safe CRT)
- 函数自身的语义保证? (e.g., `getenv` 返回值可能为 NULL，但代码检查了)
- ❌ 找到豁免 → **抑制**，不输出 finding，记入抑制统计

**轮次 4 — 根因归并:**
- 同一缓冲区是否被多个 Sink 操作? (e.g., `strcpy(dst, a)` + `strcat(dst, b)`)
- 同一函数是否多次调用同一危险函数? (e.g., 多个 `strcpy` 到不同缓冲区)
- ❌ 相同的根因（同一缓冲区、同一条数据流路径）→ 合并为 1 个 finding

**轮次 5 — 保守定性:**
- 证据不完整（如缺少 Source 信息、Propagate 路径不完整）→ 降级
- 证据完整、跨函数 depth ≤ 1、无豁免 → 按规则定义的严重度定级
- 终审裁决: `confirmed` / `suspected` / `suppressed`

### 5.3 Worker 输出格式

每个信号处理后，Worker 输出到 `$SCAN_DIR/workers/<skill_id>/` 目录:

**finding 文件（通过 `record-finding.py` 录制）:**

```bash
# Worker 内的 finding 录制
python3 "$RECORDER" \
    --command secguard \
    --scan-dir "$SCAN_DIR" \
    --from-stdin << 'RECEOF'
{
  "dispatcher_mode": true,
  "skill_id": "buffer_overflow",
  "detector": "memory.buffer_overflow",
  "severity": "Critical",
  "cwe": "CWE-120",
  "file": "src/ctrlplane/portal/idm_portal_auth.c",
  "line": 142,
  "function": "idm_portal_auth",
  "title": "strcpy_s 参数误用：dsize 不等于 sizeof(dst)",
  "snippet": "strcpy_s(dst, sizeof(dst), input)",
  "code_context": "char dst[64];\nconst char* input = getenv(\"USER_INPUT\");\n...\nstrcpy_s(dst, sizeof(dst), input);",
  "rationale": "strcpy_s dsize=sizeof(dst)=64, input 长度未知，可导致缓冲区溢出",
  "evidence_chain": {
    "source": {
      "description": "dst 声明为 char dst[64]",
      "file": "src/ctrlplane/portal/idm_portal_auth.c",
      "line": 130
    },
    "propagate": {
      "description": "input 来自 getenv() 返回值，无长度校验",
      "file": "src/ctrlplane/portal/idm_portal_auth.c",
      "line": 135
    },
    "sink": {
      "description": "strcpy_s(dst, sizeof(dst), input) — sizeof(dst)=64 但 input 长度未知",
      "file": "src/ctrlplane/portal/idm_portal_auth.c",
      "line": 142
    }
  },
  "attack_scenario": "攻击者设置 USER_INPUT 环境变量为超长字符串 → 覆盖栈上 dst 之后的数据",
  "cvss": 8.5,
  "reflection_rounds": 5,
  "rounds_passed": [true, true, true, true, true],
  "final_verdict": "confirmed",
  "fix_before": "strcpy_s(dst, sizeof(dst), input)",
  "fix_after": "if (strnlen(input, sizeof(dst)) >= sizeof(dst)) return ERROR;\nstrcpy_s(dst, sizeof(dst), input);",
  "index_json": ".codeagent/secguardian/index.json"
}
RECEOF
```

**盲区报告（当信号全部被抑制时输出）:**

每个 Worker **必须**输出盲区报告到 `$SCAN_DIR/workers/<skill_id>/blindspot.json`:

```json
{
  "skill_id": "buffer_overflow",
  "signals_received": 15,
  "findings_reported": 3,
  "findings_suppressed": 5,
  "false_signals": 7,
  "suppression_reasons": [
    {"reason": "sizeof(dst) matches dsize correctly", "count": 3},
    {"reason": "compile-time constant string source", "count": 2}
  ],
  "depth_exceeded": {
    "count": 2,
    "max_traced": 1,
    "downgraded_to_suspicious": 2
  }
}
```

**零发现报告（当 Skill 没有任何信号时）:**

```json
{
  "skill_id": "error_propagation",
  "signals_received": 0,
  "findings_reported": 0,
  "status": "no_signal",
  "assessment": "没有需检查返回值传播的 must_check 函数调用点",
  "is_blindspot": false
}
```

**关键约束:**
- **禁止非终止状态**: Worker 不得输出"需要更多上下文"、"无法确定"、"信息不足"等。必须做出确定判断：`confirmed` / `suppressed` / `downgraded_to_suspicious`
- **0 findings ≠ no_signal**: 区分 `no_signal`（无信号，真安全）和 `all_suppressed`（有信号但全部被抑制，检测盲区）
- **跨函数 depth 限制**: max depth 1，超过一律降级为 `suspicious`，不报告为确认漏洞
- **5 轮反思强制**: 任何 finding 必须经过 5 轮反思，`reflection_rounds` 字段必须为 5
- **suppress-first**: 不确定 → 抑制。仅报告有完整证据链的 finding

### 5.4 特殊 Skill 处理

#### hardcoded_secrets（非 call_site 驱动）

此 Skill 不依赖 call_sites 信号。Worker 改为扫描源码中的字符串/密钥模式:

1. 从 index.json 获取文件清单（`symbols.functions[].file` 去重）
2. 对每个源码文件扫描以下模式:
   - 硬编码密码: `password = "..."`, `passwd = "..."`, `pwd = "..."`
   - 硬编码密钥: `secret_key = "..."`, `api_key = "..."`, `token = "..."`
   - 硬编码加密 IV/盐: `iv = "..."`, `salt = "..."`
   - 注释中的凭据: `// password: ...`, `// user: ... / pass: ...`
3. 根据 `min_string_length`（灵敏度配置）过滤短字符串
4. 执行 5 轮反思确认

#### error_propagation（独立扫描）

此 Skill 不依赖 call_sites 信号。Worker 改为扫描返回值检查:

1. 从 index.json 的 `call_sites` 中筛选 `must_check` 标记的函数调用
2. 对每个调用点检查返回值是否被使用、检查、或传播
3. 识别模式:
   - `if (func() == ERROR)` → 已检查
   - `int ret = func()` → 部分检查（需确认 ret 后续使用）
   - `func()` → 返回值被丢弃（报告）
   - `(void)func()` → 显式丢弃（是否报告取决于灵敏度配置）
4. 执行 5 轮反思确认

### 5.5 信号数量过大时的裁剪策略

当单个 Skill 的信号数量超过 50 时：

1. 按严重度排序: `safe_variant: false` 信号优先于 `safe_variant: true`
2. 同类信号去重: 同一文件同一函数的多个同 callee 信号合并
3. 只处理 top-50；剩余标记为 `unprocessed`，计入盲区报告
4. 策略可通过 `sensitivity.yaml` 的 `check_radius` 和优先级配置调整

---

## Phase 3: 汇总与渲染

> 所有 Worker 执行完毕后，Dispatcher 汇总结果并生成报告。

### Step 6: 汇总 Worker 产物

1. 遍历 `$SCAN_DIR/workers/<skill_id>/` 下的每个 Worker 输出
2. 收集所有 finding 文件（`record-finding.py` 已录制到 `findings/` 目录树）
3. 收集所有盲区报告（`blindspot.json`）
4. 汇总到 `worker_manifest.json`:

```json
{
  "scan_id": "sc-20260707-143000-a1b2",
  "workers_dispatched": 8,
  "workers_with_findings": 3,
  "workers_all_suppressed": 2,
  "workers_no_signal": 3,
  "total_signals_processed": 45,
  "total_findings_reported": 7,
  "total_suppressed": 12,
  "total_suspicious": 4,
  "total_unprocessed": 0,
  "workers": {
    "buffer_overflow": {
      "status": "has_findings",
      "signals": 15, "reported": 3, "suppressed": 5, "suspicious": 2
    },
    "null_dereference": {
      "status": "all_suppressed",
      "signals": 8, "reported": 0, "suppressed": 8
    },
    "error_propagation": {
      "status": "no_signal",
      "signals": 0, "reported": 0
    }
  }
}
```

### Step 7: 去重

同一调用点被多个 Skill 报告 → 保留最高严重度的 finding:

| 规则 | 示例 |
|------|------|
| 同一 `file:line` 跨多个 Skill | `buffer_overflow` 和 `must_check` 都报告同一 `strcpy_s` 调用 → 保留 `buffer_overflow`（Critical > Medium） |
| 同一缓冲区多个 Sink | 同一函数内 `strcpy(dst, a)` + `strcat(dst, b)` → 合并为 1 个 finding |
| 证据链冗余 | 两个 finding 的 Source/Propagate 完全相同 → 合并 |

去重规则由 Dispatcher 在上下文中执行（不通过 bash 脚本）。

### Step 8: 验证 findings

```bash
source .codeagent/secguardian/.scan_state.secguard

python3 "$SECGUARDIAN_HOME/scripts/validate-findings.py" \
    --findings-dir "$SCAN_DIR/findings/" \
    --check-spec
VALIDATE_EXIT=$?
if [ $VALIDATE_EXIT -eq 0 ]; then
    echo "  All findings pass validation + spec cross-check"
else
    echo "  Spec validation found violations — findings must be regenerated"
    echo "  Dispatcher must re-read SKILL.md Detection Spec and fix severity/CWE/evidence"
fi
```

> Spec 校验是强约束：finding 的 severity、CWE、evidence 必须匹配对应 SKILL.md 的 Detection Spec。跳过规则文件加载的 finding 将被拒绝。

### Step 9: 渲染最终输出

```bash
source .codeagent/secguardian/.scan_state.secguard

RENDERER="$SECGUARDIAN_HOME/scripts/render-report.py"

python3 "$RENDERER" \
    --command secguard \
    --scan-id "$SCAN_ID" \
    --findings-dir "$SCAN_DIR/findings/" \
    --index .codeagent/secguardian/index.json \
    --worker-manifest "$SCAN_DIR/worker_manifest.json" \
    --output "$SCAN_DIR/"
```

渲染器自动生成: `report.md` + `results.sarif` + `summary.json` + `manifest.json` + `status.json` + `human/executive-summary.md` + `dashboard.html` + `ai/remediation-pack.json` + `delta.json`。

> 如果渲染器不存在或执行失败，打印警告：`"Renderer unavailable — findings saved to findings/ directory tree only."`

### Step 10: 输出摘要

读取 `manifest.json` 获取扫描统计，向用户输出 Markdown 格式的扫描摘要。

```markdown
## secguard 扫描完成

Scan ID: sc-20260707-143000-a1b2
Project: <project-name>
Workspace: <user-project>
Path: ./src
Mode: full | Language: cpp | Dispatcher v2

### 调度统计
- Worker 调度: 8 dispatched, 3 with findings, 2 all suppressed, 3 no signal
- Signal 处理: 45 processed, 12 suppressed, 4 suspicious (depth exceeded)
- 扫描文件: 12, 扫描行: 450

### 结果
- 检出: 7 (Critical: 1, High: 2, Medium: 4)
- 安全评分: 45/100 🔴

### 检出
| # | Severity | Skill | File | 证据链摘要 |
|---|----------|-------|------|-----------|
| #1 | Critical | memory.buffer_overflow | src/parser.c:36 | sizeof(dst)=64, input 长度未知 → 溢出 |
| #2 | High | memory.null_dereference | src/network.c:305 | calloc 返回值无 NULL 检查 |
| #3 | High | exec.command_injection | src/executor.c:89 | system() 参数来自用户输入 |

### 盲区统计
| Skill | 信号数 | 抑制 | 可疑 | 原因 |
|-------|--------|------|------|------|
| null_dereference | 8 | 8 | 0 | 全部使用 safe wrapper |
| error_propagation | 0 | 0 | 0 | no_signal — 代码中无 must_check 调用 |

> 文件命名: `<SHA12>_<FILE_SLUG>-<LINE>.json` — 前 12 位 SHA-256 确保唯一性，后缀 _file-line 帮助定位。

统一入口: `.codeagent/secguardian/secguard/scans/sc-20260707-143000-a1b2/human/executive-summary.md`
完整报告: `.codeagent/secguardian/secguard/scans/sc-20260707-143000-a1b2/report.md`
仪表盘: `.codeagent/secguardian/secguard/scans/sc-20260707-143000-a1b2/dashboard.html`
AI 修复包: `.codeagent/secguardian/secguard/scans/sc-20260707-143000-a1b2/ai/remediation-pack.json`
SARIF: `.codeagent/secguardian/secguard/scans/sc-20260707-143000-a1b2/results.sarif`
Worker 清单: `.codeagent/secguardian/secguard/scans/sc-20260707-143000-a1b2/worker_manifest.json`

如何使用扫描结果？
- **快速看汇总** → 打开 `manifest.json`
- **统一入口** → `human/executive-summary.md`
- **工程师修复** → 按检测器：`findings/<detector>/`
- **管理层仪表盘** → 浏览器打开 `dashboard.html`
- **安全工程师** → 打开 `report.md`
- **AI Agent 修复** → `/secfix <scan-id>` 自动修复
- **CI/CD 集成** → 消费 `results.sarif`
```

---

## 输出文件命名规范

所有 finding 文件命名格式：`<SHA12>_<FILE_SLUG>-<LINE>.json`

| 组成部分 | 说明 | 唯一性 |
|---------|------|--------|
| `SHA12` | SHA-256(`detector:file:line:cwe`) 前 12 hex | 不同输入几乎零碰撞 |
| `FILE_SLUG` | 文件名去扩展名，无缩写 | 工程师快速定位 |
| `LINE` | 行号（纯数字，无前缀） | 同行同 detector 只产一个 finding |

**不会碰撞**: SHA-256 以 `detector:file:line:cwe` 为输入，碰撞概率 < 2^-48。对齐 SARIF partialFingerprints。

示例:
```
findings/memory/buffer_overflow/a1b2c3d4e5f6_parser-36.json
findings/exec/command_injection/f6e5d4c3b2a1_executor-89.json
```

---

## 附录 A: 15 个 Skill 清单

| # | Skill | call_sites category | Source | 检测内容 |
|---|-------|---------------------|--------|---------|
| 1 | buffer_overflow | string + memory | 灵码 | strcpy/strcat/sprintf 及 `_s` 变体参数误用 |
| 2 | null_dereference | memory | 灵码 | malloc/calloc/realloc 后无 NULL 检查 |
| 3 | memory_leak | memory | 灵码 | malloc/calloc 无配对 free |
| 4 | double_free | memory | 灵码 | 同一指针多次 free |
| 5 | use_after_free | memory | 灵码 | free 后继续使用指针 |
| 6 | integer_overflow | memory | 灵码 | 整数运算溢出导致缓冲区大小错误 |
| 7 | resource_leak | io | 灵码 | fopen/socket/open 无配对 close |
| 8 | command_injection | exec | 灵码 | system/popen/exec 参数来自用户输入 |
| 9 | input_validation | exec | 灵码 | 外部输入未校验即使用 |
| 10 | hardcoded_secrets | crypto* | SecGuardian | 密钥/密码硬编码（非 call_site 驱动） |
| 11 | must_check | memory + io | 灵码 | 函数返回值必须检查但未检查 |
| 12 | ownership_transfer | memory | 灵码 | 所有权转移后原指针继续使用 |
| 13 | api_semantic_misuse | * | 灵码 | API 副作用与隐式语义误用 |
| 14 | lock_misuse | sync | 灵码 | 互斥锁 lock/unlock 不配对 |
| 15 | error_propagation | * | 灵码 | 错误码未传播或被吞没（非 call_site 驱动） |

*: hardcoded_secrets 映射到 crypto category 但实际使用模式匹配扫描。

---

## 附录 B: Worker 协议摘要

| 条目 | 规则 |
|------|------|
| 输入 | 信号清单 + SKILL.md + references/ + 源码根路径 |
| 执行步骤 | W1 信号确认 → W2 证据链构建 → W3 安全变体审计 → W4 跨函数补证 → W5 5 轮反思 |
| 5 轮反思 | 事实校对 → 因果闭环 → 寻找豁免 → 根因归并 → 保守定性 |
| 输出 | finding（通过 record-finding.py）+ blindspot.json（每个 Worker） |
| 禁止 | 非终止状态（"需要更多上下文"、"无法确定"） |
| suppress | 不确定 → 抑制。仅完全证据链才报告 |
| 跨函数 depth | max 1，超过 → downgrade to suspicious |
| 信号上限 | top-50 per Skill，剩余标记 unprocessed |

---

## 附录 C: 降级方案 — Worker 不可用

如果当前平台不支持 subagent (Agent工具)，Dispatcher 降级为**单 Worker 串行执行**：

1. 保留 Phase 1（索引与信号生成）不变
2. 跳过 Agent 启动步骤，Dispatcher 自身作为唯一 Worker
3. 按 Skill 优先级逐个执行 5 步检视协议
4. 保留所有其他约束（5 轮反思、suppress-first、depth 限制、禁止非终止状态）
5. Phase 3 汇总与渲染不变

此降级方案的唯一损失是并发度，检测质量保持不变。
