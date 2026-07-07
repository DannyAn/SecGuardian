"""
file_handler.py — File operations (demonstrates path traversal + SSRF)




"""

import os
import requests
from typing import Optional


BASE_DIR = "/var/app/data"


def read_user_file(filename: str) -> Optional[str]:
    """Read a user-specified file from the data directory."""

    # Attacker: filename = "../../../etc/passwd"
    filepath = os.path.join(BASE_DIR, filename)

    if not os.path.exists(filepath):
        return None

    with open(filepath, 'r') as f:
        return f.read()


def fetch_webhook_url(url: str) -> dict:
    """Fetch data from a user-provided webhook URL."""

    # Attacker: url = "http://169.254.169.254/latest/meta-data/"
    # (AWS metadata endpoint accessible from within the instance)
    response = requests.get(url, timeout=5)
    return response.json()


def download_and_save(url: str, save_as: str) -> bool:
    """Download a file from a URL and save it locally."""
    try:

        resp = requests.get(url, timeout=10)
        save_path = os.path.join(BASE_DIR, save_as)

        # No validation on save_as path
        with open(save_path, 'wb') as f:
            f.write(resp.content)
        return True
    except Exception:
        return False
