---
name: secguard-python-deserialization
description: "检测反序列化漏洞 — pickle.load / yaml.load / dill.load 加载不可信数据导致任意代码执行"
language: python
topic: [deserialization, injection]
skill_id: python.deserialization.pickle
signal_filter: python.deserialization.pickle*
signal_source: call_sites[category="deserialization"]
severity: critical
cwe: CWE-502
trigger_functions: [pickle.load, pickle.loads, yaml.load, dill.load, dill.loads, marshal.load, marshal.loads, shelve.open, jsonpickle.decode]
---

# 反序列化漏洞检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE | Guard-rule |
|----------|---------------|-------------------|----------|-----|------------|
| `python.deserialization.pickle` | `call_sites[cat="deserialization"]` | `pickle.load`, `yaml.load`, `dill.load`, `marshal.loads` | Critical | CWE-502 | — |

## Scenario 1: Pickle 反序列化任意代码执行

### 威胁定义
Python `pickle` 协议在反序列化时执行 `__reduce__` 方法，攻击者构造恶意 pickle 数据可触发任意系统命令。`yaml.load()` 默认使用 `FullLoader` 之外的更强大的解析器。涉及框架: Django session、Celery 任务序列化、Redis cache。

### 检测逻辑
```python
# BAD: pickle.load 不可信数据
import pickle
data = request.files['data'].read()
obj = pickle.loads(data)  # 可执行任意代码

# BAD: yaml.load 不可信数据
import yaml
config = yaml.load(user_input)  # 应使用 yaml.safe_load()

# GOOD: 安全替代
import json
obj = json.loads(data)  # 纯数据
yaml.safe_load(user_input)  # 仅基础类型
```

### 检测模式
- **MATCH**: `pickle\.load(\(s\))?` | `yaml\.load(?!.*SafeLoader)` | `dill\.load(\(s\))?` | `marshal\.load(\(s\))?` | `shelve\.open` | `jsonpickle\.decode`
- **EXCLUDE**: `yaml\.safe_load` | `yaml\.load.*SafeLoader` | `json\.load`

### 修复指引
1. 使用 `json`/`msgpack` 替代 pickle/dill
2. 使用 `yaml.safe_load()` 替代 `yaml.load()`
3. Celery 配置 `task_serializer = 'json'`
4. Django session 配置 `SESSION_SERIALIZER = 'json'`

## 证据收集指引

| 证据类型 | 要求 |
|----------|------|
| code_context | MUST — 反序列化调用 + 数据来源 |
| judgment_rationale | MUST — 数据是否用户可控、有无签名验证 |
| data_flow_path | SHOULD — 不可信来源 → 反序列化点 |
| sanitizer_analysis | MAY — hmac 签名 / 数字信封校验 |

## 输出格式

记录为 finding，标注 `severity: critical`，`cwe: CWE-502`。
