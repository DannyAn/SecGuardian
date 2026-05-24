"""
webapp.py — Simple Flask web application (demonstrates SQL injection + command injection + SSTI)

VULNERABILITIES:
  - CWE-89:  SQL injection via f-string (line 41)
  - CWE-77:  Command injection via os.system (line 56)
  - CWE-1336: SSTI via render_template_string (line 69)
  - CWE-798: Hardcoded secret key (line 17)
"""

import os
import sqlite3
from flask import Flask, request, render_template_string

# VULNERABILITY [CWE-798]: Hardcoded secret
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
    # Attacker: /user?username=admin' OR '1'='1' --
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
    # Attacker: /ping?host=localhost; cat /etc/passwd
    result = os.system(f"ping -c 1 {host}")

    return f"Ping result: {result}"


@app.route('/welcome')
def welcome():
    name = request.args.get('name', 'Guest')

    # VULNERABILITY [CWE-1336]: SSTI via render_template_string
    # Attacker: /welcome?name={{ config }}
    template = f"<h1>Welcome, {name}!</h1>"
    return render_template_string(template)


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')
