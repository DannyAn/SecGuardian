/**
 * P3 Adjudication Court — 裁决边界案例
 *
 * 场景: 存在部分保护但不足以完全消除风险的代码。
 * Detector 会标记这些为漏洞，P1 Semantic 找不到安全框架，P2 找到部分反证但不充分。
 * P3 Court 需要综合判断。
 *
 * 三个用例:
 *   1. 有输入校验但不是白名单 (regex 黑名单过滤)
 *   2. 有锁但只保护了部分操作
 *   3. 有 cleanup 函数但需要手动调用
 */

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <regex.h>
#include <pthread.h>

// ── 用例 1: 输入有校验，但不是白名单 ─────────────────
// Detector 标记: system.command-injection (system() with user input)
// P1: no_exemption — 项目没有 SafeExec 包装
// P2: 找到输入过滤 (regex 去除分号) 但不充分 — 未过滤 &&, |, $(), backtick

int is_safe_input(const char *input) {
    // 黑名单过滤 —— 只去除了分号，但 &&, ||, $(), `` 都可以注入
    regex_t regex;
    regcomp(&regex, "[;&]", REG_EXTENDED);
    int result = regexec(&regex, input, 0, NULL, 0);
    regfree(&regex);
    return result == REG_NOMATCH;  // 没匹配到分号就是"安全"
}

void run_admin_command(const char *user_cmd) {
    if (!is_safe_input(user_cmd)) {
        return;
    }
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "admin_tool %s", user_cmd);  // ← Detector 标记: CWE-77
    system(cmd);  // ← 即使过滤了分号，user_cmd 可以包含 "&& rm -rf /"
    // P3 期望: suspected (非 confirmed, 非 dismissed)
    // 理由: is_safe_input 提供了部分保护但不充分 (黑名单而非白名单)
    //       Prosecutor: system() 仍有注入路径 (&&, ||, $())
    //       Defender: is_safe_input 减少了攻击面
    //       Judge: suspected — 需要人工确认
}

// ── 用例 2: 锁保护了部分操作 ────────────────────────
static pthread_mutex_t g_mutex = PTHREAD_MUTEX_INITIALIZER;
static int g_account_balance = 1000;

int check_and_transfer(int amount) {
    // 读取余额有锁...
    pthread_mutex_lock(&g_mutex);
    int current = g_account_balance;
    pthread_mutex_unlock(&g_mutex);

    // ...但 TOCTOU: 在 lock 和 transfer 之间有 gap
    if (current >= amount) {
        // 另一个线程可能已经在这期间修改了余额
        g_account_balance -= amount;  // ← Detector 标记: CWE-362 race-condition
        return 0;
    }
    return -1;
    // P3 期望: suspected
    // 理由: 有 mutex 但未保护完整的 check-then-act 操作 (TOCTOU)
    //       Prosecutor: g_account_balance -= amount 在两个锁之间，存在竞态窗口
    //       Defender: mutex 保护了读取余额的操作
    //       Judge: suspected — 锁的范围不够，但代码意图是线程安全的
}

// ── 用例 3: Cleanup 函数存在但需手动调用 ─────────────
typedef struct {
    void *buffer;
    int initialized;
} FileCache;

FileCache *FileCache_create(void) {
    FileCache *fc = (FileCache *)malloc(sizeof(FileCache));
    fc->buffer = malloc(4096);
    fc->initialized = 1;
    return fc;
}

void FileCache_cleanup(FileCache *fc) {
    if (fc->initialized) {
        free(fc->buffer);  // ← Detector 标记: double-free (如果 cleanup 被多次调用且 initialized 未重置)
        fc->buffer = NULL;
    }
    free(fc);
}

// 使用 FileCache —— 手动调用 cleanup
void process_file(const char *path) {
    FileCache *fc = FileCache_create();
    // ... 使用 fc ...
    FileCache_cleanup(fc);  // ← 如果这里有 early return 路径，cleanup 不会被调用
    // P3 期望: suspected
    // 理由: 有 cleanup 函数 (类似 RAII) 但不是自动调用的 (不是析构函数)
    //       Prosecutor: 如果有 early return，cleanup 被跳过 → memory-leak
    //       Defender: 在当前路径中 cleanup 被正确调用
    //       Judge: suspected — 设计接近 RAII 但未强制执行
}
