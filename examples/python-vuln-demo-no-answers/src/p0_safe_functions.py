
import secrets
import subprocess
import logging
import ast
import os

logger = logging.getLogger(__name__)


def safe_query(conn, user_id):

    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))
    return cursor.fetchall()


def generate_token():

    return secrets.token_hex(32)


def safe_exec():

    subprocess.run(["ls", "-l"], capture_output=True)


def log_event(user):

    logger.info("User login: %s", user)


def safe_eval(data):

    return ast.literal_eval(data)


def encode_data(data: bytes) -> str:

    import base64
    return base64.b64encode(data).decode()
