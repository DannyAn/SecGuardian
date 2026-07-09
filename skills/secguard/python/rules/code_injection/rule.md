---
name: secguard-python-code-injection
description: "检测代码注入 — eval / exec / compile / import_module 用户可控"
language: python
topic: [injection, code_execution]
skill_id: python.code-injection.eval
signal_filter: python.code-injection.eval*
signal_source: call_sites[category="code_exec"]
severity: critical
cwe: CWE-94
trigger_functions: [eval, exec, compile, __import__, importlib.import_module, execfile, runpy.run_path, ast.literal_eval]
---

# 代码注入检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE | Guard-rule |
|----------|---------------|-------------------|----------|-----|------------|
| `python.code-injection.eval` | `call_sites[cat="code_exec"]` | `eval`, `exec`, `compile`, `import_module` | Critical | CWE-94 | — |

## Scenario 1: eval/exec 用户输入

### 威胁定义
Python `eval()`/`exec()` 执行任意 Python 表达式/代码。攻击者可通过控制输入执行系统命令、读取文件、修改运行时状态。涉及框架: 计算器接口、动态配置解析、CMS 系统。

### 检测逻辑
```python
# BAD: eval 用户输入
result = eval(request.form['expression'])

# BAD: exec 用户输入
exec(user_code)

# BAD: import_module 用户可控
module = importlib.import_module(user_input)

# BAD: compile + exec
code = compile(user_input, '<string>', 'exec')
exec(code)

# GOOD: ast.literal_eval 安全替代
import ast
result = ast.literal_eval(user_input)  # 仅安全字面量

# GOOD: 白名单模块加载
ALLOWED_MODULES = {'math', 'json', 're'}
if user_input in ALLOWED_MODULES:
    module = importlib.import_module(user_input)
```

### 检测模式
- **MATCH**: `eval\(` | `exec\(` | `compile\(` | `import_module\(` | `execfile\(`
- **EXCLUDE**: `ast\.literal_eval` | 输入来自硬编码字面量 | 白名单校验

### 修复指引
1. 使用 `ast.literal_eval()` 替代 `eval()` 处理简单数据类型
2. 禁止 `exec`/`compile` 处理用户输入
3. 动态加载使用白名单 + `importlib.import_module()`

## 证据收集指引

| 证据类型 | 要求 |
|----------|------|
| code_context | MUST — 代码执行函数调用 + 参数来源 |
| judgment_rationale | MUST — 输入是否用户可控、有无沙箱 |
| data_flow_path | SHOULD — 输入到执行点的完整路径 |

## 输出格式

记录为 finding，标注 `severity: critical`，`cwe: CWE-94`。
