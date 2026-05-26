---
detector: code-injection
severity: critical
cwe: CWE-94
language: [python]
tags: [web, injection, rce]
---

# Python 代码注入检测

## 检测概要

检查 Python 代码中是否将不可信数据传递给 eval/exec/compile/pickle 等代码执行函数。

## 检测逻辑

### Step 1: 搜索代码执行函数

```python
# BAD: eval 用户输入
result = eval(request.GET['expr'])

# BAD: exec 用户输入
exec(f"result = {user_input}")

# BAD: compile 用户输入
code = compile(user_input, '<string>', 'exec')
exec(code)

# BAD: pickle 反序列化不可信数据
data = pickle.loads(request.body)

# BAD: yaml.load (非 safe_load)
config = yaml.load(user_yaml)

# BAD: marshal.loads
obj = marshal.loads(untrusted_data)

# BAD: importlib 动态导入
module = importlib.import_module(user_module_name)
```

### Step 2: 安全替代

```python
# GOOD: 安全的数学表达式求值
import ast
import operator

ALLOWED_NODES = {ast.Expression, ast.Num, ast.BinOp, ast.Add, ast.Sub, ast.Mult, ast.Div}
tree = ast.parse(user_expr, mode='eval')
# Validate tree against ALLOWED_NODES before eval

# GOOD: yaml.safe_load
config = yaml.safe_load(user_yaml)

# GOOD: JSON 替代 pickle
data = json.loads(request.body)

# GOOD: 白名单的 import
ALLOWED_MODULES = {'json', 'csv', 'datetime'}
if user_module_name in ALLOWED_MODULES:
    module = importlib.import_module(user_module_name)
```

## 误报排除

| 场景 | 原因 |
|------|------|
| `ast.literal_eval` | 仅支持字面量，安全 |
| `yaml.safe_load` | 禁用任意类构造 |
| `json.loads` | JSON 不执行代码 |
| 白名单校验后的 importlib | 已控制导入范围 |
| 编译器内部使用的 compile | 非用户输入 |

## 检测模式汇总

```
# eval/exec 直接用户输入
eval\(request\.|eval\(input\(|eval\(sys\.argv
exec\(request\.|exec\(input\(

# pickle/yaml 不可信数据
pickle\.loads\(|pickle\.load\(
→ 来源: request|body|argv|file upload

# yaml.load (非 safe_load)
yaml\.load\(
→ 非 yaml\.safe_load\(

# importlib 动态导入
importlib\.import_module\(
→ 参数含外部输入
```
