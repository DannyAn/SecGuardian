# TP — True Positives: 真实漏洞，必须检出
import os
import subprocess


def vulnerable_query(conn, user_id):
    """TP-01: SQL 注入 — f-string 拼接"""
    cursor = conn.cursor()
    cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")  # 注入！


def vulnerable_exec(input_cmd):
    """TP-02: 命令注入 — os.system 未过滤"""
    os.system(f"ping {input_cmd}")  # 注入！
