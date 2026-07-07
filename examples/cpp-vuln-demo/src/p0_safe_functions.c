/**
 * P0 — 安全函数用例 (Detector EXCLUDE 层)
 *
 * 这些用例使用 Annex K 安全函数和业界标准安全替代方案。
 * Detector 的 EXCLUDE 模式应该在匹配阶段就排除这些代码，
 * 不产生任何 Finding。如果产生了 Finding（跨平台/Regex 回退精度不足），
 * P1 Semantic 或 P2 Counter-Evidence 应作为第二道防线抑制。
 *
 * 测试目标: 验证 Detector EXCLUDE 模式 + P1/P2 多道防线不产生误报。
 */

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sqlite3.h>

// ── Annex K 安全函数 (C11) ─────────────────────────
void safe_annex_k_functions(void) {
    char dst[256];
    char src[] = "user input";

    // memcpy_s — Annex K 安全版本，自带 dst size
    memcpy_s(dst, sizeof(dst), src, strlen(src) + 1);
    // 预期: Detector EXCLUDE: memcpy_s\(dst,\s*sizeof\(dst\)  → 不产生 Finding

    // strcpy_s — Annex K 安全版本
    strcpy_s(dst, sizeof(dst), src);
    // 预期: Detector EXCLUDE: strcpy_s\(dst,\s*sizeof\(dst\)  → 不产生 Finding

    // sprintf_s — Annex K 安全版本
    sprintf_s(dst, sizeof(dst), "value: %s", src);
    // 预期: Detector EXCLUDE: sprintf_s\(buf,\s*sizeof\(buf\)  → 不产生 Finding

    // strcat_s — Annex K 安全版本
    strcat_s(dst, sizeof(dst), "_suffix");
    // 预期: Detector EXCLUDE: strcat_s\(dst,\s*sizeof\(dst\)  → 不产生 Finding
}

// ── 标准库安全替代 ──────────────────────────────────
void safe_standard_functions(void) {
    char dst[256];
    char src[] = "user input";
    int written;

    // snprintf + sizeof + 返回值检查
    written = snprintf(dst, sizeof(dst), "value: %s", src);
    if (written < 0 || (size_t)written >= sizeof(dst)) {
        return;  // 截断检测
    }
    // 预期: Detector EXCLUDE: snprintf\([^)]*sizeof\([^)]*\).*\n.*if\s*\(.*written  → 不产生 Finding
    // 若跨平台回退精度不足产生 Finding → P2 counter_evidence_found (bounds_check + sizeof guard)

    // strncpy — 带 sizeof 限制（虽然是 Annex K 之前的标准但常用）
    strncpy(dst, src, sizeof(dst) - 1);
    dst[sizeof(dst) - 1] = '\0';  // 手动 null terminate
    // 预期: 可能产生 Finding (strncpy 不在 EXCLUDE 白名单)
    // P2 应找到: sizeof(dst) bounds check → counter_evidence_found
}

// ── 安全命令执行 ────────────────────────────────────
void safe_command_execution(void) {
    // execve — 不经过 shell，参数数组传递
    char *argv[] = {"ping", "-c", "1", "127.0.0.1", NULL};
    execve("/bin/ping", argv, NULL);
    // 预期: Detector EXCLUDE: execve\(  → 不产生 Finding

    // execv — 同样不经过 shell
    char *argv2[] = {"ls", "-la", NULL};
    execv("/bin/ls", argv2);
    // 预期: Detector EXCLUDE: execv\(  → 不产生 Finding
}

// ── POSIX 安全替代 ──────────────────────────────────
#ifdef __unix__
#include <bsd/string.h>
void safe_posix_functions(void) {
    char dst[256];
    char src[] = "user input";

    // strlcpy — BSD 安全版本，保证 null terminate
    strlcpy(dst, src, sizeof(dst));
    // 预期: 可能不在 EXCLUDE 白名单中
    // P2 应找到: sizeof(dst) 参数 → counter_evidence_found (bounds_check)

    // strlcat — BSD 安全版本
    strlcat(dst, "_suffix", sizeof(dst));
    // 预期: 同上
}
#endif

// ── 安全 SQL 查询 ───────────────────────────────────
void safe_sql_query(sqlite3 *db, const char *username) {
    sqlite3_stmt *stmt;
    // 参数化查询 — sqlite3_bind_text
    sqlite3_prepare_v2(db, "SELECT * FROM users WHERE name = ?", -1, &stmt, NULL);
    sqlite3_bind_text(stmt, 1, username, -1, SQLITE_TRANSIENT);
    sqlite3_step(stmt);
    sqlite3_finalize(stmt);
    // 预期: Detector EXCLUDE: sqlite3_bind_text|PreparedStatement.*setString  → 不产生 Finding
}
