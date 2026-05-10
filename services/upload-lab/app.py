from pathlib import Path
from datetime import datetime
from flask import Flask, request, send_from_directory
from werkzeug.utils import secure_filename

app = Flask(__name__)
UPLOAD_DIR = Path("/app/uploads")
LOG_DIR = Path("/app/logs")
UPLOAD_DIR.mkdir(exist_ok=True)
LOG_DIR.mkdir(exist_ok=True)

def log(message: str) -> None:
    with (LOG_DIR / "upload.log").open("a") as f:
        f.write(f"{datetime.utcnow().isoformat()}Z {request.remote_addr} {message}\n")

@app.get("/")
def index():
    return """
    <h1>Upload Lab</h1>
    <p>Local training service. Investigate validation and execution risks.</p>
    <form action="/upload" method="post" enctype="multipart/form-data">
      <input type="file" name="file">
      <button type="submit">Upload</button>
    </form>
    <p><a href="/uploads">List uploads</a></p>
    """

@app.post("/upload")
def upload():
    uploaded = request.files.get("file")
    if not uploaded:
        log("upload_failed no_file")
        return "no file", 400
    name = secure_filename(uploaded.filename or "unnamed")
    uploaded.save(UPLOAD_DIR / name)
    log(f"upload_ok filename={name}")
    return f"uploaded: <a href='/uploads/{name}'>{name}</a>"

@app.get("/uploads")
def list_uploads():
    items = "".join(f"<li><a href='/uploads/{p.name}'>{p.name}</a></li>" for p in UPLOAD_DIR.iterdir())
    return f"<h1>Uploads</h1><ul>{items}</ul>"

@app.get("/uploads/<path:name>")
def get_upload(name):
    log(f"download filename={name}")
    return send_from_directory(UPLOAD_DIR, name)

app.run(host="0.0.0.0", port=8080)

