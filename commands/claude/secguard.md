---
name: secguard
description: "[Claude Code] 安全加固检视 — 基于共享调度协议执行信号分区和逐规则调查，支持串行基线与可选 Agent 隔离"
platform: claude
---

# /secguard — Dispatcher Protocol v2 (EPIC-3) [Claude Code]

## Command Layer

对源码执行安全加固扫描。采用 Investigation Engine 架构：Dispatcher 信号提取 → Hypothesis Generator 多假设 → Investigator 自主取证 → Judge 独立裁决。

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

遵循 `$SECGUARDIAN_HOME/knowledge/protocols/scan-output.md` 的 Scan Output Protocol 8.0。人读/机读分离。

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

## Engine Layer — Claude Adapter

> 共享分区、Investigation Pipeline、工件路径、判决语义和强制门禁只由 `$SECGUARDIAN_HOME/knowledge/protocols/dispatch-protocol.md` 定义。本 command 只拥有 Claude 的工具调用、状态恢复和可选 Agent 隔离方式，不建立第二份协议。
>
> **隔离约束**: Dispatcher 只能加载 `$SECGUARDIAN_HOME/skills/secguard-<language>/` 下的 Skill，禁止加载 `skills/secaudit-secaudit/` 或 `skills/secreview-<language>/` 下的任何文件。知识文件从 `$SECGUARDIAN_HOME/knowledge/` 用 Claude Code 原生 `Read` 工具按需读取。禁止用 `bash cat` 读取知识文本（shell stdout 开销；与 OpenCode/Gemini 对齐）。
>
> 🚫 **不要使用 `todowrite` 工具。** 使用原生 task 系统追踪进度。
> 🚫 **不要硬编码 `RECORDER` 路径。** 必须使用 `$SCRIPTS_DIR/record-finding.py`。
> 🚫 **禁止用 `read` 工具读取 `$SCRIPTS_DIR/` 下的脚本文件。** 所有脚本通过 `Bash` 工具执行。

Claude 调度原语见 `knowledge/protocols/dispatch-protocol.md §5`。每个 (rule, batch) 必须由独立 Agent 子代理执行（真上下文隔离，CHANGE-004：串行内联被测试证伪）。禁止在主上下文串行内联完整 Steps 5-8。

## Phase 0: 关键警告（Claude Code 通用）

> **⚠️ 本模板中所有 `$SCAN_DIR`、`$SCAN_ID`、`$USER_PROJECT`、`$SECGUARDIAN_HOME` 引用都是 shell 变量。**
> **不要在文件系统路径中直接使用字面量 `$SCAN_DIR`！必须先在 bash 中执行 source 才能展开。**
>
> 正确: `mkdir -p "$SCAN_DIR/findings"`（在 bash 里执行，SCAN_DIR 已被 source）
> 错误: 直接在文件路径写 `$SCAN_DIR/findings`（AI 将创建字面目录）
>
> **输出路径规则:**
> - `.codeagent/` 目录放在**用户项目根目录**下（由 `<path>` 参数推断父目录）
> - session 文件（`session-*.md`）是 Claude Code 专有产物，OpenCode 中不需要创建
> - 所有扫描输出写入 `.codeagent/secguardian/secguard/scans/<scan-id>/` 下

## Phase 1: 索引与信号生成

> Dispatcher 直接执行的阶段。**每个 bash 调用互相独立，shell 变量不跨调用共享。**

<!-- @secguardian:ordering rule=scan_id FIRST -->
### Step 1: 初始化（仅一次 bash 调用，使用共享 init-scan.sh）

> **唯一一次预初始化 bash 调用**。通过 `scripts/init-scan.sh` 完成自动发现、健康检查、路径确认、建目录、状态持久化，替代旧版 ~40 行复制粘贴代码。
> **禁止**在 Step 1 前后插入任何独立的 bash 命令。

```bash
source "$HOME/.claude/plugins/secguardian/scripts/init-scan.sh" secguard "<path>" "<language>"
```

### 🔒 跨 Shell 状态传递规则

> **每个 bash 调用都是独立 shell，变量不共享。禁止用 `/tmp/` 或任何系统临时目录传状态。**
>
> ⚠️ `$SECGUARDIAN_HOME` **只在 source `.scan_state.secguard` 后的 bash shell 中可用**。不要在 source 之前直接引用 `$SECGUARDIAN_HOME`（值为空，路径变成 `/scripts/`）。
>
> ⚠️ **禁止对 `$SCRIPTS_DIR/` 执行 `ls`、`find`、Glob 等探索操作。** 所有脚本路径已在模板中硬编码。探索多余目录浪费上下文。

**从 Step 2 开始，每个 bash 调用必须在开头执行以下命令**（这样 `$SCAN_DIR`、`$SCAN_ID`、`$USER_PROJECT`、`$SECGUARDIAN_HOME` 才能正确展开）:

> **知识库读取**: 知识库文件（`rule.md`、`references/*.md`、`knowledge/protocols/*.md`）通过 Claude Code 原生 `read` 工具读取。
> **排除项：`$SCRIPTS_DIR/secguardian-index`**（编译的 Go 二进制）不能通过 `read` 或 `cat` 查看内容。只能通过 bash 执行（`"$INDEXER" --lang ...`）。

