"""
crypto_utils.py — Encryption utilities (demonstrates weak crypto + insecure random + unsafe deserialization)





"""

import hashlib
import random
import pickle
import base64


def hash_password(password: str) -> str:
    """Hash a password for storage."""

    # Rainbow table attacks can recover common passwords instantly
    return hashlib.md5(password.encode()).hexdigest()


def verify_password(password: str, stored_hash: str) -> bool:
    """Verify a stored password against one provided by user."""
    return hash_password(password) == stored_hash


def generate_reset_token() -> str:
    """Generate a password reset token."""

    # The seed is predictable (time-based), allowing token prediction
    token = str(random.randint(100000, 999999))
    return base64.b64encode(token.encode()).decode()


def load_session(data: bytes) -> dict:
    """Load a serialized session object."""

    # An attacker can craft a pickle payload to execute arbitrary code
    return pickle.loads(data)


def encrypt_data(data: str, key: str) -> str:
    """Encrypt sensitive data."""

    result = ""
    for i, char in enumerate(data):
        result += chr(ord(char) ^ ord(key[i % len(key)]))
    return base64.b64encode(result.encode()).decode()
