import secrets
import sqlite3
import subprocess
from datetime import datetime
from pathlib import Path

from flask import Flask, request, send_from_directory
from werkzeug.utils import secure_filename

app = Flask(__name__)

BASE_DIR = Path("/app")
DB_PATH = BASE_DIR / "exam.db"
UPLOAD_DIR = BASE_DIR / "uploads"
LOG_DIR = BASE_DIR / "logs"
UPLOAD_DIR.mkdir(exist_ok=True)
LOG_DIR.mkdir(exist_ok=True)


def log(event: str) -> None:
    with (LOG_DIR / "exam.log").open("a", encoding="utf-8") as f:
        f.write(f"{datetime.utcnow().isoformat()}Z {request.remote_addr} {event}\n")


def db() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    conn = db()
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY,
            username TEXT UNIQUE,
            password TEXT,
            role TEXT
        );
        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            author TEXT,
            body TEXT
        );
        """
    )
    rows = conn.execute("SELECT COUNT(*) AS c FROM users").fetchone()["c"]
    if rows == 0:
        conn.executemany(
            "INSERT INTO users(id, username, password, role) VALUES (?, ?, ?, ?)",
            [
                (1, "admin", "Admin123!", "admin"),
                (2, "alice", "Alice123!", "user"),
                (3, "bob", "Bob123!", "user"),
            ],
        )
    conn.commit()
    conn.close()


init_db()


@app.get("/")
def index():
    log("visit_index")
    return """
    <h1>Exam Repair Lab</h1>
    <ul>
      <li>/login?user=alice&password=Alice123!</li>
      <li>/ping?host=127.0.0.1</li>
      <li>/message</li>
      <li>/upload</li>
    </ul>
    """


@app.get("/login")
def login():
    user = request.args.get("user", "")
    password = request.args.get("password", "")
    query = f"SELECT id, username, role FROM users WHERE username = '{user}' AND password = '{password}'"
    log(f"login user={user}")
    row = db().execute(query).fetchone()
    if not row:
        return {"login": False}, 401
    return {"login": True, "id": row["id"], "username": row["username"], "role": row["role"]}


@app.get("/ping")
def ping():
    host = request.args.get("host", "127.0.0.1")
    log(f"ping host={host}")
    result = subprocess.run(
        f"ping -c 1 {host}",
        shell=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=5,
    )
    return f"<pre>{result.stdout}</pre>"


@app.get("/echo")
def echo():
    text = request.args.get("text", "")
    log("echo")
    return f"<h1>Echo</h1><p>{text}</p>"


@app.route("/message", methods=["GET", "POST"])
def message():
    conn = db()
    if request.method == "POST":
        author = request.form.get("author", "anonymous")
        body = request.form.get("body", "")
        log(f"message_post author={author}")
        conn.execute("INSERT INTO messages(author, body) VALUES (?, ?)", (author, body))
        conn.commit()
    rows = conn.execute("SELECT author, body FROM messages ORDER BY id DESC LIMIT 20").fetchall()
    items = "".join(f"<li><b>{r['author']}</b>: {r['body']}</li>" for r in rows)
    return f"""
    <h1>Messages</h1>
    <form method="post">
      <input name="author" value="student">
      <input name="body">
      <button>Post</button>
    </form>
    <ul>{items}</ul>
    """


@app.route("/upload", methods=["GET", "POST"])
def upload():
    if request.method == "GET":
        return """
        <h1>Upload</h1>
        <form method="post" enctype="multipart/form-data">
          <input type="file" name="file">
          <button>Upload</button>
        </form>
        """
    uploaded = request.files.get("file")
    if not uploaded:
        return "no file", 400
    name = secure_filename(uploaded.filename or f"upload-{secrets.token_hex(4)}")
    uploaded.save(UPLOAD_DIR / name)
    log(f"upload_ok filename={name}")
    return f"uploaded: <a href='/uploads/{name}'>{name}</a>"


@app.get("/uploads/<path:name>")
def get_upload(name):
    log(f"download filename={name}")
    return send_from_directory(UPLOAD_DIR, name)


@app.get("/health")
def health():
    return {"status": "ok"}


app.run(host="0.0.0.0", port=8080)