### Step 2: 构建语义索引（不可跳过）

> 索引器产出 `call_sites`（库函数调用点 + 参数摘要），作为 Phase 2 Worker 的任务信号清单。**不执行此步骤将导致 Worker 没有信号指引。**
> 索引自动复用同路径缓存。加 `--force` 强制重建。

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

INDEXER="$SCRIPTS_DIR/secguardian-index"
# 超时保护: timeout 30s
if command -v timeout &>/dev/null; then
    timeout 30 "$INDEXER" --lang "$SCAN_LANG" --path "$SCAN_PATH" --output "$USER_PROJECT/.codeagent/secguardian/index.json" || {
        echo "FAIL: Indexer timed out after 30s or failed — cannot continue"
        echo "  macOS: brew install coreutils  (provides 'timeout' command)"
        exit 1
    }
elif command -v gtimeout &>/dev/null; then
    gtimeout 30 "$INDEXER" --lang "$SCAN_LANG" --path "$SCAN_PATH" --output "$USER_PROJECT/.codeagent/secguardian/index.json" || {
        echo "FAIL: Indexer timed out after 30s or failed — cannot continue"
        exit 1
    }
else
    echo "WARNING: 'timeout' not found — indexer runs without timeout protection"
    "$INDEXER" --lang "$SCAN_LANG" --path "$SCAN_PATH" --output "$USER_PROJECT/.codeagent/secguardian/index.json"
fi
if [ ! -f "$USER_PROJECT/.codeagent/secguardian/index.json" ]; then
    echo "FATAL: Indexer failed — cannot continue"
    exit 1
fi
```

### Step 3: 验证索引完整性

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"
python3 "$SCRIPTS_DIR/validate-index.py" "$USER_PROJECT/.codeagent/secguardian/index.json" || { echo "FATAL: index invalid"; exit 1; }
```

### Step 4: 信号分区（per-rule 隔离，引擎强制）

> **依据**: `knowledge/protocols/dispatch-protocol.md`（单一真理源）。per-rule 隔离 + 引擎预过滤，三平台行为一致；Claude 平台调度原语见该协议 §5。

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

python3 "$SCRIPTS_DIR/partition-signals.py" \
    --index "$USER_PROJECT/.codeagent/secguardian/index.json" \
    --rules-dir "$RULES_DIR" \
    --batch-size 20 \
    --json > "$SCAN_DIR/partition-plan.json"
```

### Step 5: 生成 compact schedule + Agent prompts [NON-SKIPPABLE]

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

# compact schedule（LLM 只读 stdout）
python3 "$SCRIPTS_DIR/compact-schedule.py" --plan "$SCAN_DIR/partition-plan.json"

# 标准化 Agent prompts（含 canonical JSON schema）
python3 "$SCRIPTS_DIR/gen-task-prompts.py" \
    --plan "$SCAN_DIR/partition-plan.json" \
    --project "$USER_PROJECT" \
    --scan-dir "$SCAN_DIR" \
    --index-json "$USER_PROJECT/.codeagent/secguardian/index.json" \
    --json > "$SCAN_DIR/task-prompts.json"
```

### Step 6-9: per-batch Agent dispatch [NON-NEGOTIABLE]

> Claude Code 用 `Agent` 工具实现真上下文隔离。每个 Agent 的 prompt 来自 `task-prompts.json` 的 `prompt` 字段原文。

| 阶段 | 操作 | 工具 |
|------|------|------|
| Pilot | 选 signal 最少的 batch，内联执行 | `Bash` + `Read`（仅该 batch 的 rule.md + 源码窗口） |
| 剩余 | 每个 batch 一个 Agent，滚动并发（上限 4），prompt 取自 `task-prompts.json` | `Agent` |
| 验证 | 每个 Agent 返回后检查 canonical 工件存在 | `Bash` |

**禁止**：
- 读完整 `partition-plan.json`（用 compact-schedule.py 代替）
- 手写 Agent prompt（全部来自 `task-prompts.json`）
- 合并多个 batch 到一个 Agent
- 父 dispatcher 读 rule.md / 源码 / judge_verdict.json
- `todowrite`、探索目录、Read 二进制文件
- 临时文件用 `/tmp/`（`gen-task-prompts.py` 已创建 `$SCAN_DIR/.tmp/`）

### Step 10: 引擎强制 + Phase 3 验证 [NON-SKIPPABLE]

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

# verification + coverage gate
python3 "$SCRIPTS_DIR/verification-gate.py" \
    --index "$USER_PROJECT/.codeagent/secguardian/index.json" \
    --scan-dir "$SCAN_DIR/"
python3 "$SCRIPTS_DIR/coverage-gate.py" \
    --plan "$SCAN_DIR/partition-plan.json" \
    --scan-dir "$SCAN_DIR/"

# verdict 汇总
python3 "$SCRIPTS_DIR/scan-verdicts.py" --scan-dir "$SCAN_DIR/"

