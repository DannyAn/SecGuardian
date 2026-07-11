# CHANGE-006: Inline Script Elimination & Task Prompt Standardization

> **Date**: 2026-07-11
> **Status**: Implemented
> **驱动**: OpenCode session `ses_0aea` 暴露 3 类系统性问题：
> 1. 12 个 `python3 -c "..."` 内联脚本 → Windows 不兼容、不可维护
> 2. 20 个 Task prompt 格式不一致 → 39/46 findings needs_review
> 3. 主 dispatcher 重复实现已有脚本逻辑 → 上下文浪费

---

## 一、测试暴露的事实

### 1.1 内联 Python 脚本 (12 处)

```
Line 1076: python3 -c "import os; print(os.path.abspath(...))"     # 路径解析（init-scan.sh 内部）
Line 1101: python3 -c "import json; d=json.load(open(...))"        # 缓存检查（init-scan.sh 内部）
Line 3036: python3 -c "import json\n...read partition-plan..."      # 读完整 plan（违反约束）
Line 3283: python3 -c "import json\n...print schedule..."            # 读完整 plan（违反约束）
Line 5374: python3 -c "import json\n...count assignments..."         # 重新实现 partition-signals
Line 5607: python3 -c "import json, os\n...scan verdicts..."         # 重新实现 gate 逻辑
```

**Windows 影响**：`python3 -c "code\nwith\nnewlines"` 在 cmd.exe 中换行符处理完全不同；PowerShell 中引号转义规则不同。这些内联脚本在 Windows 必然失败。

### 1.2 Task Prompt 结构不一致 (5 种变体)

```
injection.command_injection:  包含 signal 详情 + JUDGE_VERDICT_SCHEMA   ← 最佳
memory.buffer_overflow:       包含 signal 详情，无 schema                  ← 缺格式约束
memory.null:                  无 signal 详情，要求 "read partition-plan"  ← 迫使 Agent 读 plan
memory.leak:                  简化为一行描述                               ← 信息不足
crypto.hardcoded/batch-002:   batch 合并式 Task                          ← 违反 CHANGE-005
```

**后果**：20 个 Task Agent 收到不同格式的指令 → 产出 20 种不同的 JSON 格式 → 39/46 needs_review。

### 1.3 RECORDER 路径硬编码

每个 Task prompt 中 `RECORDER` 是绝对路径，不是 `$SCRIPTS_DIR/record-finding.py`。如果部署路径变化，所有 Task 失败。

---

## 二、根因

| # | 根因 | 表现 |
|---|------|------|
| 1 | 模板允许 LLM 自行生成 bash 命令 | 内联 `python3 -c` 替代已有脚本 |
| 2 | Task prompt 由 dispatcher LLM 现场捏造 | 20 种不同 prompt 结构 |
| 3 | 已有脚本功能完备但未被引用 | `partition-signals.py` 有 `--self-test` 但 dispatcher 不用它的 summary 输出 |
| 4 | 没有机器可消费的 Task prompt 生成器 | dispatcher 用人脑生成 prompt → 不可复现 |

---

## 三、修复方案

### 3.1 新增 3 个固化脚本（替代所有内联 python3 -c）

| 脚本 | 替代的内联模式 | 用途 |
|------|--------------|------|
| `scripts/compact-schedule.py` | `python3 -c "import json...print schedule"` | 读 partition-plan → 输出 compact schedule 文本/JSON |
| `scripts/gen-task-prompts.py` | dispatcher LLM 现场捏 prompt | 读 partition-plan → 输出标准化 Task prompt（含完整 JSON schema） |
| `scripts/scan-verdicts.py` | `python3 -c "import json, os...scan verdicts"` | 扫描所有 judge_verdict.json → 输出汇总（confirmed/suppressed/unknown） |

**设计原则**：
- 所有脚本只接受 `--self-test` 和 JSON 输入，不接 shell 变量
- 输出默认 text（给 LLM 读），`--json` 输出 JSON（给机器消费）
- 跨平台：只用 `os.path.join` 等标准库，不依赖 shell 特性

### 3.2 模板中删除所有内联 python3 -c

