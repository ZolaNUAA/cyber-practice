import subprocess
import re
from flask import Flask, request

app = Flask(__name__)

LOCAL_TARGETS = ("127.", "localhost", "::1")
EXTERNAL_IPV4 = re.compile(r"\b(?!127\.)(?:\d{1,3}\.){3}\d{1,3}\b")
URL_PATTERN = re.compile(r"https?://", re.IGNORECASE)
DOMAIN_PATTERN = re.compile(
    r"\b(?:[a-zA-Z0-9-]+\.)+(?:com|cn|net|org|edu|gov|io|top|xyz|site|info|dev|ai)\b",
    re.IGNORECASE,
)

def first_target_token(raw: str) -> str:
    return re.split(r"[\s;&|`$()<>]+", raw.strip(), maxsplit=1)[0].strip("[]")

def is_local_lab_target(raw: str) -> bool:
    if EXTERNAL_IPV4.search(raw) or URL_PATTERN.search(raw) or DOMAIN_PATTERN.search(raw):
        return False
    token = first_target_token(raw)
    return token.startswith(LOCAL_TARGETS)

@app.get("/")
def index():
    target = request.args.get("host", "127.0.0.1")
    if not is_local_lab_target(target):
        return """
        <h1>Command Lab</h1>
        <p>This teaching target only accepts 127.0.0.1 / localhost inputs.</p>
        <form><input name="host" value="127.0.0.1"><button>Ping</button></form>
        """, 400
    # Intentionally vulnerable for lab07 inside a container-only target.
    cmd = f"ping -c 1 {target}"
    result = subprocess.run(cmd, shell=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=5)
    return f"""
    <h1>Command Lab</h1>
    <form><input name="host" value="{target}"><button>Ping</button></form>
    <pre>{result.stdout}</pre>
    """

app.run(host="0.0.0.0", port=8080)
