# Python 安全反模式

代码审查中需要关注的 Python 特有安全反模式。

## 异常处理反模式

| 反模式 | 风险 | 正确做法 |
|--------|------|---------|
| `except: pass` 裸异常吞掉 | 包括 KeyboardInterrupt/SystemExit | 明确异常类型 |
| `except Exception: pass` 空块 | 吞掉安全关键异常 | 至少记录日志 |
| `raise` 无参数在错误上下文 | 丢失原始 traceback | `raise from exc` 保留链 |

## 动态特性反模式

| 反模式 | 风险 | 正确做法 |
|--------|------|---------|
| `getattr(obj, user_key)` | 访问非预期属性 | 白名单允许的属性 |
| `setattr(obj, user_key, val)` | 注入属性 | 禁止用户可控 key |
| `__getattr__` 重写不当 | 属性访问劫持 | 安全审计自定义 getattr |
| `type(name, bases, dict)` 动态创建类 | 类型混淆 | 禁止用户输入作为类名 |
| Monkey patch 第三方库 | 安全假设失效 | 通过注入/配置替代 |

## 反序列化反模式

| 反模式 | 风险 | 正确做法 |
|--------|------|---------|
| `json.loads` → `object_hook` 动态类型 | 类型注入 | 使用具体类型 + Pydantic |
| `pickle.dumps` 用于缓存/会话 | 如果数据可被篡改则危险 | JSON + HMAC 签名 |

## Django/Flask 反模式

| 反模式 | 风险 | 正确做法 |
|--------|------|---------|
| Model `objects.raw()` 直接使用 | SQL 注入 | 参数化或 ORM filter |
| `HttpResponse(user_content)` | XSS | render() 自动编码 |
| `@login_required` 覆盖不完整 | 未授权访问 | 检查所有敏感视图 |
| DRF `Serializer` 无 `read_only_fields` | Mass Assignment | 明确只读字段 |
