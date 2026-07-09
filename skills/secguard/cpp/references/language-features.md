# C/C++ 语言特性参考

## 自定义分配器识别

在嵌入式、内核、游戏引擎中，直接使用 `malloc`/`free` 很少见。大厂项目通常定义自己的分配器包装，以便审计、追踪和替换。

**命名模式（都应识别为分配/释放函数）：**
```
分配:     xxx_malloc, xxx_alloc, xxx_new, xxx_create, ALLOC_xxx, pool_alloc
释放:     xxx_free, xxx_delete, xxx_destroy, xxx_release, FREE_xxx, pool_free
重分配:   xxx_realloc, xxx_resize
```

**典型模式：**
```c
// 前缀包装
void* my_malloc(size_t size);
void  my_free(void* ptr);

// 宏包装
#define MALLOC(s)   mem_pool_alloc(&global_pool, s)

// Arena/zone 分配器
void* zone_alloc(Zone* z, size_t s);
void  zone_free_all(Zone* z);

// C++ operator 重载
void* operator new(size_t size);
void  operator delete(void* ptr);
```

**在 signal indexer 中的处理**：`index.json` 的 `symbols.functions` 中，`xxx_malloc` 等价于 `malloc`，`xxx_free` 等价于 `free`。配对验证：`xxx_malloc` 应由 `xxx_free` 释放，而非混用裸 `free()`。

## 编译器安全标志

```
-fstack-protector-strong           # Stack canary
-fPIE -pie                         # ASLR
-Wall -Wextra -Werror              # 编译时警告
-D_FORTIFY_SOURCE=2                # 加固内存函数
-Wformat -Wformat-security         # 格式字符串检查
-Wl,-z,relro -Wl,-z,now            # Full RELRO
-fsanitize=address                 # AddressSanitizer
```

## SQL/数据库注入（C/C++ 特有）

| 模式 | 风险 | 安全做法 |
|------|------|---------|
| `sqlite3_mprintf(sql, user)` `%s` | SQL 注入 | `sqlite3_prepare_v2` + `sqlite3_bind_text` |
| `snprintf(buf, n, sql, user)` + `sqlite3_exec()` | SQL 注入 | prepare + bind |
| `mysql_query(conn, buf)` + 拼接 | SQL 注入 | `mysql_stmt_bind_param()` |
| `PQexec(conn, sql)` + 拼接 | SQL 注入 | `PQexecParams()` |
| `SQLExecDirect(stmt, sql, ...)` + 拼接 | SQL 注入 | `SQLBindParameter()` + `SQLPrepare()` |

## C++ 特有问题

- RAII 违反（资源未绑定生命周期）
- 虚函数表覆盖（vtable 劫持）
- 异常抛出时的资源泄露
- `reinterpret_cast` 绕过类型安全
- Lambda 捕获引用悬空
