"""
webapp.py — Web security vulnerability examples (Python/Flask)














"""

import os
import sqlite3
from flask import Flask, request, make_response
import xml.etree.ElementTree as ET
import jwt
import requests


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

    result = os.system(f"ping -c 1 {host}")
    return f"Ping result: {result}"



@app.route("/search")
def search_xss():
    query = request.args.get("q", "")

    return f"<html><body>Search results for: {query}</body></html>"


@app.route("/fetch")
def fetch_url():
    url = request.args.get("url", "")

    resp = requests.get(url)
    return resp.text


@app.route("/transfer", methods=["POST"])
def transfer_money():
    amount = request.form.get("amount", "0")

    execute_transfer(amount)
    return "OK"

def execute_transfer(amount):
    print(f"Transferring ${amount}")


@app.route("/admin")
def admin_panel():

    return "<html><body>Admin Panel — secret data</body></html>"


@app.route("/api/user/<int:user_id>/profile")
def get_user_profile(user_id):

    profile = query_profile(user_id)
    return profile

def query_profile(uid):
    return f"<profile><id>{uid}</id><ssn>123-45-6789</ssn></profile>"


@app.route("/api/parse_xml", methods=["POST"])
def parse_xml():
    xml_data = request.data

    parser = ET.XMLParser()
    tree = ET.fromstring(xml_data, parser)
    return "parsed"


@app.route("/api/login", methods=["POST"])
def login():
    username = request.json.get("username")

    token = jwt.encode({"user": username, "admin": True},
                        "secret", algorithm="HS256")
    return {"token": token}


@app.route("/redirect")
def redirect():
    next_url = request.args.get("next", "/")

    resp = make_response("", 302)
    resp.headers["Location"] = next_url
    return resp


@app.route("/api/eval", methods=["POST"])
def eval_code():
    expr = request.json.get("expression", "")

    result = eval(expr)
    return {"result": result}



@app.route("/api/validate")
def validate_input():
    value = request.args.get("value", "")

    return process_value(value)

def process_value(v):
    return f"Processed: {v}"


@app.route("/api/upload", methods=["POST"])
def upload_file():
    f = request.files.get("file")

    f.save("/uploads/" + f.filename)
    return "uploaded"


@app.route("/api/admin/dashboard")
def admin_dashboard():

    return "Sensitive admin data"


@app.route("/api/profile")
def profile():

    return get_user_data()

def get_user_data():
    return '{"email":"user@example.com"}'


def write_config_file():

    with open("/etc/app/prod.ini", "w") as f:
        f.write("[default]\nkey=value")


@app.route("/api/process", methods=["POST"])
def process_items():
    items = request.json.get("items", [])

    for item in items:
        expensive_op(item)
    return "OK"

def expensive_op(item):
    pass


if __name__ == '__main__':
    app.run(debug=True)
