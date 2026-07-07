# TASK-004: Update runtime-model.md

> **Feature**: FEATURE-005 Architecture Document Revision
> **文件**: `docs/architecture/runtime-model.md`
> **改动量**: 局部修改 ~15%

## 目标

在 §4 CI 验证层中增加"确定性预检流程"的具体描述。

## 具体修改

### §4 CI: Verification Constraint Layer

在现有内容后追加"确定性快速门禁"小节：

```markdown
### 4.1 确定性快速门禁 (Deterministic Fast Gate)

CI 可以在不调用 LLM 的情况下，利用确定性信号做快速门禁：

1. **锚定校验**: 扫描结果的每个 finding 是否都有 index 锚点？
   - 无锚点 finding 比例 > 阈值 → WARN（LLM 可能在推测）
2. **预筛匹配率**: index 预筛命中了多少 finding？
   - 匹配率 < 阈值 → 可能遗漏检测（LLM 跳过了 detector）
3. **去重检查**: 同一代码位置是否产生了多个重复 finding？

快速门禁不替代完整 LLM 扫描。它只做"卫生检查"——
确保扫描过程没有明显异常。完整的安全分析仍需 LLM。
```

### §5 Implications → Impact on Verification

更新验证关注点表，增加确定性信号相关验证项。

## 验证

```bash
# 包含快速门禁/确定性预检描述
grep -c "快速门禁\|fast gate\|确定性预检\|deterministic.*pre" docs/architecture/runtime-model.md  # 期望: >= 1

# 仍然不包含 consumption mode 语言（已有验证）
grep -c "consumption mode" docs/architecture/runtime-model.md  # 期望: 0
```
