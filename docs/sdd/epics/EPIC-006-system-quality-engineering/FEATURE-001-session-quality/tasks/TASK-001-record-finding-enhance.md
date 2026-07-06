# TASK-001: record-finding.py 增强

> **所属**: FEATURE-001-session-quality
> **优先级**: P0

## 改动项

### 1. argparse 拒绝未知参数 (P1)

当前行为: `--attack-scannerio` argparse 静默忽略（`parse_known_args` 行为），
导致 `--attack-scenario` 缺失后报 required args error。

改为: 调用 `p.parse_args()` 后检查 `sys.argv` 中是否有未识别的 `--` 参数。

```python
# 在所有参数解析后，检查是否有未知参数
import re
for raw_arg in normalized_argv:
    if raw_arg.startswith('--'):
        name = raw_arg.split('=')[0].lstrip('-')
        if name not in [a.dest.replace('_', '-') for a in p._actions if hasattr(a, 'dest')]:
            print(f"FATAL: Unknown argument: --{name}", file=sys.stderr)
            sys.exit(4)
```

### 2. --from-stdin 接受完整 JSON (P0)

当前: `--from-stdin` 仍需 CLI `--scan-dir`, `--detector`, `--severity` 等参数。
Agent 首次使用必然踩坑（实测日志验证）。

改为: `--from-stdin` 时，stdin JSON 必须包含所有必需字段。
`--scan-dir` 也可从 JSON 读取。CLI 参数完全可选。

实现: 在 `--from-stdin` 模式下标记所有 CLI 参数为 `required=False`，
然后从 JSON 中验证必要性。

### 3. 后调用验证 (P1)

在 stdout 输出 RECORDED 行后，同时输出 findings 文件路径。
Agent 可据此自行确认文件已写入（外部指引，非 record-finding.py 的内部修改）。