`commands/opencode/secguard.md` 中的以下块全部替换为脚本调用：

| 原内联调用 | 替换为 |
|-----------|--------|
| `python3 -c "import json...partition-plan..."` (compact schedule) | `python3 "$SCRIPTS_DIR/compact-schedule.py" --plan "$SCAN_DIR/partition-plan.json"` |
| dispatcher 手写 Task prompt | `python3 "$SCRIPTS_DIR/gen-task-prompts.py" --plan ... --project ... --json` → 消费 JSON 输出 |
| `python3 -c "import json, os...scan verdicts..."` (Phase 3) | `python3 "$SCRIPTS_DIR/scan-verdicts.py" --scan-dir "$SCAN_DIR/"` |
| `python3 -c "import json...count assignments..."` (Phase 3) | `python3 "$SCRIPTS_DIR/partition-signals.py" --summary --plan ...` |

### 3.3 Phase 3 管道验证脚本化

`commands/opencode/secguard.md` 中 Phase 3 的三段内联 python3 -c 全部替换为：

```bash
python3 "$SCRIPTS_DIR/scan-verdicts.py" --scan-dir "$SCAN_DIR/"
```

不再在模板中嵌入业务逻辑代码。

### 3.4 RECORDER 路径标准化

Task prompt 中的 `RECORDER` 改为 `$SCRIPTS_DIR/record-finding.py`（通过 gen-task-prompts.py 的模板固定）。

---

## 四、TDD 验收

### TDD-C1: 所有内联 python3 -c 消除

```bash
grep -c 'python3 -c' commands/opencode/secguard.md
# 期望: 0（Phase 3 的 worker_manifest 生成除外，那是现有的固化 inline）
```

### TDD-C2: gen-task-prompts 自检

```bash
python3 scripts/gen-task-prompts.py --self-test
# 期望: OK - gen-task-prompts self-test passed
```

### TDD-C3: compact-schedule 自检

```bash
python3 scripts/compact-schedule.py --plan "$SCAN_DIR/partition-plan.json" | head -1
# 期望: 输出 "rule_id | batch_id | signal_count | rule_path" 格式的行
```

### TDD-C4: scan-verdicts 自检 + 真实数据

```bash
python3 scripts/scan-verdicts.py --self-test
# 期望: OK - scan-verdicts self-test passed

python3 scripts/scan-verdicts.py --scan-dir "$SCAN_DIR"
# 期望: 输出 confirmed/suppressed/unknown 统计
```

### TDD-C5: Task prompt 一致性

```bash
python3 scripts/gen-task-prompts.py --plan ... --json | python3 -c "
import json, sys
ps = json.load(sys.stdin)
# 验证每个 prompt 包含相同的关键段
for p in ps:
    assert 'CANONICAL ARTIFACT FORMATS' in p['prompt'], f'{p[\"rule_id\"]} missing schema'
    assert 'CRITICAL RULES' in p['prompt'], f'{p[\"rule_id\"]} missing rules'
    assert 'signal_id' in p['prompt'], f'{p[\"rule_id\"]} missing signal_id'
    assert 'Do NOT read complete source files' in p['prompt']
    assert 'Do NOT read partition-plan.json' in p['prompt']
print(f'OK - {len(ps)} prompts validated')
# 期望: OK - 20 prompts validated
```

---

## 五、部署

新脚本加入 `scripts/package.sh` 和 `scripts/deploy.sh` 的打包清单：

```bash
# package.sh 和 deploy.sh 中已有的脚本清单追加:
for wrapper in ... compact-schedule.py gen-task-prompts.py scan-verdicts.py; do
```

---

## 六、影响范围

| 文件 | 改动 |
|------|------|
| `scripts/compact-schedule.py` | 新增 |
| `scripts/gen-task-prompts.py` | 新增 |
| `scripts/scan-verdicts.py` | 新增 |
| `commands/opencode/secguard.md` | Phase 2 compact schedule 生成 + Phase 3 管道验证替换为脚本调用 |
| `commands/claude/secguard.md` | 同步更新 |
| `scripts/package.sh` | 追加新脚本到打包清单 |
| `scripts/deploy.sh` | 追加新脚本到部署清单 |
