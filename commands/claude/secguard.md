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

Claude 基线是主上下文串行处理每个 `(rule_id, batch_id)`；Agent 仅是可选隔离增强，不能改变共享协议或跳过强制链。

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

# 引擎产出平台无关 partition 计划：{rule: [batch1, batch2, ...]}
python3 "$SCRIPTS_DIR/partition-signals.py" \
    --index "$USER_PROJECT/.codeagent/secguardian/index.json" \
    --rules-dir "$RULES_DIR" \
    --batch-size 20 \
    --json > "$SCAN_DIR/partition-plan.json"
```

### Step 5-8: per (rule, batch) Investigation Pipeline — Agent 隔离强制执行

> **设计依据**: `knowledge/protocols/dispatch-protocol.md §3`（共享 Investigation Pipeline）+ ADR-006（per-rule 隔离任务 + 引擎预过滤）。
> **关键决策 (CHANGE-004)**: 串行内联被测试证伪——LLM 在共享上下文中读数个完整文件后自行丢弃剩余规则。每个 (rule, batch) 必须由独立 Agent 子代理执行，实现真上下文隔离，确保规则完整性不可由 LLM 自由意志绕过。

**调度模式（唯一，不可绕过）：**

```
每个 (rule, batch) = 一个 Agent 子代理（真上下文隔离）
```

- Pilot batch: 选择 signal 最少的非空 batch，串行内联执行。pilot 的 verification-gate 校验失败时立即停止，禁止启动剩余 Agent。
- 剩余 batch: Agent 滚动并发，并发上限 = min(4, remaining_batches)。一个 Agent 完成才补一个。
- 每个 Agent 只处理一个精确 `(rule_id, batch_id)`，禁止合并多个 rule 或 batch。

**上下文隔离硬约束（CHANGE-004）：**
- 每个 Agent 启动时，上下文是干净的：不包含其他 rule 的调查内容、不包含完整源文件
- 每个 Agent 只能 `Read`:
  1. 唯一 `rule.md`（该 batch 的规则文件）
  2. batch 信号中每个 signal 的源码窗口：`Read(file, offset=signal.line-N, limit=2N)`，N 默认 15
  3. 禁止不带 offset/limit 的 Read 调用（禁止读完整源文件）
- Agent 上下文结束后，主 dispatcher 只收：findings 摘要 + 工件路径。不累积完整 Investigation 内容。

**Agent 工作流程（Steps 5-8，每个 Agent 内独立执行）：**

1. 从主 dispatcher 接收 `rule_id`、`batch_id`、`rule.md` 路径、batch 信号列表
2. 读取 `rule.md` 获取 Detection Spec + Q-matrix canonical 名
3. 对每个 signal，Read 源码窗口（带 offset/limit）→ Hypothesis Generator → Investigator → Counter Evidence → Judge + Q-matrix → Record
4. 工件写入 `workers/<rule_id>/<batch_id>/`，禁止多个 batch 共用文件
5. 返回 findings 摘要给主 dispatcher

**主 dispatcher 上下文约束：**
- 禁止预读全部 rule.md、全部源码或完整 signal-rich plan
- 只读 compact partition schedule（rule_id + batch_id + signal 数）+ 完成事件通知
- 不轮询 Agent，不维护自然语言 running total
- 所有统计从 gate/manifest artifacts 读取

**Agent prompt 结构（每个 Agent 收到）：**
```
你是 SecGuardian 安全分析专家。执行以下 isolated batch 的 Investigation Pipeline:

RULE: {rule_id}
BATCH: {batch_id}
RULE_FILE: {path/to/rule.md}
SIGNALS: [{signal_id, file, line, kind, category}, ...]

工作目录: workers/{rule_id}/{batch_id}/

执行 Steps 5-8:
- Step 5: 读 rule.md → 对每个 signal 生成 3-5 假设 → 写 hypotheses.json
- Step 6: 逐假设收集三段式证据 → 写 evidence.json
- Step 7: 逐 signal 尝试推翻 → 写 counter_evidence.json
- Step 7.5: 用 rule.md 的 Q-matrix canonical 名判决 → 写 judge_verdict.json
- Step 8: CONFIRMED → record-finding.py 录入

返回: {confirmed: N, suppressed: M, findings: [...]}
```

**引擎强制（Agent 返回后，主 dispatcher 执行）：**
```bash
# verification-gate: anchor/severity/Q-matrix 校验 → gate-audit.json
python3 "$SCRIPTS_DIR/verification-gate.py" \
    --index "$USER_PROJECT/.codeagent/secguardian/index.json" \
    --scan-dir "$SCAN_DIR/"
# coverage-gate: 所有 (rule,batch) 完成后的 scan 级覆盖核算
python3 "$SCRIPTS_DIR/coverage-gate.py" \
    --plan "$SCAN_DIR/partition-plan.json" \
    --scan-dir "$SCAN_DIR/"
```

> **规则完整性保证**: per-rule 纪律由引擎强制（coverage-gate 逐 assignment 核销）+ Agent 上下文隔离（LLM 无法因上下文压力丢弃未处理的规则）。漏跑 rule → 该 rule 信号未 investigated → coverage-gate BLOCKED。

### Step 8.5: 引擎强制（验证 + 覆盖门禁）

```bash
# verification-gate: anchor/severity 校验 → gate-audit.json（confirmed 才计入 CI）
python3 "$SCRIPTS_DIR/verification-gate.py" \
    --index "$USER_PROJECT/.codeagent/secguardian/index.json" \
    --scan-dir "$SCAN_DIR/"
# coverage-gate: batch-suppression 拦截（signals>0 且 0 investigated → BLOCKED exit 1）
python3 "$SCRIPTS_DIR/coverage-gate.py" \
    --plan "$SCAN_DIR/partition-plan.json" \
    --scan-dir "$SCAN_DIR/" \
    --json > "$SCAN_DIR/coverage-audit.json"
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
