---
name: secguard-python-command-injection
description: "检测命令注入 — os.system / subprocess(shell=True) 拼接用户输入"
language: python
topic: [system, injection, shell]
skill_id: python.command-injection.shell
signal_filter: python.command-injection.shell*
signal_source: call_sites[category="exec"]
severity: critical
cwe: CWE-78
trigger_functions: [os.system, os.popen, subprocess.Popen, subprocess.call, subprocess.run, subprocess.getoutput, subprocess.getstatusoutput, os.exec*, os.posix_spawn, shutil.which]
---

# 命令注入检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE | Guard-rule |
|----------|---------------|-------------------|----------|-----|------------|
| `python.command-injection.shell` | `call_sites[cat="exec"]` | `os.system`, `subprocess.Popen`, `subprocess.run` | Critical | CWE-78 | `system-command-injection` |

## Scenario 1: Shell 命令拼接用户输入

### 威胁定义
Python 中 `os.system()` 和 `subprocess.*(shell=True)` 会调用系统 shell 解析命令字符串，用户输入中的 `;`、`|`、`$()` 等元字符可导致任意命令执行。涉及框架: Flask web 接口、Django management command、自动化脚本。

### 检测逻辑
```python
# BAD: os.system + 用户输入
os.system(f"ping {user_host}")

# BAD: subprocess shell=True
subprocess.run(f"grep {pattern} /var/log", shell=True)

# GOOD: 参数列表 + shell=False
subprocess.run(["ping", "-c", "1", validated_host], shell=False)
```

### 检测模式
- **MATCH**: `os\.system\(` | `os\.popen\(` | `subprocess\.(Popen|call|run)\(.*shell\s*=\s*True` | `subprocess\.getoutput\(`
- **EXCLUDE**: `shell\s*=\s*False` | 参数为列表而非字符串

### 修复指引
1. 使用 `subprocess.run([...], shell=False)` 参数列表形式
2. 使用 `shlex.quote()` 对用户参数转义（不推荐首选）
3. 白名单验证允许的命令和参数

## 证据收集指引

| 证据类型 | 要求 |
|----------|------|
| code_context | MUST — 命令执行调用 + 参数构造 |
| judgment_rationale | MUST — 用户输入是否可达命令参数 |
| data_flow_path | SHOULD — 输入入口到执行点 |
| call_stack | SHOULD — 调用链确认跨函数传递 |

## 输出格式

记录为 finding，标注 `severity: critical`，`cwe: CWE-78`。
