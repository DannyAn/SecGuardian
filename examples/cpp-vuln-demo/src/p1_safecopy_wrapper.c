/**
 * P1 Semantic Verification — SafeCopy Wrapper
 *
 * 场景: memcpy 使用了项目自定义的 SafeCopy 包装类。

 * `SafeCopy_copy(dst, src, n)` 中的 memcpy 调用。
 *
 * P1 应该做的事: 扫描项目 types 构建 Security Profile，发现 SafeCopy 类
 * 的语义保证是 bounds_checked，将任何使用 SafeCopy 的 Finding 标记为 exempted。
 */

#include <string.h>
#include <stddef.h>

// ── 项目自定义安全包装 ────────────────────────────
// SafeCopy: 保证目标缓冲区大小检查的 memcpy 包装
typedef struct {
    void *ptr;
    size_t capacity;
} SafeBuffer;

// SafeCopy_copy: 总是先检查 bounds 再调用 memcpy
// 语义保证: bounds_checked
void SafeCopy_copy(SafeBuffer *dst, const void *src, size_t n) {
    if (n > dst->capacity) {
        return;  // 拒绝溢出拷贝
    }
    memcpy(dst->ptr, src, n);
                                // P1 应该抑制: SafeCopy_copy 已保证 bounds_checked
}

// SafeCopy_strcpy: 安全版本的字符串拷贝
size_t SafeCopy_strcpy(SafeBuffer *dst, const char *src) {
    size_t len = strlen(src);
    if (len >= dst->capacity) {
        len = dst->capacity - 1;
    }
    memcpy(dst->ptr, src, len);
    ((char *)dst->ptr)[len] = '\0';
    return len;
}

// ── 业务代码使用 SafeCopy ─────────────────────────
void process_user_data(const char *user_input) {
    char buf_storage[256];
    SafeBuffer buf = {buf_storage, sizeof(buf_storage)};

    // 直接使用 SafeCopy —— 总是安全的
    SafeCopy_copy(&buf, user_input, strlen(user_input));

    // 理由: SafeCopy_copy 语义保证 bounds_checked
}

// ── 对比: 未使用 SafeCopy 的代码 ──────────────────
void process_user_data_unsafe(const char *user_input) {
    char buf[64];
    memcpy(buf, user_input, strlen(user_input));

    // 理由: 没有 SafeCopy 包装
}
