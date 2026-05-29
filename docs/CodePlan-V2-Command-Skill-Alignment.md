# CodePlan V2: Command-Skill 对齐与 Agent 执行优化

> Status: **Proposed for Review**
> Based on: session-ses_189e.md 验证发现
> Focus: 修复 Command 与 Skill 的步骤分歧、强制索引器调用、消除冗余输出

---

## 1. 问题发现 (Root Cause Analysis)

### 致命问题: 索引器从未被执行

验证会话 `ses_189e` 中，Agent 完成了扫描但**完全跳过了 `secguardian-index`**。

**根因**: Command 和 Skill 的执行步骤存在**两套指令冲突**：

| 来源 | Step 2 内容 |
|------|-------------|
| `commands/secguard.md` | "调用代码索引器构建 Tree-sitter 语义索引" — 找到 wrapper，执行，读取 index.json |
| `skills/secguard-cpp/SKILL.md` | "确定扫描范围" — 列出文件，全量/增量模式判断 |

Agent 加载了 Skill 后，Skill 的 Step 列表覆盖了 Command 的步骤。Skill 从未提及索引器，所以 Agent 直接跳到了手工逐文件分析。

### 次生问题清单

| # | 问题 | 严重度 | 证据 (session) |
|---|------|--------|---------------|
| **P1** | Command/Skill 步骤冲突，索引器被跳过 | 🔴 Critical | Agent 未执行任何 `secguardian-index` 命令 |
| **P2** | Skill SKILL.md 缺失索引器调用步骤 | 🔴 Critical | Skill 的 Step 1→7 流程无 indexer |
| **P3** | Agent 消耗大量 token 逐文件读取 8 个源文件 | 🟡 High | 共 read 8 次 × 100+ 行，~5000 token |
| **P4** | Agent 重写了整个 detector-index.md (255行) | 🟡 High | 为修复一行重复条目，write_file 整个文件 |
| **P5** | `duration_ms: 980` 明显是编造的（实际 ~160s） | 🟡 Medium | manifest.json 中 duration_ms 虚报 |
| **P6** | 无 `index.json` 导致丢掉跨文件分析能力 | 🟡 Medium | alloc/free 配对、调用链追踪完全缺失 |
| **P7** | 扫描摘要输出格式可读性差 | 🟢 Low | 35 条 finding 仅列 Top 5，无 namespace 分组 |
| **P8** | 使用了 DeepSeek V4 Flash (小模型) 而非 Claude | 🟢 Info | 模型选择影响分析质量 |

---

## 2. 解决方案设计

### 核心原则

> **索引器是扫描的前置条件，不可可选、不可跳过。**

Command 中的索引器指令必须是**阻塞式**的——Agent 不执行索引器就不能继续。

### 方案 A: Command 中强化索引器指令（推荐，改动最小）

在 `commands/secguard.md`（及 `secaudit.md`、`secreview.md`）中，将 Step 2 改写为**带验证步骤的强制指令**：

```markdown
2. **调用代码索引器（必须执行，不可跳过）**：
   
   2a. 定位 wrapper：
       ```bash
       test -f .opencode/scripts/secguardian-index && INDEXER=.opencode/scripts/secguardian-index || \
       test -f .gemini/scripts/secguardian-index && INDEXER=.gemini/scripts/secguardian-index || \
       INDEXER=./scripts/secguardian-index
       ```
   
   2b. 执行索引（阻塞等待完成）：
       ```bash
       $INDEXER --path <path> --output <output_dir>/index.json
       ```
   
   2c. 验证索引完整性（必须通过）：
       ```bash
       python3 -c "
       import json; d=json.load(open('<output_dir>/index.json'))
       assert len(d.get('files',[])) > 0, 'NO_FILES'
       assert len(d.get('symbols',{}).get('functions',[])) > 0, 'NO_SYMBOLS'
       print(f'OK: {len(d[\"files\"])} files, {len(d[\"symbols\"][\"functions\"])} functions')
       "
       ```
       若验证失败，报告错误并**终止扫描**。
   
   2d. 将 index.json 加载为上下文（保持在整个扫描过程中）。
```

### 方案 B: Skill SKILL.md 中注入索引器步骤

