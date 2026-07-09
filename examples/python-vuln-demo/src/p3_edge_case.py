# P3 — Edge Cases: 部分保护不充分
import subprocess
import threading


class CommandExecutor:

    
    BLACKLIST = ["rm", "shutdown", "del", "format"]
    
    def exec(self, cmd: str) -> str:
        cmd = cmd.strip()
        for bad in self.BLACKLIST:
            if bad in cmd:
                return "blocked"
        # 仍有绕过风险：编码、路径组合等
        return subprocess.check_output(cmd, shell=True).decode()


class ConfigManager:

    
    def __init__(self):
        self._loaded = False
        self._lock = threading.Lock()
    
    def reload(self):
        if not self._loaded:             # 检查
            with self._lock:             # 加锁
                self._load_config()
                self._loaded = True
    
    def _load_config(self):
        pass
