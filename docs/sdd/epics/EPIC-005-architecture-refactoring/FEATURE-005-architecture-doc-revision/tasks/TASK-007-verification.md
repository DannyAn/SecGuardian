# TASK-007: Cross-Reference Verification + Self-Check

> **Feature**: FEATURE-005 Architecture Document Revision
> **类型**: Verification
> **依赖**: TASK-001~006 全部完成

## 目标

验证 6 份修正后的架构文档交叉引用一致、成功标准全部通过、不修改 production 代码。

## 验证步骤

### Step 1: Success Criteria Check

```bash
# SC-1: security-engine.md 不再包含 "LLM MAY NOT introduce" 绝对约束
grep -c "MAY NOT.*introduce" docs/architecture/security-engine.md
# 期望: 0

# SC-2: security-engine.md 包含信号层能力表和渐进演进路线
grep -c "信号层\|Signal Layer\|渐进\|progressive" docs/architecture/security-engine.md
# 期望: >= 3

# SC-3: engine_contract.md 不再定义 Engine API
grep -c "Engine receives\|Engine processes\|Engine emits" internal/engine/engine_contract.md
# 期望: 0

# SC-4: engine_contract.md 包含锚定约束和证据约束
grep -c "锚定\|anchor\|证据\|evidence" internal/engine/engine_contract.md
# 期望: >= 4

# SC-5: architecture-vNext.md Phase 2/3 不再提 "deterministic matcher"
grep -c "deterministic.*match\|deterministic.*engine" docs/architecture/architecture-vNext.md
# 期望: 0

# SC-6: architecture-vNext.md Phase 2 改为信号增强
grep -c "跨文件调用图\|cross-file call graph\|type.*hierarch\|类型.*继承" docs/architecture/architecture-vNext.md
# 期望: >= 1

# SC-7: runtime-model.md 包含 CI 确定性预检流程
grep -c "快速门禁\|fast gate\|确定性预检" docs/architecture/runtime-model.md
# 期望: >= 1

# SC-8: design-principles.md ADR-007 更新为协作模型
grep -c "Signal-LLM\|信号.*LLM" docs/architecture/design-principles.md
# 期望: >= 1

# SC-9: engineering-principles.md EP-1 提供替代方案
grep -c "Signal Anchoring\|信号锚定" docs/architecture/engineering-principles.md
# 期望: >= 1
```

### Step 2: Cross-Reference Integrity

```bash
# 检查所有架构文档间的交叉引用完整性
# 每个文档引用的其他文档路径应该存在

# architecture-vNext.md 引用的文档
grep -oP '\[.*?\]\(\./[^)]+\.md\)' docs/architecture/architecture-vNext.md | while read link; do
  target=$(echo "$link" | grep -oP '(?<=\(\./)[^)]+')
  [ -f "docs/architecture/$target" ] || echo "BROKEN: $target"
done

# security-engine.md 引用的文档
grep -oP '\[.*?\]\(\./[^)]+\.md\)' docs/architecture/security-engine.md | while read link; do
  target=$(echo "$link" | grep -oP '(?<=\(\./)[^)]+')
  [ -f "docs/architecture/$target" ] || echo "BROKEN: $target"
done

# runtime-model.md 引用的文档
grep -oP '\[.*?\]\(\./[^)]+\.md\)' docs/architecture/runtime-model.md | while read link; do
  target=$(echo "$link" | grep -oP '(?<=\(\./)[^)]+')
  [ -f "docs/architecture/$target" ] || echo "BROKEN: $target"
done
```

### Step 3: Circuit Breaker (Self-Check)

```bash
bash scripts/self-check.sh
# 期望: exit 0
```

### Step 4: Production Code Check

```bash
git diff --stat origin/codex/epic-005-architecture-refactoring
# 期望: 仅含 docs/ + internal/engine/ + internal/output/ 下的 .md 文件
# 不应包含任何 .go / .py / .sh 文件修改
```

### Step 5: Engineering Principles Self-Audit

```bash
# 修正后的所有架构文档应符合 EP-1~EP-7
# EP-1: 无 SecurityEngine interface/API 描述
grep -r "SecurityEngine\|Engine interface" docs/architecture/ internal/engine/ internal/output/ --include="*.md"
# 期望: 0 匹配（或仅在 EP 自身的反例中出现）

# EP-7: 每个文档 80% 描述当前系统
# 手动审核: security-engine.md, engine_contract.md 是否以当前现实为主
```

## 验证通过标准

- Step 1: 所有 SC 检查通过
- Step 2: 无断裂交叉引用
- Step 3: self-check.sh exit 0
- Step 4: Production 代码零修改
- Step 5: 自审计通过
