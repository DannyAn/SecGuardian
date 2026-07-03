# P0 — 安全函数，不应产生 Finding
import secrets
import subprocess
import logging
import ast
import os

logger = logging.getLogger(__name__)


def safe_query(conn, user_id):
    """P0-01: 参数化查询 — 安全"""
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
    return cursor.fetchall()


def generate_token():
    """P0-02: secrets 模块 — 密码学安全"""
    return secrets.token_hex(32)


def safe_exec():
    """P0-03: subprocess.run 列表参数 — 非注入"""
    subprocess.run(["ls", "-l"], capture_output=True)


def log_event(user):
    """P0-04: logging %s 占位符 — 安全"""
    logger.info("User login: %s", user)


def safe_eval(data):
    """P0-05: ast.literal_eval — 安全求值"""
    return ast.literal_eval(data)


def encode_data(data: bytes) -> str:
    """P0-06: 安全编码"""
    import base64
    return base64.b64encode(data).decode()
