---
name: secguard-python
description: 对 Python 代码进行安全加固检视，编排 11 个子 skill，覆盖 API 调用检测、代码注入语义分析、序列化安全验证等多个维度。当用户请求 Python 安全扫描、Python 代码审计、Django/Flask 安全、Python 注入检测、pickle 安全时使用。
category: language-specific
language: python
topic: [web, crypto, system]
---

# Python 安全加固排查 — 检视算子索引

本文件是 `skills/secguard/python/` 下 11 个检视算子 skill 的主索引/派发表。
每个算子对应 `rules/` 下的一个规则目录，包含自己的 `rule.md`。

> **执行流程由 `commands/claude/secguard.md` 的 Dispatcher 协议调度。**
> 本文件只做三件事：(1) 查表选 skill；(2) 按信号分类；(3) 引用 Dispatcher。

---

## 1. 检视算子一览

| # | Rule (目录名) | Severity | CWE | `signal_source` | `skill_id` |
|---|---------------|----------|-----|-----------------|------------|
| 1 | [`deserialization/`](./rules/deserialization/) | Critical | CWE-502 | `call_sites[cat="deserialization"]` | `python.deserialization.pickle` |
| 2 | [`command_injection/`](./rules/command_injection/) | Critical | CWE-78 | `call_sites[cat="exec"]` | `python.command-injection.shell` |
| 3 | [`ssti/`](./rules/ssti/) | Critical | CWE-1336 | `call_sites[cat="template"]` | `python.ssti.jinja2` |
| 4 | [`code_injection/`](./rules/code_injection/) | Critical | CWE-94 | `call_sites[cat="code_exec"]` | `python.code-injection.eval` |
| 5 | [`sql_injection/`](./rules/sql_injection/) | High | CWE-89 | `call_sites[cat="database"]` | `python.sql-injection.execute` |
| 6 | [`path_traversal/`](./rules/path_traversal/) | High | CWE-22 | `call_sites[cat="io"]` | `python.path-traversal.open` |
| 7 | [`ssrf/`](./rules/ssrf/) | High | CWE-918 | `call_sites[cat="network"]` | `python.ssrf.requests` |
| 8 | [`weak_crypto/`](./rules/weak_crypto/) | High | CWE-327 | `call_sites[cat="crypto"]` | `python.weak-crypto.md5` |
| 9 | [`hardcoded_secrets/`](./rules/hardcoded_secrets/) | High | CWE-798 | `call_sites[cat="crypto"]` | `python.hardcoded-secrets.key` |
| 10 | [`debug_mode/`](./rules/debug_mode/) | Medium | CWE-489 | `call_sites[cat="config"]` | `python.debug-mode.django` |
| 11 | [`xss/`](./rules/xss/) | Medium | CWE-79 | `call_sites[cat="template"]` | `python.xss.template` |

**按严重度排序执行**: `Critical (4) → High (5) → Medium (2)`

---

## 2. 信号源分类 → Skill 映射

`index.json` 的 `call_sites[].category` 字段决定触发哪些算子：

| call_sites Category | 触发的 Rule 目录 | 信号函数（示例） |
|--------------------|------------------|-----------------|
| `"deserialization"` | `deserialization` | `pickle.load`, `yaml.load`, `dill.load`, `marshal.loads` |
| `"exec"` | `command_injection` | `os.system`, `subprocess.Popen`, `subprocess.run` |
| `"template"` | `ssti`, `xss` | `render_template_string`, `jinja2.Template`, `mark_safe` |
| `"code_exec"` | `code_injection` | `eval`, `exec`, `compile`, `import_module` |
| `"database"` | `sql_injection` | `cursor.execute`, `sqlalchemy.text`, `raw` |
| `"io"` | `path_traversal` | `open`, `tarfile.extractall`, `shutil`, `pathlib.Path` |
| `"network"` | `ssrf` | `requests.get`, `urllib.request.urlopen`, `httpx.get` |
| `"crypto"` | `weak_crypto`, `hardcoded_secrets` | `hashlib.md5`, `Crypto.Cipher.DES`, `SECRET_KEY`, `password` |
| `"config"` | `debug_mode` | `DEBUG=True`, `debug=True`, `app.run(debug=True)` |

### OO 语言全量加载策略

Python 作为面向对象语言，使用全量加载策略（区别于 C/C++ 精确匹配）：
- 所有 11 个 rule 目录的 `rule.md` 均预读
- 各算子自行从 `index.json.symbols.functions` 匹配 `trigger_functions`
- 无匹配时不产生 finding（`confidence: low`）

---

## 3. 参考文件

| 文件 | 内容 |
|------|------|
| [`references/language-features.md`](./references/language-features.md) | Python 危险函数清单、框架特性 |
