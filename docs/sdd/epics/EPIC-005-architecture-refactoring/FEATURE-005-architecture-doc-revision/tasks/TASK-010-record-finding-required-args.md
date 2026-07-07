# TASK-010: Make Evidence Fields Required in record-finding.py

> **Feature**: FEATURE-005 | **来源**: CHANGE-001
> **文件**: `scripts/record-finding.py`
> **改动量**: ~10 行

## 目标

`record-finding.py` 的 `--snippet`、`--code-context`、`--rationale` 从可选改为必填，
强制 LLM 在录制 finding 前准备完整证据。

## 具体修改

在 argparse 定义中将 `required=True` 加入以下参数：
- `--snippet` (当前: 可选)
- `--code-context` (当前: 可选)
- `--rationale` (当前: 可选)

修改前：
```python
parser.add_argument('--snippet', default='', help='Code snippet')
parser.add_argument('--code-context', default='', help='Code context')
parser.add_argument('--rationale', default='', help='Judgment rationale')
```

修改后：
```python
parser.add_argument('--snippet', required=True, help='Code snippet (REQUIRED per engine_contract.md Rule B)')
parser.add_argument('--code-context', required=True, help='Code context (REQUIRED per engine_contract.md Rule B)')
parser.add_argument('--rationale', required=True, help='Judgment rationale (REQUIRED per engine_contract.md Rule B)')
```

同时在 `--attack-scenario` 上也加 required：
```python
parser.add_argument('--attack-scenario', required=True, help='Attack scenario (REQUIRED)')
```

## 验证

```bash
# 不带必填参数应该报错
python3 scripts/record-finding.py --command secguard --scan-dir /tmp --detector test --severity High --cwe CWE-999 --file test.go --line 1 --fix-before x --fix-after y 2>&1 | grep -c "required"
# 期望: >= 1 (报错信息中有 required)
```
