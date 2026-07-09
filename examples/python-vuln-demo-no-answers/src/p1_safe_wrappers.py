

class SafeQuery:
    """强制参数化查询的封装"""
    
    @staticmethod
    def query(conn, sql, *params):
        cursor = conn.cursor()
        cursor.execute(sql, params)  # 强制参数化
        return cursor.fetchall()


class SafeFileHandler:
    """安全文件处理器，内建路径清洗"""
    
    ALLOWED_CHARS = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/_-.")
    
    @classmethod
    def read(cls, base_dir, filename):
        safe_name = "".join(c for c in filename if c in cls.ALLOWED_CHARS)
        import os
        full_path = os.path.normpath(os.path.join(base_dir, safe_name))
        if not full_path.startswith(os.path.normpath(base_dir)):
            raise ValueError("Path traversal detected")
        with open(full_path) as f:
            return f.read()


def find_user_safe(conn, user_id):

    return SafeQuery.query(conn, "SELECT * FROM users WHERE id = %s", user_id)


def read_config_safe(base_dir, name):

    return SafeFileHandler.read(base_dir, name)
