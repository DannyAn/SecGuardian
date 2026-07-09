# SDD: Worker Context Isolation — 跨平台子任务调度

> **Date**: 2026-07-09 | **Priority**: P0 | **Estimate**: 1 session

---

## 1. Problem Statement

### 1.1 当前现象

生产环境扫描（pkmhipster Java 项目）在 OpenCode 平台上运行 `/secguard` 时，所有 Worker 在**同一个 LLM context** 中串行执行：

| 工具 | Worker 数量 | 调度方式 | Context 隔离 | 并发度 |
|------|------------|---------|-------------|-------|
| Claude Code | 5 | Agent 工具（子会话） | ✅ 完全隔离 | ✅ 并行 |
| **OpenCode** | **5** | **内联串行（附录 C）** | **❌ 共享** | **❌ 串行** |

同一问题影响 secreview 和 secaudit 指令。

### 1.2 根本原因

`commands/secguard.md`（及 secreview.md、secaudit.md）指令模板写死了 `Agent` 工具名来启动 Worker。OpenCode 上没有 `Agent` 工具，自动降级到附录 C —— Dispatcher 自身充当唯一 Worker，内联加载所有 rule.md，信号混在同一个 context。

### 1.3 危害

| 问题 | 影响 |
|------|------|
| **上下文污染** | deserialization 的信号与 log_injection 混在一个 context，语义边界模糊 |
| **级联偏见** | 前一 skill 的判断结论影响后一个（"前面说是安全的，我这个也安全"） |
| **单点失败** | 一个 Worker 超时 → 整个扫描中断，不是只丢一个 skill |
| **Context 天花板** | 大项目 ~1000 callsites 下内联无法执行事实锚定反思 |

### 1.4 设计初衷

> Worker **子任务隔离的核心价值不是"并发"——而是 Context Isolation。**
>
> 每个 Worker 必须有独立 LLM context，才能可靠执行事实锚定反思（3 个域专用 Yes/No 问题）。共享 context 中前一个 skill 的分析结论会污染后一个的判断。

---

## 2. 设计约束

| # | 约束 | 来源 |
|---|------|------|
| C-01 | **Skill 保持平台中立** — SKILL.md 和 rule.md 不出现任何平台相关字段 | 架构决策 |
| C-02 | **Command 拥有调度权** — command 文件决定如何启动 Worker、用什么工具 | 架构决策 |
| C-03 | **不引入 agents/ 目录** — Worker 协议在 command 文件中内联，不需要预注册角色文件 | 架构决策 |
| C-04 | **三命令一致** — secguard/secreview/secaudit 都要做 | cross-command 需求 |
| C-05 | **Claude Code 零退化** — 现有 Agent 调度路径不受影响 | 现有用户保护 |

### 2.1 决策过程

关键问题：OpenCode 的 `background-task` 工具启动子代理时是否需要预注册角色文件？

调查结论：**不需要。**

OpenCode SDK 定义：

```
SubtaskPartInput = {
    prompt: string;       // Worker 的完整指令（直接接收）
    agent: string;        // 角色名（标签，不是文件引用）
    description: string;  // 简短描述
}
```

`prompt` 字段直接接收 Worker 协议的完整指令。Worker 的 5 步检视协议已经在 command 文件（secguard.md §5.2）中定义，直接通过 `prompt` 传给 `background-task`，不需要任何预注册角色文件。

这意味着：
- **不需要 `agents/` 目录**（原方案 A 废弃）
- **不需要 Worker 角色文件**（不复制、不注册）
- command 文件直接写 `background-task(prompt="<Worker 协议>", signals=[...])`
- Skill 保持纯检测知识，零平台感知

---

## 3. 架构方案

### 3.1 命令文件按平台分离

```
commands/
├── claude/                    ← Claude Code 专用命令文件（从现有 commands/*.md 迁移）
│   ├── secguard.md            ← 写死 Agent 工具启动 Worker
│   ├── secreview.md
│   ├── secaudit.md
│   └── secfix.md
├── opencode/                  ← OpenCode 专用命令文件（新建，使用 background-task）
│   ├── secguard.md
│   ├── secreview.md
│   ├── secaudit.md
│   └── secfix.md
└── gemini/                    ← 已有，不变
    ├── secguard.toml
    ├── secaudit.toml
    ├── secreview.toml
    └── secfix.toml
```

