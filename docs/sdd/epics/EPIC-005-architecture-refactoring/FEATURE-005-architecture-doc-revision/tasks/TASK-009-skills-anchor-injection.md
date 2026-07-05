# TASK-009: Inject Anchor + Evidence Constraints into Skills

> **Feature**: FEATURE-005 | **来源**: CHANGE-001
> **文件**: `skills/secguard/{cpp,go,java,python,js}/SKILL.md` (5 files)
> **改动量**: 每个文件 ~10 行

## 目标

在 5 个 secguard skill 文件中注入锚定约束和信号预筛规则。

## 具体修改

在每个 SKILL.md 的 `🎯 Detector Selection` 区域末尾，增加预筛规则：

```markdown
#### 📊 信号预筛 (Signal Pre-Filter — engine_contract.md Rule C)

基于 index.json 确定性信号的检测器触发规则：
- `symbols.functions` 含 `malloc`/`realloc` 无对应 `free` → 触发 memory-leak
- `symbols.functions` 含 `strcpy`/`sprintf`/`gets` → 触发 buffer-overflow
- `symbols.functions` 含 `system`/`exec`/`popen` → 触发 command-injection
- 无加密库函数符号 → 跳过 crypto-misuse 检测器
- 无 SQL 库函数符号 → 跳过 SQL-injection 检测器

无信号匹配时仍可执行检测器，但 MUST 标记 `confidence: low`。
```

在每个 SKILL.md 的 `⚙️ Engine Instructions` 区域开头，增加锚定约束：

```markdown
**🔗 锚定+证据约束 (engine_contract.md Rule A + Rule B):**
- 每个 finding 的 `file`+`line` MUST 可追溯到 index.json 的符号或文件列表
- 每个 finding MUST 包含 `--snippet`、`--code-context`、`--rationale`
- 无 index 锚点的 finding MUST 标记 `confidence: low`
```

## 验证

```bash
grep -l "Signal Pre-Filter\|信号预筛" skills/secguard/*/SKILL.md | wc -l  # 期望: 5
grep -l "锚定+证据\|Anchor.*Evidence\|engine_contract" skills/secguard/*/SKILL.md | wc -l  # 期望: 5
```
