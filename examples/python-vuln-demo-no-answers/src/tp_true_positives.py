# TP — True Positives: 真实漏洞，必须检出
import os
import subprocess


def vulnerable_query(conn, user_id):

    cursor = conn.cursor()
    cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")  # 注入！


def vulnerable_exec(input_cmd):

    os.system(f"ping {input_cmd}")  # 注入！
