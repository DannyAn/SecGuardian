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

        with self._lock:
            self._value += 1
            return self._value

    def safe_resource(self):

        with ResourceHandle() as h:
            _ = len(h.buffer)

    def safe_write(self, data):

        self._lock.acquire()
        try:
            # 写入操作
            pass
        finally:
            self._lock.release()
