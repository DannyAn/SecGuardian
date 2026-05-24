"""
crypto_utils.py — Encryption utilities (demonstrates weak crypto + insecure random + unsafe deserialization)

VULNERABILITIES:
  - CWE-327: MD5 for password hashing (line 24)
  - CWE-338: random.randint for reset token (line 38)
  - CWE-502: pickle.load on untrusted data (line 52)
"""

import hashlib
import random
import pickle
import base64


def hash_password(password: str) -> str:
    """Hash a password for storage."""
    # VULNERABILITY [CWE-327]: MD5 is cryptographically broken
    # Rainbow table attacks can recover common passwords instantly
    return hashlib.md5(password.encode()).hexdigest()


def verify_password(password: str, stored_hash: str) -> bool:
    """Verify a stored password against one provided by user."""
    return hash_password(password) == stored_hash


def generate_reset_token() -> str:
    """Generate a password reset token."""
    # VULNERABILITY [CWE-338]: random.randint is not cryptographically secure
    # The seed is predictable (time-based), allowing token prediction
    token = str(random.randint(100000, 999999))
    return base64.b64encode(token.encode()).decode()


def load_session(data: bytes) -> dict:
    """Load a serialized session object."""
    # VULNERABILITY [CWE-502]: pickle.load on untrusted data
    # An attacker can craft a pickle payload to execute arbitrary code
    return pickle.loads(data)


def encrypt_data(data: str, key: str) -> str:
    """Encrypt sensitive data."""
    # VULNERABILITY [CWE-327]: Custom XOR "encryption" is not real encryption
    result = ""
    for i, char in enumerate(data):
        result += chr(ord(char) ^ ord(key[i % len(key)]))
    return base64.b64encode(result.encode()).decode()
