# Reporters

> 审计结果的输出格式扩展点。每个 Reporter 负责将 findings 转换为特定格式。

## 当前支持的输出格式

| Reporter | 输出文件 | 用途 | 状态 |
|----------|---------|------|------|
| `markdown` | `report.md` | 人类可读审计报告 | ✅ 渲染器内置 |
| `sarif` | `results.sarif` | SARIF 2.1.0 (CI/CD) | ✅ 渲染器内置 |
| `json` | `summary.json` | 轻量统计 | ✅ 渲染器内置 |

## 扩展点

添加新的 Reporter：

```
reporters/<name>.py
reporters/<name>.tpl          ← 可选模板
```

Reporter 接口（规范）：

```python
def render(findings: list, index: dict, output_dir: str) -> str:
    \"\"\"
    Args:
        findings: 所有发现的列表
        index: 代码索引 (AnalysisContext)
        output_dir: 输出目录路径
    Returns:
        输出的文件路径
    \"\"\"
    pass
```
