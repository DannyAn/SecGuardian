---
detector: review.python
type: review-rule
language: python
max_severity: Critical
cwe: CWE-000
anti_pattern_count: 12
---
## 审查三要素

每条发现的证据必须给出以下三个维度的判断（直接体现在 finding 的 `evidence.judgment_rationale` 中）：

### 1. 信号锚定 (Signal Anchor)
- 检出是否基于 `index.json` 的 `call_sites`、`string_literals` 或 `control_flow`？
- 是 → HIGH/MEDIUM confidence；否 → LOW confidence

### 2. 利用可达性 (Reachability)
- 反模式涉及的 API/数据是否受用户输入控制？
- 通过 `call_graph.edges` 追踪数据流，判断是否存在从外部输入到 sink 的路径
- 存在 → HIGH exploitability；不存在 → downgrade severity

### 3. 变更上下文 (Change Context)
- 反模式在 diff 新增行 → 完整评估（P0/P1 优先）
- 反模式在 diff 上下文行 → 回归风险检查（P2）
- 反模式在未变更文件 → 标记为 INFO，不阻塞 PR


# Python 安全反模式检测矩阵

代码审查中需要关注的 Python 特有安全反模式及具体检测规则。

## 异常处理反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| `except: pass` 裸异常吞掉 | `except\s*:\s*pass` | Critical |
| `except Exception: pass` 空块 | `except\s+Exception\s*:\s*pass\s*$` | High |
| `raise` 无参数丢失 traceback | `raise\s*$` 非 `raise from` 模式 | Medium |
| `return str(e)` 堆栈泄露 | `return\s+str\(e\)\|jsonify.*str\(e\)` 在异常处理器中 | High |

## 动态特性反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| `getattr(obj, user_key)` | `getattr\([^,]*,\s*(request\|input\|user\|param)` | Medium |
| `setattr(obj, user_key, val)` | `setattr\([^,]*,\s*(request\|input\|user\|param)` | High |
| `type(name, bases, dict)` 动态创建类 | `type\([^,]*,\s*\([^)]*\)` 含外部输入 | High |
| `exec`/`compile` 用户输入 | `exec\(.*request\|input\|user\|compile\(.*request\|input\|user` | Critical |
| `importlib.import_module` 用户输入 | `import_module\(.*request\|input\|user` | High |

## 反序列化反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| `pickle.load(untrusted)` | `pickle\.load[s]?\(.*(request\|input\|user\|data\|body)` | Critical |
| `yaml.load(untrusted)` 非 safe_load | `yaml\.load\(` 非 `yaml.safe_load` | Critical |
| `dill.load` 任意数据 | `dill\.load[s]?\(` | Critical |
| `json.loads` + `object_hook` | `json\.loads\(.*object_hook=` | Medium |

## Django/Flask 反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| Model `objects.raw()` 拼接 | `\.raw\(.*%\|f['\"]\+` SQL 拼接 | Critical |
| `HttpResponse(user_content)` XSS | `HttpResponse\(.*request\|user\|input` | High |
| DRF 无 `read_only_fields` | Meta 类含 `fields = '__all__'` 且无 `read_only_fields` | Medium |
| DEBUG=True 生产环境 | `DEBUG\s*=\s*True` 在 settings.py 中 | High |

## 加密反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| `hashlib.md5` 安全用途 | `hashlib\.md5\(` 且上下文含 `password\|auth\|sign` | High |
| `hashlib.sha1` 安全用途 | `hashlib\.sha1\(` 且上下文含 `password\|auth\|sign` | High |
| `random.random` 安全用途 | `random\.random\(\)\|random\.randint\(` 用于 token/key 生成 | High |
| AES-ECB 模式 | `AES\.MODE_ECB\|AES\.new\(.*ECB` | High |
| 密码验证直接比较 | `password\s*==\s*(user_input\|stored)\|if.*password.*!=.*confirm` | Medium |

## 错误处理反模式

| 反模式 | 检测 Pattern | 严重度 |
|--------|-------------|--------|
| `logging.info(f"Password: {pw}")` | `log.*password\|secret\|token\|key` | High |
| API 返回 traceback | `jsonify\(traceback\.format_exc\(\)\)` | High |
| `app.run(debug=True)` | `app\.run\(debug\s*=\s*True\)` | High |
