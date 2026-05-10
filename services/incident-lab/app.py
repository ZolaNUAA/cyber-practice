from datetime import datetime
from flask import Flask, request

app = Flask(__name__)

def log(event):
    with open("/app/logs/incident.log", "a") as f:
        f.write(f"{datetime.utcnow().isoformat()}Z {request.remote_addr} {event}\n")

@app.get("/")
def index():
    log("visit_index")
    return "<h1>Incident Lab</h1><p>Use logs and evidence files to build the timeline.</p><p>Try /login?user=admin&password=wrong</p>"

@app.get("/login")
def login():
    user = request.args.get("user", "-")
    ok = user == "dev" and request.args.get("password") == "Dev123"
    log(f"login user={user} result={'success' if ok else 'failed'}")
    return {"login": ok}

@app.get("/admin/export")
def export():
    log("suspicious_admin_export")
    return "export started"

app.run(host="0.0.0.0", port=8080)