# findings 查询
python3 "$SCRIPTS_DIR/show-findings.py" --scan-dir "$SCAN_DIR/" --summary
```

gate 非零退出 → 禁止渲染。`gate-audit.json` 中 `needs_review > 0` → 不渲染。

### Step 11: 渲染最终输出

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

RENDERER="$SCRIPTS_DIR/render-report.py"
python3 "$RENDERER" \
    --command secguard \
    --scan-id "$SCAN_ID" \
    --findings-dir "$SCAN_DIR/findings/" \
    --path "$SCAN_PATH" \
    --language "$SCAN_LANG" \
    --index "$USER_PROJECT/.codeagent/secguardian/index.json" \
    --output "$SCAN_DIR/" \
    --ci
```

### Step 12: 输出摘要（Project/Path 信息来源）

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"
echo "SCAN_PATH=$SCAN_PATH"
echo "USER_PROJECT=$USER_PROJECT"
```

**输出格式（禁止占位符）**：
```
## secguard 扫描完成

Scan ID: <实际scan_id> | Project: <USER_PROJECT最后一级> | Path: <SCAN_PATH相对路径> | Language: cpp
```

任一 gate 命令非零退出，或 `gate-audit.json` 中 `needs_review > 0`，扫描状态立即为 **BLOCKED**。禁止执行 Step 9，禁止把候选 finding 称为 confirmed；只输出失败的 rule/batch 和工件路径供诊断。

### Step 9: 渲染最终输出

```bash
USER_PROJECT="$(cd "$(dirname "<path>")" && pwd)"
source "$USER_PROJECT/.codeagent/secguardian/.scan_state.secguard"

RENDERER="$SCRIPTS_DIR/render-report.py"

python3 "$RENDERER" \
    --command secguard \
    --scan-id "$SCAN_ID" \
    --findings-dir "$SCAN_DIR/findings/" \
    --path "$SCAN_PATH" \
    --language "$SCAN_LANG" \
    --index "$USER_PROJECT/.codeagent/secguardian/index.json" \
    --output "$SCAN_DIR/" \
    --ci
```

渲染器自动生成: `report.md` + `results.sarif` + `summary.json` + `manifest.json` + `status.json` + `human/executive-summary.md` + `dashboard.html` + `ai/remediation-pack.json` + `delta.json`。

> 如果渲染器不存在或执行失败，打印警告：`"Renderer unavailable — findings saved to findings/ directory tree only."`

### Step 10: 输出摘要（遵循统一 CLI 输出协议）

读取 `manifest.json` 获取扫描统计，并原样输出 renderer 生成的 `cli-summary.md`。不得由 LLM 重算 finding 数量、Severity 或重新组织发现表。格式由 `knowledge/protocols/scan-output.md §CLI 输出摘要` 唯一定义。

**secguard 特有规则：**
- **统计表**：按 Worker 展开（`信号数 | 检出 | 抑制 | 误报` 列），这是 secguard 独有的信号级明细
- **0 finding 附加注释**：在统计表下方说明未映射信号（如 "X 个 io close() 调用当前 Skill 范围未覆盖"）
- **Rule 列**：填充 `rule_id`，缺失时使用 detector ID。发现表必须使用 `Severity | Rule | Location | Summary`，Location 为 `file:line`。

**0 finding 示例：**

```markdown
## secguard 扫描完成

Scan ID: sc-YYYYMMDD-HHMMSS-xxxx | Project: <project> | Path: <path> | Language: <lang> | Mode: <mode>

### 扫描统计

| 项目 | 数值 |
|------|------|
| 扫描文件 | 225 |
| 信号数 | 66 |
| 检出 | 0 |

**Worker 明细：** log_injection 39 信号已抑制，deserialization 14 已抑制，command_injection 1 已抑制。

*其中 12 个 io 信号（close() 调用）当前 Skill 范围未覆盖。*

### 安全评分

**100/100 🟢 Grade A — 无可报告发现。**
```

**有 finding 示例：**

```markdown
## secguard 扫描完成

Scan ID: sc-YYYYMMDD-HHMMSS-xxxx | Project: <project> | Path: <path> | Language: <lang> | Mode: <mode>

### 扫描统计

| 项目 | 数值 |
|------|------|
| 扫描文件 | 15 |
| 信号数 | 45 |
| 检出 | 7 (Critical: 1, High: 2, Medium: 4) |

**Worker 明细：** buffer_overflow 7 检出 / 12 抑制 / 26 误报，null_dereference 4 检出 / 4 抑制。

### 发现详情

| Severity | Rule | Location | Summary |
|----------|------|----------|---------|
| 🔴 Critical | memory.buffer_overflow | src/parser.c:36 | sizeof(dst)=64, input未知 |
| 🟠 High | memory.integer_overflow | src/network.c:46 | size calc overflow |
| 🟠 High | web.sql_injection | src/webapp.c:59 | sprintf SQL from input |

### 安全评分

**55/100 🟡 Grade C — 存在需关注的风险。**
```

**输出文件：**
- `report.md`、`results.sarif`、`summary.json`、`status.json`、`dashboard.html`

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
