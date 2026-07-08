# Guard-Rules ↔ Skills 映射

> **本文件解决"双份维护"问题**。
>
> `knowledge/guard-rules/` 是规范知识源头（CWE 定义、安全模式、修复示例），跨语言共享。
> `skills/<lang>/<skill>/references/rule.md` 是运行时适配副本（检测协议、信号映射、事实锚定）。
>
> **两者不重复内容，各司其职。** 本文件提供双向映射。

## 映射关系

| guard-rule (知识源头) | 对应 Skill (检测算子) | 是否存在 skill? | 说明 |
|----------------------|---------------------|----------------|------|
| memory-buffer-overflow | **buffer_overflow** | ✅ | CWE-120，strcpy/strcat/sprintf/memcpy 调用检测 |
| memory-null-dereference | **null_dereference** | ✅ | CWE-476，malloc/calloc 返回值检查 |
| memory-memory-leak | **memory_leak** | ✅ | CWE-401，alloc/free 配对分析 |
| memory-double-free | **double_free** | ✅ | CWE-415，同一指针多次 free |
| memory-use-after-free | **use_after_free** | ✅ | CWE-416，free 后使用 |
| memory-integer-overflow | **integer_overflow** | ✅ | CWE-190，整数运算溢出 |
| memory-heap-buffer-overflow | **buffer_overflow** | ✅ | 合并到 buffer_overflow |
| memory-off-by-one | **buffer_overflow** | ✅ | 合并到 buffer_overflow |
| memory-format-string | **api_semantic_misuse** | ✅ | CWE-628，printf(user_input) 等 |
| memory-oob-read | **buffer_overflow** | ✅ | 合并到 buffer_overflow |
| memory-uninitialized-memory | **null_dereference** | ✅ | CWE-476 |
| memory-mismatched-free | **ownership_transfer** | ✅ | mismatched alloc/dealloc |
| memory-bad-cast | **api_semantic_misuse** | ✅ | CWE-628 |
| resource-file-leak | **resource_leak** | ✅ | CWE-404，fopen/open 未 close |
| resource-file-double-close | **resource_leak** | ✅ | 合并到 resource_leak |
| resource-file-use-after-close | **resource_leak** | ✅ | 合并到 resource_leak |
| resource-socket-leak | **resource_leak** | ✅ | 合并到 resource_leak |
| resource-lock-misuse | **lock_misuse** | ✅ | CWE-667 |
| resource-refcount-misuse | **ownership_transfer** | ✅ | 引用计数错误 |
| system-command-injection | **command_injection** | ✅ | CWE-78，system/popen |
| system-path-traversal | **input_validation** | ✅ | CWE-22 |
| system-insecure-temp-file | **input_validation** | ✅ | CWE-377 |
| system-symlink-attack | **input_validation** | ✅ | CWE-61 |
| system-toctou | **input_validation** | ✅ | CWE-367 |
| system-privilege-escalation | **input_validation** | ✅ | CWE-269 |
| system-insecure-permissions | **input_validation** | ✅ | CWE-276 |
| system-secrets-detection | **hardcoded_secrets** | ✅ | CWE-798 |
| crypto-hardcoded-secrets | **hardcoded_secrets** | ✅ | CWE-798 |
| crypto-hardcoded-iv | **hardcoded_secrets** | ✅ | 合并到 hardcoded_secrets |
| crypto-weak-crypto-algorithm | **hardcoded_secrets** | ✅ | CWE-327 |
| crypto-insufficient-key-length | **hardcoded_secrets** | ✅ | CWE-326 |
| crypto-password-storage | **hardcoded_secrets** | ✅ | CWE-916 |
| crypto-aes-ecb-mode | **hardcoded_secrets** | ✅ | CWE-327 |
| crypto-weak-random | **hardcoded_secrets** | ✅ | CWE-338 |
| crypto-tls-version | — | ❌ | 暂不覆盖 |
| concurrency-race-condition | **lock_misuse** | ✅ | CWE-362，锁误用的一种 |
| concurrency-data-race | **lock_misuse** | ✅ | CWE-366 |
| concurrency-deadlock | **lock_misuse** | ✅ | CWE-833 |
| concurrency-thread-unsafe-signal | **lock_misuse** | ✅ | CWE-479 |
| error-exception-swallow | **error_propagation** | ✅ | CWE-390 |
| error-unified-error-format | **error_propagation** | ✅ | 合并到 error_propagation |
| error-stack-trace-leak | — | ❌ | 暂不覆盖 |
| error-log-sensitive-data | — | ❌ | 暂不覆盖 |
| error-debug-mode-production | — | ❌ | 暂不覆盖 |
| error-panic-to-client | — | ❌ | 暂不覆盖 |
| web-sql-injection | — | ❌ | 语言无关，后续覆盖 |
| web-xss | — | ❌ | 同上 |
| web-input-validation | — | ❌ | 同上 |
| web-* (其余 20+) | — | ❌ | 暂不覆盖 |

## 维护规则

### 当修改一个 guard-rule 时

```
1. 修改 `knowledge/guard-rules/<name>.md`（规范来源）
2. 查本映射表找到对应 skill
3. 更新 `skills/<lang>/<skill>/references/rule.md`（运行时副本）
4. 修改记录到 CHANGELOG
```

### 当修改一个 skill 的 references/rule.md 时

```
1. 先查 `knowledge/guard-rules/` 是否有对应规则
2. 有 → 先更新 guard-rule（规范来源），再同步到 rule.md
3. 无 → rule.md 是新规则，考虑在 guard-rules/ 中补充
```

### 非 C/C++ 语言的规则覆盖

当前 15 个 skill 仅覆盖 C/C++。其他语言的 guard-rule 不变：
- 使用旧架构（LLM 全权加载多个 guard-rule）
- 后续按语言逐步迁移到 skill 架构
- 迁移顺序: C/C++ ✅ → Java → Go → Python → JavaScript

## 统计

- 总 guard-rules: ~67
- 已映射到 skills: ~40（部分合并后实际由 15 个 skill 覆盖）
- 暂不覆盖: ~27（主要为 web-* 和部分 error/crypto 规则）
- 覆盖比例: ~60%
