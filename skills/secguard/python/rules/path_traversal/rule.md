---
name: secguard-python-path-traversal
description: "检测路径穿越 — open(user_path) / tarfile.extractall / shutil 用户输入未验证"
language: python
topic: [io, filesystem, injection]
skill_id: python.path-traversal.open
signal_filter: python.path-traversal.open*
signal_source: call_sites[callee="open|Path|join|os.path"]
severity: high
cwe: CWE-22
trigger_functions: [open, pathlib.Path, tarfile.extractall, tarfile.extract, shutil.unpack_archive, shutil.copy, shutil.move, os.remove, os.unlink, os.rename, tempfile.mkstemp]
---

# 路径穿越检测规则

## 概要

| skill_id | signal_source | trigger_functions | severity | CWE | Guard-rule |
|----------|---------------|-------------------|----------|-----|------------|
| `python.path-traversal.open` | `call_sites[cat="io"]` | `open`, `tarfile.extractall`, `pathlib.Path`, `shutil` | High | CWE-22 | — |

## Scenario 1: 文件操作路径用户可控

### 威胁定义
用户通过 `../`、绝对路径覆盖等手段访问受限目录外的文件，可能导致敏感文件读取、ZIP/TAR Slip 攻击。涉及框架: Flask/Django 文件上传、日志查看器、配置文件管理。

### 检测逻辑
```python
# BAD: open 直接使用用户输入
with open(user_path, 'r') as f:
    data = f.read()

# BAD: tarfile extractall Zip Slip
with tarfile.open(user_archive) as tar:
    tar.extractall('/tmp/out')  # 条目覆盖任意文件

# BAD: shutil 用户路径
shutil.copy(user_src, user_dst)

# GOOD: 路径规范化 + 白名单
import os.path
base = '/var/data/'
requested = os.path.normpath(os.path.join(base, user_path))
if not requested.startswith(os.path.realpath(base)):
    raise PermissionError()
with open(requested, 'r') as f:
    data = f.read()
```

### 检测模式
- **MATCH**: `open\(.*request\|args\|form\|input\|user` | `tarfile\.extractall\(` | `shutil\.(copy|move|unpack)\(.*user`
- **EXCLUDE**: `os\.path\.normpath.*startswith.*realpath` | 白名单校验 | 路径拼接从 `os.path.join(base,` 且 base 不可控

### 修复指引
1. `os.path.realpath()` 规范化后校验前缀
2. `tarfile.extractall()` 前检查成员路径（`os.path.isabs()` + `../`）
3. 使用白名单限制允许访问的目录

## 证据收集指引

| 证据类型 | 要求 |
|----------|------|
| code_context | MUST — 文件操作函数及路径构造 |
| judgment_rationale | MUST — 用户输入是否路径可控 |
| data_flow_path | SHOULD — 输入到文件操作的路径 |
| sanitizer_analysis | MAY — 路径规范化/白名单 |

## 输出格式

记录为 finding，标注 `severity: high`，`cwe: CWE-22`。