在三个 secguard-* skill 的 SKILL.md 中，将 Step 2 替换为索引器调用步骤，与 Command 保持一致。涉及的 Skill：
- `skills/secguard-cpp/SKILL.md`
- `skills/secguard-java/SKILL.md`
- `skills/secguard-python/SKILL.md`
- `skills/secguard-go/SKILL.md`

### 方案 C: Command 中嵌入 "前置检查" 检查清单

在命令开头添加一个 **前置检查块**，Agent 必须先逐项打勾才能进入扫描：

```markdown
## 前置检查 (Pre-flight Checklist)

在执行扫描前，必须确认以下每一项：

- [ ] `.opencode/scripts/secguardian-index` 或 `.gemini/scripts/secguardian-index` 存在且可执行
- [ ] 索引器 `--health` 检查通过
- [ ] `index.json` 已生成且通过完整性验证
- [ ] 已读取 `index.json` 并理解其结构

**以上任意一项未通过，扫描不得开始。向用户报告具体错误。**
```

---

## 3. 本次执行建议

**采用方案 A + C 组合（改动最小，效果最强）**：

| 步骤 | 文件 | 改动 |
|------|------|------|
| 1 | `commands/secguard.md` | Step 2 重写为强制索引器指令 + 验证步骤 + 前置检查清单 |
| 2 | `commands/secaudit.md` | 同上 |
| 3 | `commands/secreview.md` | 同上 |
| 4 | `skills/secguard-cpp/SKILL.md` | Step 2 从"确定扫描范围"改为"调用索引器 + 加载 index.json"，原 Step 2 内容合并到 Step 3 |
| 5 | `skills/secguard-java/SKILL.md` | 同上 |
| 6 | `skills/secguard-python/SKILL.md` | 同上 |
| 7 | `skills/secguard-go/SKILL.md` | 同上 |

### 不改动的部分

| 项目 | 原因 |
|------|------|
| 其他 21 个 secaudit/secreview skill | secaudit/secreview 的 SKILL.md 有各自不同的 Step 流程，由 Command 层面的索引器指令统一覆盖 |
| `knowledge/detectors/*.md` | 检测逻辑保持不变 |
| 构建/部署脚本 | V1 重构已完成，本次仅修复 prompt 层面 |

---

## 4. 预期效果

修改后，Agent 执行 `/secguard` 时的链路变为：

```
1. 加载 command → 读取前置检查清单
2. 定位 secguardian-index wrapper → 执行 --health
3. 执行索引: --path <path> --output <output_dir>/index.json
4. 验证 index.json 完整性 (files > 0, symbols.functions > 0)
5. 读取 index.json 加载为上下文
6. 加载 skill → 按 detector namespace 过滤匹配
7. 基于 index.json 的符号表 + 调用图执行检测器
8. 生成 findings + manifest.json
9. 输出摘要
```

**关键变化**: Step 3 从"可选"变为"强制且不可跳过"。如果索引器不可用，Agent 应该**报错终止**而非降级为手工扫描。

---

## 5. 验证计划

1. 执行 `bash scripts/dev-deploy.sh` 部署最新变更
2. 启动 OpenCode，执行 `/secguard examples/cpp-vuln-demo/src/ memory.*`
3. 检查 Agent 是否：
   - ✅ 执行了 `secguardian-index --health`
   - ✅ 执行了 `secguardian-index --path ... --output .../index.json`
   - ✅ 读取了 `index.json` 内容
   - ✅ 在分析中引用了 index 中的符号/调用图信息
4. 对比修改前后的 token 消耗（应显著减少，因为不再逐文件 read）

---

## 6. 后续优化（不在本次范围内）

| 优化项 | 优先级 | 说明 |
|--------|--------|------|
| Skill SKILL.md 中的示例数据更新 | P2 | 当前 Step 1/6 中的示例 scan_id 格式、行号与实际不一致 |
| `detector-index.md` 中移除重复条目 #45 | P3 | open-redirect 在 #36 和 #45 重复出现 |
| `duration_ms` 自动计算 | P3 | 在 command 中指示 Agent 用 wall-clock 计算而非编造 |
| SARIF 输出验证 | P3 | 当前仅生成 manifest+findings，SARIF 未触发 |
| 增量扫描 (git diff) 端到端验证 | P3 | 全量扫描已跑通，增量模式尚未测试 |