部署映射（由 `deploy.sh` 和 `release.sh` 执行）：

```
Claude Code  →  commands/claude/*.md   →  .claude/plugins/secguardian/commands/
OpenCode     →  commands/opencode/*.md →  ~/.config/opencode/extensions/secguardian/commands/
               + 同步到 ~/.config/opencode/commands/
Gemini       →  commands/gemini/*.toml →  .gemini/extensions/secguardian/commands/
```

### 3.2 控制流

```
Skill (纯知识)                     rule.md + SKILL.md
                                      ↑
                                      │ 读取检测规则
                                      │
┌─────────────────────────────────────────────────────────────┐
│  Command (调度权)              平台感知                      │
│                                                             │
│  Phase 1: 索引 + 信号生成 (共享)                              │
│    secguardian-index --path → index.json                     │
│    validate-index.py → 信号分组                              │
│                                                             │
│  Phase 2: Worker 调度 (平台差异)                              │
│    Claude Code:                                              │
│      Agent(skill_id, signals, rule.md, protocol)              │
│    OpenCode:                                                 │
│      background-task(prompt=protocol, signals)                │
│                                                             │
│  Phase 3: 渲染报告 (共享)                                      │
│    record-finding.py + render-report.py → report.md           │
└─────────────────────────────────────────────────────────────┘
```

### 3.3 Worker 协议定义位置

Worker 的 5 步检视协议（W1-W5）定义在 **command 文件自身**中，不放在 skill 中，也不放在单独的角色文件中：

- `commands/claude/secguard.md §5.2` — 现有，不变
- `commands/opencode/secguard.md §5.2` — 协议内容相同，但使用 `background-task` 原语
- `commands/gemini/...` — 按 Gemini 的原语调整

规则文件引用通过 `$SECGUARDIAN_HOME` 环境变量：

```bash
cat "$SECGUARDIAN_HOME/skills/secguard-java/rules/{skill}/rule.md"
```

两平台共享同一路径。

### 3.4 Worker 输出格式一致

两平台 Worker 使用完全相同的 `record-finding.py` 录制 finding，盲区格式一致。Phase 3 渲染层无差异。

---

## 4. 跨命令一致

### secguard

| | Claude Code | OpenCode |
|--|-------------|----------|
| Worker 原语 | Agent 工具 | `background-task(prompt=..., signals=...)` |
| Worker 数量 | 信号数 / BATCH_SIZE(50) | 同上 |
| 并发控制 | Agent 自动管理 | 上限 5，`background-output(block=true)` |
| rule.md 引用 | bash cat | bash cat |

### secreview

secreview 目前的工作流不同——它没有信号派发 Worker 这一说，AI 直接全面审阅代码。但未来如果 secreview 也走向信号驱动的 Worker 隔离，模式相同。

### secaudit

同 secreview。

**当前做**：先适配 `/secguard`，因为它的 Worker 隔离需求最明确、最紧急。
**未来扩展**：secreview/secaudit 如需 Worker 隔离，套用同一范式。

---

## 5. 开发工作流

### 5.1 开发锚定：Claude Code 优先

每次修改 command 文件时，**锚定 Claude Code 开发**，OpenCode 版本派生适配。

```
Step 1: 修改 commands/claude/secguard.md     ← 第一手修改
Step 2: 对应的 commands/opencode/secguard.md   ← 复制 Claude 版完成后，翻译 Phase 2
Step 3: Gemini .toml（如需要）                 ← 可选的，手动更新
Step 4: verify-commands.sh 跑一遍             ← 静态验证两平台一致性
```

理由：
- Claude Code 是主开发平台，Agent 工具协议成熟稳定
- Phase 1（索引）和 Phase 3（渲染）跨平台完全一致，只差 Phase 2 的 Worker 调度工具名
- OpenCode 翻译工作量为：Phase 2 中 `Agent` → `background-task`，其余复制不动

### 5.2 `sync-toml.sh` 处置

**结论：sync-toml.sh 在平台拆分后废弃。**

当前 sync-toml.sh 依赖根目录 `commands/*.md` 作为单一来源。平台拆分后：
- 根目录 .md 不再存在（迁移到 `commands/claude/`）
- sync-toml.sh 需改为读取 `commands/claude/` — 但用户反感 .toml 格式，不值得维护一个大家都不喜欢的自动生成链路
- Gemini 是最少使用的平台，`commands/gemini/*.toml` 保留为**静态文件**，protocol 有大变更时才手动更新

