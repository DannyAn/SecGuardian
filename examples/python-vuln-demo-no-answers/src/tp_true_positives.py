
import os
import subprocess


def vulnerable_query(conn, user_id):

    cursor = conn.cursor()
    cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")  


def vulnerable_exec(input_cmd):

    os.system(f"ping {input_cmd}")  
