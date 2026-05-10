import subprocess
from flask import Flask, request

app = Flask(__name__)

@app.get("/")
def index():
    target = request.args.get("host", "127.0.0.1")
    # Intentionally vulnerable for lab07 inside a container-only target.
    cmd = f"ping -c 1 {target}"
    result = subprocess.run(cmd, shell=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=5)
    return f"""
    <h1>Command Lab</h1>
    <form><input name="host" value="{target}"><button>Ping</button></form>
    <pre>{result.stdout}</pre>
    """

app.run(host="0.0.0.0", port=8080)

