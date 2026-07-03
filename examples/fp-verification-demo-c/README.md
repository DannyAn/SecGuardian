# FP Verification Demo — 误报消减验证用例集

验证 FEATURE-003 三轮验证管道。18 个测试用例覆盖 5 个分类。

## 规模

| 指标 | 数值 |
|------|------|
| 源文件 | 7 |
| 总测试用例 | 18 |
| 应完全不产生 Finding (P0) | 7 |
| 应被验证管道抑制 (P1+P2+P3) | 7 |
| 最终 Certified Finding | 4 |
| 目标收敛率 | 77.8% |
| 目标 Precision | 100% |

完整 benchmark 见 [benchmark.md](benchmark.md)，ground truth 见 [expected-results.json](expected-results.json)。

## 用例覆盖矩阵

### P0 — 安全函数 (Detector EXCLUDE)

| # | 文件 | 安全函数 | 预期 |
|---|------|---------|------|
| P0-01~04 | `p0_safe_functions.c` | memcpy_s, strcpy_s, sprintf_s, strcat_s (Annex K) | 0 Finding |
| P0-05 | `p0_safe_functions.c` | snprintf + sizeof + 返回值检查 | 0 Finding |
| P0-06 | `p0_safe_functions.c` | execve() 不经过 shell | 0 Finding |
| P0-07 | `p0_safe_functions.c` | sqlite3_prepare_v2 + bind_text 参数化 | 0 Finding |

### P1 — Semantic Verification (安全框架)

| # | 文件 | 触发 Detector | 安全机制 | P1 期望 |
|---|------|-------------|---------|--------|
| P1-01~02 | `p1_safecopy_wrapper.c` | memory.buffer-overflow | SafeCopy 包装保证 bounds_checked | exempted |
| P1-03 | `p1_safequery_wrapper.c` | web.sql-injection | SafeQuery 包装保证 prepared_statement | exempted |

### P2 — Counter-Evidence (反证搜寻)

| # | 文件 | 触发 Detector | 反证 | P2 期望 |
|---|------|-------------|------|--------|
| P2-01 | `p2_raii_memory.c` | memory.memory-leak | ResourceHandle RAII 构造分配+析构释放 | counter_evidence_found |
| P2-02 | `p2_lock_guard.c` | concurrency.race-condition | LockGuard mutex 守卫 | counter_evidence_found |
| P2-03~04 | `p2_bounds_checked.c` | memory.buffer-overflow | if-guard bounds check / sizeof guard | counter_evidence_found |

### P3 — Edge Cases (裁决法庭)

| # | 文件 | 触发 Detector | 部分保护 | P3 期望 |
|---|------|-------------|---------|--------|
| P3-01 | `p3_edge_case.c` | system.command-injection | is_safe_input 黑名单过滤但不充分 | suspected |
| P3-02 | `p3_edge_case.c` | concurrency.race-condition | mutex 保护读取但 TOCTOU 窗口 | suspected |

### TP — True Positives (真阳性对照)

| # | 文件 | 漏洞 | 期望 |
|---|------|------|------|
| TP-01 | `p1_safecopy_wrapper.c` | memcpy 无 bounds check, 无 SafeCopy | P3 confirmed |
| TP-02 | `p1_safequery_wrapper.c` | sprintf SQL 拼接, 无参数化 | P3 confirmed |
