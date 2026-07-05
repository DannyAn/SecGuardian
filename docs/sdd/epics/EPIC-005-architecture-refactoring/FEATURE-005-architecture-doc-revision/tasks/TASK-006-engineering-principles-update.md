# TASK-006: Update engineering-principles.md

> **Feature**: FEATURE-005 Architecture Document Revision
> **文件**: `docs/architecture/engineering-principles.md`
> **改动量**: 局部修改 ~5%

## 目标

更新 EP-1，提供"信号锚定"作为抽象 Engine 的替代方案。

## 具体修改

### EP-1 更新

**标题**: "No Premature Execution Kernel Abstraction" → "Signal Anchoring Over Engine Abstraction"

**Statement 段落追加**:
```markdown
### What to Do Instead (Updated)

Instead of abstracting the execution path behind an Engine interface,
strengthen the deterministic signals that anchor LLM reasoning:

1. **Signal anchoring**: Every finding must reference an index.json symbol or file+line
2. **Signal pre-filtering**: Use index signals to scope detector applicability
3. **Signal enhancement**: Progressively improve indexer output (cross-file call graph,
   type hierarchy, data-flow pre-analysis)

These are concrete, verifiable improvements to the indexer — not abstract
interfaces that assume a second strategy before it exists.
```

**Non-Violation Example 更新**:
```go
// ✅ Acceptable — signal anchoring, not engine abstraction
// index.json provides deterministic anchors; LLM reasoning is constrained
// to produce findings that reference these anchors.
type FindingAnchor struct {
    SymbolName string `json:"symbol_name,omitempty"`
    File       string `json:"file"`
    Line       int    `json:"line"`
}
// The anchor is a data constraint, not an execution abstraction.
```

### Summary Table 更新

EP-1 行更新为新的 Enforcement 描述。

## 验证

```bash
# EP-1 包含替代方案
grep -c "Signal Anchoring\|信号锚定" docs/architecture/engineering-principles.md  # 期望: >= 1

# 七条 EP 全部存在
grep -c "^## Principle EP-" docs/architecture/engineering-principles.md  # 期望: 7
```
