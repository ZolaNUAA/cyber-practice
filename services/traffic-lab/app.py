from datetime import datetime
from flask import Flask, request

app = Flask(__name__)

def log(event):
    with open("/app/logs/traffic.log", "a") as f:
        f.write(f"{datetime.utcnow().isoformat()}Z {request.remote_addr} {event} ua={request.headers.get('User-Agent','-')}\n")

@app.get("/")
def index():
    log("normal_index")
    return "<h1>Traffic Lab</h1><p>Try /api/status and /beacon?id=101</p>"

@app.get("/api/status")
def status():
    log("api_status")
    return {"status": "ok", "service": "traffic-lab"}

@app.get("/beacon")
def beacon():
    log(f"suspicious_beacon id={request.args.get('id','-')}")
    return {"received": True}

app.run(host="0.0.0.0", port=8080)

