# FEATURE-001: Signal Extraction Dispatcher — 实施计划

> **目标**: 将 9 个命令文件（3 命令 × 3 平台）的 Dispatcher 从"分派 Skill"重写为"输出 Signal + 上下文"
> **方法**: 先改闭包平台（OpenCode）的 secguard 作为样板，验证后同步到其他平台和命令
> **不涉及**: Go 代码、Rule 文件、Skill 文件（这些是 FEATURE-002/003 的范畴）

---

## 1. 架构概览（变更前后）

### 变更前

```
Commands (secguard.md) — 约 5 步执行管线
  Step 1: 索引器 health + 路径验证
  Step 2: 建立索引（--path --output）
  Step 3: 读 index.json → 分派 Skill（buffer_overflow, null_dereference...）
  Step 4: Worker 执行（W1-W5 逐 Rule 验证）
  Step 5: 渲染
```

### 变更后

```
Commands (secguard.md) — 精简为 3 步 Dispatcher
  Phase 1: 索引器 health + 路径验证（不变）
  Phase 2: 建立索引 + 信号提取（读取 index.json → 分类 → 添加上下文）
  Phase 3: 输出 Signal Summary → 移交 Investigation Pipeline

Skills (SKILL.md) — 接管第 4-5 步
  Phase 4: Hypothesis Generator（3-5 假设/信号）
  Phase 5: Investigator + Evidence + Counter Evidence
  Phase 6: Judge → Finding
  Phase 7: 渲染
```

---

## 2. 文件变更清单

| 文件 | 改动量 | 改动内容 |
|------|--------|---------|
| `commands/opencode/secguard.md` | ~50 行 | 样板：Dispatcher 重构 + Signal Extraction |
| `commands/opencode/secaudit.md` | ~40 行 | 按样板同步 |
| `commands/opencode/secreview.md` | ~40 行 | 按样板同步 |
| `commands/claude/secguard.md` | ~50 行 | 同上，Claude 命名空间调整 |
| `commands/claude/secaudit.md` | ~40 行 | 同上 |
| `commands/claude/secreview.md` | ~40 行 | 同上 |
| `commands/gemini/secguard.toml` | ~50 行 | 同上，TOML 格式 |
| `commands/gemini/secaudit.toml` | ~40 行 | 同上 |
| `commands/gemini/secreview.toml` | ~40 行 | 同上 |
| `knowledge/protocols/scan-output.md` | ~20 行 | Signal schema 更新 |

---

## 3. Tasks

### Task T1: 读取 OpenCode secguard.md 当前结构

读取当前 `commands/opencode/secguard.md` 的完整内容，理解五步执行管线的细节。

**依赖**: 无
**验证**: 确认已理解 Dispatcher、Worker、renderer 三段代码的位置

### Task T2: 重构 OpenCode secguard.md Dispatcher

将 Step 1（前置检查 + 索引构建）保留，Step 2-3（Skill 分派）重写为 Signal Extraction。

**改动内容**:

1. 删除以下内容：
   - Skill 选择逻辑（"你的任务是按检测器类型分派给对应 skill"）
   - category 相关的判断（"如果是 memory 类别..."）
   - safe_variant 判定（"如果 safe_variant 为 true 则直接 suppress"）
   - 限制调查方向的语言（"你只需要关注以下检测器: buffer_overflow, null_dereference"）

2. 新增以下内容：
   - Signal 数据结构定义（REQ-001 的新 schema）
   - Signal Type 映射（memory_allocation, memory_copy 等）
   - 上下文人步骤（从源码文件中读取每信号 ±3 行）
   - 错误/正确示例（REQ-004）
   - "Dispatcher 禁止"条款（REQ-002, REQ-003）
   - Pipeline 移交声明（"Dispatcher 完成，以下是 Hypothesis Generator 的职责"）

3. 保留：
   - 索引器 health 检查
   - `--path`、`--output`、`--lang` 参数
   - 渲染输出步骤

**验证**: `git diff commands/opencode/secguard.md` 确认 Dispatcher 部分重写

### Task T3: 同步到 OpenCode secaudit.md + secreview.md

按 secguard 样板重写 secaudit.md 和 secreview.md 的 Dispatcher 部分。

**差异说明**:
- secaudit: 输出全量 Signal（不过滤），Hypothesis 深度更高（5-7 假设而非 3-5）
- secreview: Signal 聚焦 PR 变更的范围（在 Phase 2 筛选）

**验证**: 三文件 Dispatcher 部分的 diff 一致（只有 Signal 数量和深度参数不同）

### Task T4: 同步到 Claude 平台三文件

将 OpenCode 的三份命令文件翻译到 Claude 命名空间。

**差异**: 路径前缀、工具名、settings 配置位置不同。Dispatcher 逻辑完全一致。

**验证**: `diff commands/opencode/secguard.md commands/claude/secguard.md` 只显示路径差异

### Task T5: 同步到 Gemini 平台三文件（TOML 格式）

将 OpenCode 的三份命令文件转换为 Gemini 的 TOML 格式。

**差异**: 格式不同（TOML vs Markdown），Dispatcher 逻辑完全一致。

**验证**: `grep -c "Signal Extraction\|Hypothesis Generator\|Dispatcher 禁止" commands/gemini/secguard.toml` ≥ 3 处

### Task T6: 更新 Signal Schema 协议文档

在 `knowledge/protocols/scan-output.md` 中更新 Signal 的定义。

**改动**: 添加新 Signal schema（REQ-001），标记旧 schema 为 deprecated

**验证**: `grep -c "signal_id\|type.*memory_allocation" knowledge/protocols/scan-output.md` ≥ 2

### Task T7: 自检 + 端到端验证

```bash
# 1. 自检
bash scripts/self-check.sh

# 2. 验证 Dispatcher 不再包含 category 判断
grep -n "category\|skill.*分派\|检测器类型" commands/opencode/secguard.md
# 期望: 0 匹配（或只在协议引用中出现）

# 3. 验证 Dispatcher 包含 Signal 输出
grep -n "Signal Summary\|Signal Type\|Hypothesis Generator" commands/opencode/secguard.md
# 期望: ≥ 5 处匹配

# 4. 验证跨平台一致性
diff <(grep -c "Dispatcher" commands/opencode/secguard.md) <(grep -c "Dispatcher" commands/claude/secguard.md)
# 期望: 数值一致（或接近）
```

**验证**: 全部 4 项检查通过

---

## 4. 任务执行顺序

```
T1 (read) ──→ T2 (secguard) ──→ T3 (secaudit + secreview)
                                      │
                                      ▼
                              T4 (Claude × 3) ──→ T5 (Gemini × 3)
                                                          │
                                                          ▼
                                                  T6 (protocol) ──→ T7 (verify)
```

T1 是分析任务，不产生代码变更。
T2 是最关键的任务——样板做得对，后面都是机械同步。
T3-T5 可以并行（OpenCode 的 secaudit/secreview + Claude 三文件 + Gemini 三文件）。

---

## 5. 回滚策略

如果 Dispatcher 重构后扫描失败：
1. `git checkout HEAD~1 commands/opencode/secguard.md` 恢复单文件
2. 按需恢复其他文件
3. 运行 `bash scripts/deploy.sh all` 重新部署

Dispatcher 重构是纯 Prompt 变更，不涉及 Go 编译，回滚风险极低。
