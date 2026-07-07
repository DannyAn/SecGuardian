# TASK-006: H-8 render-report.py import 上提

> **文件**: scripts/render-report.py
> **目标**: 将函数内的 `from collections import defaultdict/Counter` 上提到文件顶部

## 验证

- `grep -c 'def.*import\|def.*from' scripts/render-report.py` → 0
