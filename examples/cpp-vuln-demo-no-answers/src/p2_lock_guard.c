/**
 * P2 Counter-Evidence Hunt — Mutex Lock Guard
 *
 * 场景: pthread_mutex_lock/unlock 被 RAII 风格的 LockGuard 包装。

 * 但 LockGuard 在作用域内持有锁，保证了互斥访问。
 *
 * P2 应该做的事: 搜索到 LockGuard 模式（构造函数 lock + 析构函数 unlock），
 * 将 race-condition Finding 标记为 counter_evidence_found。
 */

#include <pthread.h>

static pthread_mutex_t g_mutex = PTHREAD_MUTEX_INITIALIZER;
static int g_counter = 0;

// ── RAII LockGuard ─────────────────────────────────
typedef struct {
    pthread_mutex_t *mutex;
} LockGuard;

LockGuard LockGuard_create(pthread_mutex_t *m) {
    LockGuard g;
    g.mutex = m;
    pthread_mutex_lock(m);  // ← 构造函数中加锁
    return g;
}

void LockGuard_release(LockGuard *g) {
    pthread_mutex_unlock(g->mutex);  // ← 析构函数中解锁
}

// ── 业务代码使用 LockGuard ─────────────────────────
void increment_counter(void) {
    LockGuard guard = LockGuard_create(&g_mutex);

    g_counter++;
                  // P2 应该找到: LockGuard 保证了 mutex 互斥访问
    // 可能还有其他操作...

    LockGuard_release(&guard);

    // 理由: LockGuard 保证 — counter++ 在 mutex 保护下执行
}

// ── 对比: 无锁保护 ─────────────────────────────────
static int g_unprotected = 0;

void increment_unprotected(void) {
    g_unprotected++;

    // 理由: 无 mutex 保护，确实存在 race condition
}
