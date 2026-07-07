---
detector: code-injection
severity: critical
cwe: CWE-94
language: [python]
tags: [web, injection, rce]
precision: high
confidence: dynamic
---

## Detection Spec

<!-- @secguardian:detection-spec -->
```json
{
  "detector": "web.code-injection",
  "type": "guard-rule",
  "namespace": "web",
  "severity": "Critical",
  "cwe": "CWE-94",
  "cvss": 9.8,
  "confidence": "dynamic",
  "precision": "high",
  "languages": [
    "python"
  ],
  "target_functions": [
    "compile",
    "eval",
    "exec",
    "import_module",
    "load",
    "loads",
    "parse",
    "safe_load"
  ],
  "match_patterns": [],
  "exclude_patterns": [],
  "required_evidence": [
    "code_context",
    "judgment_rationale"
  ],
  "optional_evidence": [
    "data_flow_path",
    "call_stack"
  ]
}
```
## 威胁定义 (Threat Definition)

不可信数据传递给 Python 代码执行函数（`eval`/`exec`/`compile`/`pickle.load`），导致攻击者在服务端执行任意 Python 代码。`eval("__import__('os').system('id')")` 即可完成 RCE。

**核心原则：永远不要将用户输入传递给任何代码执行函数。即使是看似安全的沙箱（`eval(x, {"__builtins__": {}})`）也可能被绕过。**

## 检测逻辑 (Detection Logic)

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

## 修复指引 (Remediation)

1. **禁止**：`eval()`/`exec()`/`compile()` 接受任何用户输入
2. 如需动态执行，使用安全沙箱（如 RestrictedPython）并严格限制可用函数
3. `pickle` → 替换为 JSON 序列化
4. `yaml.load` → 替换为 `yaml.safe_load`

## 取证证据收集指引 (Evidence Collection Guide)

### 必须收集 (MUST)
- [ ] **code_context**：eval/exec/pickle 调用及参数来源
      → findings.evidence.code_context
- [ ] **judgment_rationale**：用户输入是否可达代码执行函数
      → findings.evidence.judgment_rationale

### 建议收集 (SHOULD)
- [ ] **data_flow_path**：用户输入→代码执行函数的完整数据流
      → findings.evidence.data_flow_path
- [ ] **call_stack**：从入口到代码执行函数的调用链
      → findings.evidence.call_stack

### 可选收集 (MAY)
- [ ] **variable_state**：执行函数参数值/沙箱配置状态
      → findings.evidence.variable_state
- [ ] **sanitizer_analysis**：是否使用 ast.literal_eval 或 safe_load 等安全替代
      → findings.evidence.sanitizer_analysis

## 误报排除 (False Positive Exclusion)

| 场景 (Scenario) | 排除依据 (Exclusion Basis) | 证据要求 (Evidence Required) |
|------|------|------|
| `ast.literal_eval` | 仅支持字面量，安全 | 确认调用为 ast.literal_eval（非 ast.parse + eval 组合） |
| `yaml.safe_load` | 禁用任意类构造 | 确认使用 yaml.safe_load，非 yaml.load |
| `json.loads` | JSON 不执行代码 | 确认数据源为 JSON 格式，非 pickle 格式伪装 |
| 白名单校验后的 importlib | 已控制导入范围 | 提供白名单常量定义及校验代码 |
| 编译器内部使用的 compile | 非用户输入 | 提供 compile 参数来源为非用户可控输入的证明 |

## 检测模式汇总 (Detection Pattern Summary)

### 匹配模式 (MATCH)

```
# eval/exec 直接用户输入
eval\(request\.|eval\(input\(|eval\(sys\.argv
→ evidence: code_context, data_flow_path

exec\(request\.|exec\(input\(
→ evidence: code_context, data_flow_path

# pickle/yaml 不可信数据
pickle\.loads\(|pickle\.load\(
→ 来源: request|body|argv|file upload
→ evidence: data_flow_path, code_context

# yaml.load (非 safe_load)
yaml\.load\(
→ 非 yaml\.safe_load\(
→ evidence: code_context, sanitizer_analysis

# importlib 动态导入
importlib\.import_module\(
→ 参数含外部输入
→ evidence: data_flow_path

# compile + exec 链
compile\(.*user_input
→ evidence: code_context

# marshal.loads 不可信数据
marshal\.loads\(
→ evidence: code_context
```

### 排除模式 (EXCLUDE)

```
# ast.literal_eval 安全求值
→ evidence: sanitizer_analysis (仅支持字面量)

# yaml.safe_load 安全加载
→ evidence: sanitizer_analysis (禁用任意类构造)

# json.loads JSON 反序列化
→ evidence: sanitizer_analysis (纯数据格式)

# importlib + 白名单校验
→ evidence: sanitizer_analysis (已控制导入范围)

# compile 内部编译器使用（非用户输入）
→ evidence: judgment_rationale (参数来源为系统内部)
```
