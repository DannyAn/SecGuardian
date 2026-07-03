# P2 — Counter-Evidence: 反证搜寻
import threading
import os


class ResourceHandle:
    """RAII 资源句柄"""
    def __enter__(self):
        self.buffer = bytearray(1024)
        return self
    def __exit__(self, *args):
        self.buffer = None  # 自动释放


class SafeCounter:
    def __init__(self):
        self._lock = threading.Lock()
        self._value = 0
        self._file = None

    def safe_increment(self):
        """P2-02: Lock 保护 — 非竞争"""
        with self._lock:
            self._value += 1
            return self._value

    def safe_resource(self):
        """P2-01: with 语句自动释放 — 非泄漏"""
        with ResourceHandle() as h:
            _ = len(h.buffer)

    def safe_write(self, data):
        """P2-04: with 锁 + try/finally — 非竞争"""
        self._lock.acquire()
        try:
            # 写入操作
            pass
        finally:
            self._lock.release()
