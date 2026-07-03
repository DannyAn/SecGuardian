// P2 — Counter-Evidence: 反证搜寻，应被抑制
import java.util.concurrent.locks.*;
import java.util.concurrent.atomic.*;

class ResourceHandle implements AutoCloseable {
    private byte[] buffer = new byte[1024];
    public void close() { buffer = null; }  // RAII
}

public class p2_counter_evidence {
    private final Lock mutex = new ReentrantLock();
    private final AtomicInteger counter = new AtomicInteger(0);
    private int sharedState = 0;
    private int fileHandle = 0;

    // P2-01: try-with-resources 自动释放 — 非泄漏
    public void safeResource() {
        try (ResourceHandle h = new ResourceHandle()) {
            // 使用资源，自动 close()
        }
    }

    // P2-02: Lock 保护共享状态 — 非竞争
    public void safeIncrement() {
        mutex.lock();
        try {
            sharedState++;
        } finally {
            mutex.unlock();
        }
    }

    // P2-03: AtomicInteger 线程安全 — 非竞争
    public int safeCounter() {
        return counter.incrementAndGet();
    }

    // P2-04: 同步方法 — 非竞争
    public synchronized void syncWrite(String data) {
        // 同步写入
    }
}
