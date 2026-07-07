# FP Verification Benchmark — Java

> FEATURE-003 验证管线的 Java 误报消减用例集。
> Ground truth 定义在 expected-results.json。

## 规模

| 指标 | 数值 |
|------|------|
| 源文件 | 5 |
| 总测试用例 | 12 |
| P0 (安全函数不应报) | 6 |
| P1 (语义抑制) | 2 |
| P2 (反证抑制) | 4 |
| P3 (可疑需人工) | 2 |
| TP (真阳性) | 2 |
| 最终 Certified Finding | 4 |

## 用例

### P0 — 安全函数 (不产生 Finding)

| # | 函数 | 安全理由 |
|---|------|---------|
| P0-01 | PreparedStatement | 参数化查询防注入 |
| P0-02 | SecureRandom | 密码学安全随机数 |
| P0-03 | Files.move ATOMIC_MOVE | 原子文件操作 |
| P0-04 | Logger 参数化消息 | 日志占位符非拼接 |
| P0-05 | Path.normalize | 路径遍历防御 |
| P0-06 | Base64.getEncoder | 安全编码输出 |

### P1 — Semantic Verification (抑制)

| # | 触发 | 安全机制 | 期望 |
|---|------|---------|------|
| P1-01 | SQL 注入检测 | SafeQuery 封装强制 PreparedStatement | exempted |
| P1-02 | 路径遍历 | FileLogger 内建路径清洗 | exempted |

### P2 — Counter-Evidence (抑制)

| # | 触发 | 反证 | 期望 |
|---|------|------|------|
| P2-01 | 资源泄漏 | try-with-resources AutoCloseable | counter_evidence_found |
| P2-02 | 竞争条件 | ReentrantLock try/finally | counter_evidence_found |
| P2-03 | 竞争条件 | AtomicInteger | counter_evidence_found |
| P2-04 | 竞争条件 | synchronized 方法 | counter_evidence_found |

### P3 — Edge Cases (suspect)

| # | 触发 | 部分保护 | 期望 |
|---|------|---------|------|
| P3-01 | 命令注入 | 黑名单过滤但不充分 | suspected |
| P3-02 | TOCTOU | 检查在锁外 | suspected |

### TP — True Positives (confirmed)

| # | 漏洞类型 | 代码特征 |
|---|---------|---------|
| TP-01 | SQL 注入 | Statement 字符串拼接 |
| TP-02 | 命令注入 | Runtime.exec 未过滤拼接 |
