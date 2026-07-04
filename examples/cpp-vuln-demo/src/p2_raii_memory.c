/**
 * P2 Counter-Evidence Hunt — RAII Memory Management
 *
 * 场景: malloc/free 被 RAII 包装类管理。Detector 的 memory-leak 规则会标记
 * malloc() 没有对应的 free()，或 double-free 规则标记同一指针多次 free。
 * 但 ResourceHandle 类在构造函数中分配、析构函数中释放，保证生命周期安全。
 *
 * P2 应该做的事: 搜索到 ResourceHandle 的 RAII 模式（构造分配+析构释放），
 * 将 memory-leak 和 double-free Finding 标记为 counter_evidence_found。
 */

#include <stdlib.h>
#include <string.h>
#include <pthread.h>

// ── RAII 资源管理类 ───────────────────────────────
typedef struct {
    void *data;
    size_t size;
    int owned;  // 是否拥有内存所有权
} ResourceHandle;

// 构造函数: 分配内存
ResourceHandle *ResourceHandle_create(size_t size) {
    ResourceHandle *h = (ResourceHandle *)malloc(sizeof(ResourceHandle));
    h->data = malloc(size);     // ← Detector 会标记: 可能 memory-leak
    h->size = size;
    h->owned = 1;
    return h;
}

// 析构函数: 释放内存
void ResourceHandle_destroy(ResourceHandle *h) {
    if (h && h->owned) {
        free(h->data);           // ← 配对的 free
        h->data = NULL;
        h->owned = 0;
    }
    free(h);
}

// RAII 守卫: 栈上创建，作用域结束自动调用 destroy
// 类比 std::unique_ptr / std::lock_guard
#define ResourceHandle_scoped(name, size) \
    ResourceHandle *name = ResourceHandle_create(size); \
    int _##name##_cleanup __attribute__((cleanup(_scoped_destroy))) = 0

static void _scoped_destroy(int *flag) {
    (void)flag;  // cleanup attribute marker
}

// ── 业务代码使用 RAII ──────────────────────────────
void process_buffer(const void *input, size_t len) {
    ResourceHandle *handle = ResourceHandle_create(len);

    memcpy(handle->data, input, len);  // ← Detector 标记: buffer-overflow (memcpy with user len)
                                        // P2 应找到: ResourceHandle 的 RAII 保证 + create 时的 size 分配

    // 处理数据...
    process_data(handle->data, handle->size);

    ResourceHandle_destroy(handle);  // RAII 释放
    // P2 期望: memory-leak Finding 标记为 counter_evidence_found
    // 理由: RAII 保证 — ResourceHandle_destroy 在析构路径中释放所有内存
}

// ── 对比: 无 RAII 的裸指针 ─────────────────────────
void process_buffer_unsafe(const void *input, size_t len) {
    void *buf = malloc(len);  // ← Detector 标记: memory-leak (如果后面 return 路径没 free)
    if (!buf) return;         // ← 这里直接 return，泄漏了

    memcpy(buf, input, len);
    process_data(buf, len);
    free(buf);
    // P2 期望: 这个 Finding 不被 counter_evidence_found
    // 理由: 无 RAII 保证 — return 路径存在内存泄漏
}