`package.sh` 第 29-30 行的 `sync-toml.sh` 调用移除。

### 5.3 开发约束

| 规则 | 说明 |
|------|------|
| 所有新增命令功能先在 `commands/claude/` 实现 | 单一方向开发流 |
| Phase 1/3 内容跨平台必须一致 | `commands/opencode/` 中的索引和渲染步骤不得修改 |
| Phase 2 是唯一允许差异的部分 | Worker 调度工具名 + 并发控制策略 |
| `commands/gemini/*.toml` 不要求与 .md 完全同步 | 已知落后可接受 |

---

## 6. 实施计划

### Phase 1: 命令文件平台分离

| Step | 动作 | 说明 |
|------|------|------|
| 1.1 | 创建 `commands/claude/` | 从 `commands/*.md` 迁移，内容不变 |
| 1.2 | 创建 `commands/opencode/secguard.md` | 复制 claude 版，Phase 2 用 background-task |
| 1.3 | 创建 `commands/opencode/secreview.md` | 同上 |
| 1.4 | 创建 `commands/opencode/secaudit.md` | 同上 |
| 1.5 | 创建 `commands/opencode/secfix.md` | 同上 |
| 1.6 | 移除 `package.sh` 中 `sync-toml.sh` 调用 | 自动生成 .toml 废弃 |
| 1.7 | 删除根目录 `commands/*.md` | 已迁移到 `commands/claude/` |

### Phase 2: deploy/package 脚本适配

| Step | 文件 | 修改 |
|------|------|------|
| 2.1 | `scripts/package.sh` | 命令复制逻辑: `commands/claude/*.md` → dist claude 包 |
| 2.2 | `scripts/deploy.sh` | deploy_claude(): 源改为 `commands/claude/` |
| 2.3 | `scripts/deploy.sh` | deploy_opencode(): 源改为 `commands/opencode/` |
| 2.4 | `scripts/release.sh` | 打包命令复制逻辑同步 |

### Phase 3: 创建 verify-commands.sh 验证脚本

| Step | 文件 | 说明 |
|------|------|------|
| 3.1 | `scripts/verify-commands.sh` | 跨平台命令文件一致性验证 |

详见 §7 验证方案。

### Phase 4: 清理 + 文档

| Step | 动作 |
|------|------|
| 4.1 | 删除 `commands/secguard.md` 等根目录 .md 文件 |
| 4.2 | 更新文档（CLAUDE.md、AGENTS.md 等）中的路径引用 |
| 4.3 | 更新 `release.sh` 中的命令复制路径 |

---

## 7. 验证方案

### 7.1 L1: 构建时静态检查（`scripts/verify-commands.sh`）

每次 `bash scripts/package.sh` 后自动运行（或作为 CI 检查）。

**检查 1 — 文件完备性**

`commands/claude/` 和 `commands/opencode/` 有相同名称的命令文件集：

```bash
# 检查两平台命令文件是否一一对应
diff <(ls commands/claude/ | sed 's/\.md$//' | sort) \
     <(ls commands/opencode/ | sed 's/\.md$//' | sort)
```

**检查 2 — 禁用词检查**

```bash
# opencode/ 文件不得出现 Agent 工具名
grep -rn 'Agent(' commands/opencode/ && fail "OpenCode 文件引用了 Agent 工具"

# claude/ 文件不得出现 background-task
grep -rn 'background-task' commands/claude/ && fail "Claude 文件引用了 background-task"
```

**检查 3 — Phase 1/3 一致性**

从 claude 和 opencode 版本中提取 Phase 1 和 Phase 3 的核心步骤，检查是否一致。方法：对两文件分别提取索引步骤和渲染步骤的 shell 命令序列，diff 对比。

```bash
# 提取 Phase 1 的 bash 命令签名
extract_phase() {
  local file=$1 phase=$2
  sed -n "/## Phase ${phase}/,/^## /p" "$file" | grep -E '^\$\$'  ...
}
```

如果 Phase 1/3 不一致 → 构建失败，要求开发者同步。

**检查 4 — 部署文件完整性**

