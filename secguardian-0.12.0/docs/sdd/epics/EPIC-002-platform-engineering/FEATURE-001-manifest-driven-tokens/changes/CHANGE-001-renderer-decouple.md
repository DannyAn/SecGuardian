# CHANGE-001: renderer 从硬编码索引解耦

> **Feature**: FEATURE-001-manifest-driven-tokens
> **日期**: 2026-06-07
> **类型**: 技术债务清理
> **原则**: Change 管理演进

## Reason

`scripts/render-report.py` 中硬编码了 68 行 `DETECTOR_RULE_INDEX`：
```python
DETECTOR_RULE_INDEX = {
    "system.command-injection": {"index": 0, "cwe": ["CWE-77", "CWE-94"]},
    "web.sql-injection":        {"index": 1, "cwe": ["CWE-89"]},
    # ... 68 entries — 每次新增 detector 必须手动同步
}
```

这与 Manifest-Driven Tokens 的目标一致：消除散弹式修改。新增 detector 时开发者必须记住更新这个 dict，否则 SARIF 输出缺少 CWE 映射。

## Impact

| 维度 | 变更前 | 变更后 |
|------|--------|--------|
| 新增 detector 需改文件数 | 9+ (含 renderer) | 2 (manifest.json + detector 文件) |
| SARIF ruleId 映射 | 硬编码 dict | 动态扫描 knowledge/guard-rules/ |
| CWE 字段 | 手动维护 | 自动从 detector frontmatter 提取 |

### 新增需求
- REQ-011: renderer 从 knowledge/guard-rules/ 动态构建规则索引

### 向后兼容
- SARIF 输出格式不变
- ruleId 命名规则不变
