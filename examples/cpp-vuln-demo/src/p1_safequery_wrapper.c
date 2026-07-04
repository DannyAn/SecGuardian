/**
 * P1 Semantic Verification — SafeQuery Wrapper
 *
 * 场景: SQL 查询使用项目自定义的 SafeQuery 包装，保证参数化。
 * Detector 的 sql-injection 规则会标记 `sprintf(query, ...)` 然后在 `sqlite3_exec(query)`
 * 中执行。但 SafeQuery 提供了 build + exec 方法，内部使用 sqlite3_bind_* 参数化。
 *
 * P1 应该做的事: 构建 Security Profile 时发现 SafeQuery 保证 prepared_statement，
 * 将任何通过 SafeQuery 执行的查询标记为 exempted。
 */

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sqlite3.h>

// ── 项目自定义 SafeQuery 包装 ──────────────────────
// SafeQuery: 保证参数化查询的 SQLite 包装
// 语义保证: prepared_statement
typedef struct {
    sqlite3 *db;
    sqlite3_stmt *stmt;
} SafeQuery;

SafeQuery *SafeQuery_prepare(sqlite3 *db, const char *sql) {
    SafeQuery *q = (SafeQuery *)malloc(sizeof(SafeQuery));
    q->db = db;
    sqlite3_prepare_v2(db, sql, -1, &q->stmt, NULL);
    return q;
}

void SafeQuery_bind_text(SafeQuery *q, int index, const char *value) {
    sqlite3_bind_text(q->stmt, index, value, -1, SQLITE_TRANSIENT);
}

int SafeQuery_exec(SafeQuery *q) {
    return sqlite3_step(q->stmt);
}

void SafeQuery_free(SafeQuery *q) {
    sqlite3_finalize(q->stmt);
    free(q);
}

// ── 业务代码使用 SafeQuery ─────────────────────────
void lookup_user(sqlite3 *db, const char *username) {
    // 用 SafeQuery — 总是参数化的
    SafeQuery *q = SafeQuery_prepare(db, "SELECT * FROM users WHERE name = ?");
    SafeQuery_bind_text(q, 1, username);
    SafeQuery_exec(q);
    // P1 期望: 任何关联的 SQL injection Finding 被 exempted
    // 理由: SafeQuery 语义保证 prepared_statement
    SafeQuery_free(q);
}

// ── 对比: 未使用 SafeQuery 的代码 ──────────────────
void lookup_user_unsafe(sqlite3 *db, const char *username) {
    char query[512];
    sprintf(query, "SELECT * FROM users WHERE name = '%s'", username);
    sqlite3_exec(db, query, NULL, NULL, NULL);
    // ← 真漏洞: CWE-89 SQL injection
    // P1 期望: 这个 Finding 不被 exempted
}