模拟三平台部署，检查各目标目录是否有完整的命令文件集。

### 7.2 L2: 部署验证（`deploy.sh --verify`）

已有 `--verify` 参数。补充验证：

```bash
# 检查部署后的命令文件工具名正确
grep -q 'Agent' ~/.claude/plugins/secguardian/commands/secguard.md || fail
grep -q 'background-task' ~/.config/opencode/extensions/secguardian/commands/secguard.md || fail
```

### 7.3 L3: 端到端集成验证

在已知 demo 项目上执行 `/secguard`，验证 Worker 正常启动：

**Claude Code 验证**：运行 `/secguard ./examples/java-vuln-demo/src java`，检查扫描日志：
- 出现 `Agent` tool call，数量 >= 有信号的 skill 数
- 每个 Worker 的 tool call 序列独立（不交叉）

**OpenCode 验证**：运行 `/secguard ./examples/java-vuln-demo/src java`，检查扫描日志：
- 出现 `background-task` tool call，数量 >= 有信号的 skill 数
- 每个 Worker 的 `prompt` 内容完整（包含完整的 W1-W5 协议）
- 存在 `background-output(block=true)` 调用

**离线验证**：扫描完成后，检查 `workers/` 目录结构：
```
.codeagent/secguardian/secguard/scans/<scan-id>/workers/
├── log_injection/batch-00/blindspot.json          ← 存在
├── deserialization/batch-00/blindspot.json         ← 存在
├── command_injection/batch-00/blindspot.json       ← 存在
└── xxe/batch-00/blindspot.json                     ← 存在
```

空的 blindspot.json 也是预期产出（`all_suppressed`），确认 Worker 确实被调度且执行完毕。

### 7.4 L4: 回归测试

| 场景 | 预期 |
|------|------|
| Claude Code 全量扫描 | Worker 通过 Agent 工具并发执行，finding 数与基线一致 |
| OpenCode 全量扫描 | Worker 通过 background-task 独立执行，finding 数与 Claude Code 差集为 0 |
| Git diff 增量扫描 | 同全量扫描的 Worker 调度逻辑，只信号量减少 |
| 单 Worker 模拟超时 | 其他 Worker 正常完成，不影响最终 report |
| `package.sh` 构建 | 三平台命令文件正确分离到各自 dist 输出 |

### 7.5 验收标准

此 SDD 完成的定义：

- [ ] verification L1 通过（静态检查全部绿色）
- [ ] verification L2 通过（deploy --verify 正常）
- [ ] `commands/claude/` 与 `commands/opencode/` 文件一一对应
- [ ] OpenCode 扫描日志中出现 `background-task` 调用（手动确认一次）
- [ ] Claude Code 扫描回归 0 故障
- [ ] 根目录 `commands/*.md` 已清理
- [ ] `sync-toml.sh` 调用已移除

---

## 8. ADR

### ADR-001: Skill 保持平台中立

**日期**: 2026-07-09
**状态**: ✅ Accepted

#### Decision

SKILL.md 和 rule.md 不出现任何平台相关字段。Worker 的调度方式、工具选择完全由 command 文件决定。

#### Reason

Skill 是检测知识，平台是实现细节。让 SKILL.md 感知平台会污染知识文件的长期价值 —— 平台会过时，知识不会。

#### Consequences

- 正面: skill 跨平台复用，无维护负担
- 正面: 新增平台时只需改 command 文件
- 负面: 无（这只是在重申已有设计原则）

---

### ADR-002: Command 全权调度 Worker，不引入 agents/ 层

**日期**: 2026-07-09
**状态**: ✅ Accepted

#### Decision

Command 文件直接包含 Worker 协议，通过 `background-task(prompt=...)` 内联传递，不需要预注册角色文件。

#### Reason

1. OpenCode 的 `background-task` 接受 `prompt` 字段直接传递完整指令，角色文件是不必要的中间层
2. 不引入新概念（agents/）降低认知负担
3. Worker 协议已在 command 文件中定义（secguard.md §5.2），不复制即不冗余
4. 业界也没有 skill 衍生 agents 角色的常见做法——skill 应该保持纯知识

#### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| `agents/` 目录 + 预注册角色文件 | 不必要的中间层，`background-task` 接受 inline prompt，不需要预注册 |
| Worker 协议下沉到 SKILL.md | skill 感知平台差异，违反 ADR-001 |
| 单 command 文件做运行时平台探测 | 部署时已知平台，不需运行时判断。代码复杂度上升 |

