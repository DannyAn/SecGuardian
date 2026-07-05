# TASK-008: Inject Anchor + Pre-Filter Constraints into commands/secguard.md

> **Feature**: FEATURE-005 | **来源**: CHANGE-001
> **文件**: `commands/secguard.md`
> **改动量**: ~20 行

## 目标

将架构文档中的锚定约束和预筛收紧注入到实际 prompt 指令中。

## 具体修改

### 修改 1: Step 2.5b 收紧预筛

当前文本：
```
> **关键约束**：此步骤构建的映射**仅用于加速执行**，不跳过任何已确定的检测器。
> 即使某检测器在 index.json 中无直接匹配，AI 仍需执行它。
```

改为：
```
> **关键约束**：此步骤构建的映射用于加速执行和信号预筛。
> 当检测器在 index.json 中无直接信号匹配时，可以执行但 **MUST** 标记 `confidence: low`
> 并在 `judgment_rationale` 中说明"无 index 信号支撑，基于 LLM 语义分析"。
```

### 修改 2: Step 4 开头增加锚定校验

在 "Step 4: 输出结构化 findings" 标题后，第一个段落前插入：

```markdown
**🔗 锚定约束 (Anchor Rule — 参见 internal/engine/engine_contract.md Rule A):**

每个 finding 必须满足：
1. `file` + `line` 在 index.json 的 `files` 列表和 `symbols` 中存在对应条目
2. 调用 `record-finding.py` 时必须提供 `--snippet`（代码片段）、`--code-context`（上下文）、`--rationale`（判断依据）
3. 如果 file+line 在 index 中无匹配，标记 `confidence: low` 并解释原因
```

### 修改 3: Step 4 的 record-finding.py 示例增强

在 `record-finding.py` 调用示例中增加必填参数：

```bash
python3 "$RECORDER" \
    --command secguard \
    --scan-dir .codeagent/secguardian/secguard/scans/<scan_id> \
    --detector <namespace.name> \
    --severity Critical --cwe CWE-89 \
    --file src/UserController.java --line 52 \
    --snippet "<vulnerable code line>" \
    --code-context "<surrounding function context>" \
    --rationale "<why this matches the detector rule>" \
    --attack-scenario "<how an attacker exploits this>" \
    --fix-before "<bad_code>" --fix-after "<good_code>"
```

## 验证

```bash
grep -c "锚定约束\|Anchor Rule" commands/secguard.md  # 期望: >= 1
grep -c "confidence: low" commands/secguard.md  # 期望: >= 1
grep -c -- "--snippet.*--code-context.*--rationale" commands/secguard.md  # 期望: >= 1
```
