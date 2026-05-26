"""
webapp.py — Web security vulnerability examples (Python/Flask)

VULNERABILITIES:
  - CWE-89:  SQL injection via f-string (line 22)
  - CWE-77:  Command injection via os.system (line 33)
  - CWE-798: Hardcoded secret key (line 15)
  - CWE-79:  XSS — output without escaping (line 47)
  - CWE-918: SSRF — user-controlled URL fetch (line 58)
  - CWE-352: CSRF — no token on /transfer (line 71)
  - CWE-287: Auth bypass — missing auth check (line 83)
  - CWE-639: IDOR — no ownership check (line 95)
  - CWE-611: XXE — insecure XML parsing (line 109)
  - CWE-347: JWT misuse — weak secret (line 121)
  - CWE-601: Open redirect — user input in Location (line 133)
  - CWE-94:  Code injection — eval on user input (line 145)
"""

import os
import sqlite3
from flask import Flask, request, make_response
import xml.etree.ElementTree as ET
import jwt
import requests

# VULNERABILITY [CWE-798]: Hardcoded secret in source code
SECRET_KEY = "my-super-secret-key-12345"
DATABASE_URL = "mysql://admin:password123@localhost:3306/mydb"

app = Flask(__name__)
app.config['SECRET_KEY'] = SECRET_KEY


def get_db():
    conn = sqlite3.connect('users.db')
    return conn


@app.route('/user')
def get_user():
    username = request.args.get('username', '')
    conn = get_db()
    cursor = conn.cursor()

    # VULNERABILITY [CWE-89]: SQL injection via f-string
    query = f"SELECT * FROM users WHERE username = '{username}'"
    cursor.execute(query)

    user = cursor.fetchone()
    conn.close()
    if user:
        return f"User found: {user}"
    return "User not found"


@app.route('/ping')
def ping_host():
    host = request.args.get('host', 'localhost')
    # VULNERABILITY [CWE-77]: Command injection via os.system
    result = os.system(f"ping -c 1 {host}")
    return f"Ping result: {result}"


# ── CWE-79: XSS ──────────────────────────────────────────────
@app.route("/search")
def search_xss():
    query = request.args.get("q", "")
    # VULNERABILITY [CWE-79]: XSS — user input rendered without escaping
    return f"<html><body>Search results for: {query}</body></html>"

# ── CWE-918: SSRF ────────────────────────────────────────────
@app.route("/fetch")
def fetch_url():
    url = request.args.get("url", "")
    # VULNERABILITY [CWE-918]: SSRF — user controls fetch target
    resp = requests.get(url)
    return resp.text

# ── CWE-352: CSRF ────────────────────────────────────────────
@app.route("/transfer", methods=["POST"])
def transfer_money():
    amount = request.form.get("amount", "0")
    # VULNERABILITY [CWE-352]: CSRF — no CSRF token validation
    execute_transfer(amount)
    return "OK"

def execute_transfer(amount):
    print(f"Transferring ${amount}")

# ── CWE-287: Auth Bypass ─────────────────────────────────────
@app.route("/admin")
def admin_panel():
    # VULNERABILITY [CWE-287]: Auth bypass — no auth check
    return "<html><body>Admin Panel — secret data</body></html>"

# ── CWE-639: IDOR ───────────────────────────────────────────
@app.route("/api/user/<int:user_id>/profile")
def get_user_profile(user_id):
    # VULNERABILITY [CWE-639]: IDOR — no ownership check
    profile = query_profile(user_id)
    return profile

def query_profile(uid):
    return f"<profile><id>{uid}</id><ssn>123-45-6789</ssn></profile>"

# ── CWE-611: XXE ────────────────────────────────────────────
@app.route("/api/parse_xml", methods=["POST"])
def parse_xml():
    xml_data = request.data
    # VULNERABILITY [CWE-611]: XXE — insecure XML parser (external entities enabled)
    parser = ET.XMLParser()
    tree = ET.fromstring(xml_data, parser)
    return "parsed"

# ── CWE-347: JWT Misuse ─────────────────────────────────────
@app.route("/api/login", methods=["POST"])
def login():
    username = request.json.get("username")
    # VULNERABILITY [CWE-347]: JWT with weak/guessable secret
    token = jwt.encode({"user": username, "admin": True},
                        "secret", algorithm="HS256")
    return {"token": token}

# ── CWE-601: Open Redirect ──────────────────────────────────
@app.route("/redirect")
def redirect():
    next_url = request.args.get("next", "/")
    # VULNERABILITY [CWE-601]: Open redirect — user controls redirect target
    resp = make_response("", 302)
    resp.headers["Location"] = next_url
    return resp

# ── CWE-94: Code Injection ──────────────────────────────────
@app.route("/api/eval", methods=["POST"])
def eval_code():
    expr = request.json.get("expression", "")
    # VULNERABILITY [CWE-94]: Code injection — eval on user input
    result = eval(expr)
    return {"result": result}


# ── CWE-20: Improper Input Validation ──────────────────────
@app.route("/api/validate")
def validate_input():
    value = request.args.get("value", "")
    # VULNERABILITY [CWE-20]: Input validation — no check on value
    return process_value(value)

def process_value(v):
    return f"Processed: {v}"

# ── CWE-434: Unrestricted File Upload ──────────────────────
@app.route("/api/upload", methods=["POST"])
def upload_file():
    f = request.files.get("file")
    # VULNERABILITY [CWE-434]: No type/size validation on upload
    f.save("/uploads/" + f.filename)
    return "uploaded"

# ── CWE-862: Missing Authorization ─────────────────────────
@app.route("/api/admin/dashboard")
def admin_dashboard():
    # VULNERABILITY [CWE-862]: No role check for admin function
    return "Sensitive admin data"

# ── CWE-306: Missing Authentication ────────────────────────
@app.route("/api/profile")
def profile():
    # VULNERABILITY [CWE-306]: No authentication required
    return get_user_data()

def get_user_data():
    return '{"email":"user@example.com"}'

# ── CWE-276: Insecure Permissions ──────────────────────────
def write_config_file():
    # VULNERABILITY [CWE-276]: Insecure default permissions
    with open("/etc/app/prod.ini", "w") as f:
        f.write("[default]\nkey=value")

# ── CWE-400: Resource Exhaustion ──────────────────────────
@app.route("/api/process", methods=["POST"])
def process_items():
    items = request.json.get("items", [])
    # VULNERABILITY [CWE-400]: No limit on items size
    for item in items:
        expensive_op(item)
    return "OK"

def expensive_op(item):
    pass


if __name__ == '__main__':
    app.run(debug=True)