#### Consequences

- 正面: 无新增概念，架构简单
- 正面: Worker 隔离的实现成本极低（~5 行改动到 Phase 2）
- 正面: `agents/` 目录的免除避免了未来维护此目录的负担

---

### ADR-003: 开发锚定 Claude Code

**日期**: 2026-07-09
**状态**: ✅ Accepted

#### Decision

所有 command 文件修改以 `commands/claude/` 版本为第一手修改目标。OpenCode 版本派生适配，只改 Phase 2 的 Worker 调度原语。

#### Reason

1. Claude Code 是主开发平台，Agent 工具协议成熟稳定
2. Phase 1/3 跨平台完全一致，只差 Phase 2 的工具名。锚定一个平台减少心智负担
3. 两版本同步由 `verify-commands.sh` 的 Phase 1/3 一致性检查保障

#### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| 锚定 OpenCode | Worker 隔离需求来自 OpenCode，应该锚定有问题的平台 | 隔离是平台能力差异，不是 OpenCode 的 feature。协议设计在 Claude Code 上更清晰 |
| 无锚定，改哪边算哪边 | 两版本最终必然 drift，Phase 1/3 不一致导致 scan 行为差异 |

#### Consequences

- 正面: 开发流程清晰，心智负担低
- 正面: verify-commands.sh 能自动捕获同步遗漏
- 负面: OpenCode 的 Phase 2 翻译由开发者手动完成（但工作量极小——工具名替换 + 并发控制调整）

---

### ADR-004: 废弃 `sync-toml.sh`

**日期**: 2026-07-09
**状态**: ✅ Accepted

#### Decision

`sync-toml.sh` 在平台拆分后废弃。`commands/gemini/*.toml` 保留为静态文件，不再自动生成。

#### Reason

1. `sync-toml.sh` 依赖根目录 `commands/*.md` 作为单一来源——拆分后根目录不再存在
2. 用户明确不喜好 .toml 格式，不值得维护一条用户不喜欢、目标平台少用的自动生成链路
3. Gemini 是最少使用的平台，手动维护 .toml 的成本远低于维护自动生成脚本的成本
4. 如果 Gemini 使用量上升，届时有真实需求时再恢复自动生成也不迟

#### Rejected Alternatives

| 方案 | 否决原因 |
|------|---------|
| `sync-toml.sh` 改为读取 `commands/claude/` | 自动生成一个用户不喜欢的格式，维护负价值 |
| 移除 Gemini 支持 | 过激。不主动投入但不主动放弃 |

#### Consequences

- 正面: 少维护一个脚本，少一条自动生成链路
- 正面: `package.sh` 简化（移除第 29-30 行的 sync-toml.sh 调用）
- 正面: .toml 手动更新 = 开发者实际触碰了 Gemini 版本，反而会更谨慎
- 负面: .toml 版本可能偶尔落后于 .md 版本（已知可接受）

---

## 9. Scope

### 做

- `commands/claude/` + `commands/opencode/` 四命令平台分离
- `commands/opencode/secguard.md` 使用 `background-task` 实现 Worker 隔离
- `scripts/verify-commands.sh` 跨平台一致性的静态检查
- deploy.sh / package.sh 适配（命令复制源路径变更）
- `package.sh` 中 `sync-toml.sh` 调用移除
- 根目录 `commands/*.md` 清理

### 不做

- `agents/` 目录
- `skills/` 的任何改动
- OpenCode 插件 JS 层改动
- Gemini 命令文件重写（已有 .toml 格式）
- secreview/secaudit 的 Worker 隔离（先做 secguard，范式一致后按需扩展）
- 编写 `sync-toml.sh` 的新版本

---

## 10. Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| OpenCode `background-task` 的 `prompt` 字段有长度限制 | 长 Worker 协议被截断 | 实测验证，必要时用 `prompt` + `description` 拆分 |
| LLM 在 OpenCode 上不主动使用 `background-task` | 降级到附录 C | 命令文件提供显式步骤指令 + 示例代码 |
| 现有 `commands/*.md` 的链接/引用被遗漏 | 部署脚本错误 | 一次性迁移 + grep 扫描所有引用 |
