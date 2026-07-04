/**
 * P2 Counter-Evidence Hunt — Bounds Check Before Sink
 *
 * 场景: memcpy 前有显式的 if-guard bounds check。
 * Detector 的 memory.buffer-overflow 规则会标记 memcpy(dst, src, len)
 * 因为 len 来自用户输入。但紧邻的 if (len > sizeof(dst)) 检查已阻止溢出。
 *
 * P2 应该做的事: 搜索 memcpy 前的 bounds check 守卫代码，
 * 将标记为 counter_evidence_found。
 */

#include <string.h>
#include <stddef.h>

#define MAX_MSG_SIZE 512

// ── 带 bounds check 的安全 memcpy ──────────────────
void copy_message(void *dst, const void *src, size_t user_len) {
    // bounds check 在 memcpy 之前
    if (user_len > MAX_MSG_SIZE) {
        return;  // 拒绝超大输入
    }

    memcpy(dst, src, user_len);  // ← Detector 标记: CWE-120 buffer-overflow
                                  // P2 应该找到: line 24 if-guard 保证了 user_len <= MAX_MSG_SIZE
                                  // 只要 sizeof(dst) >= MAX_MSG_SIZE, 就是安全的

    // P2 期望: counter_evidence_found
    // 理由: bounds check at line 24 — user_len <= MAX_MSG_SIZE before memcpy
}

// 带显式 sizeof 检查的版本
void copy_to_stack_buffer(const void *src, size_t user_len) {
    char dst[256];

    if (user_len >= sizeof(dst)) {  // 直接用 sizeof 做 guard
        return;
    }

    memcpy(dst, src, user_len);  // ← Detector 标记，但 sizeof(dst) guard 保证了安全
    // P2 期望: counter_evidence_found
    // 理由: bounds check at line 37 — user_len < sizeof(dst)
}

// ── 对比: 无 bounds check ──────────────────────────
void copy_message_unsafe(void *dst, const void *src, size_t user_len) {
    memcpy(dst, src, user_len);  // ← 真漏洞: CWE-120, user_len 可能 > sizeof(dst)
    // P2 期望: counter_evidence_not_found
    // 理由: 无 bounds check
}
