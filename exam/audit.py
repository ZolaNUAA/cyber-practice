import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def append_audit(root: Path, state: dict, action: str, detail: dict[str, Any] | None = None) -> None:
    event = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "student_id": state.get("student_id"),
        "student_name": state.get("student_name"),
        "action": action,
        "detail": detail or {},
    }
    path = root / "audit-log.jsonl"
    with path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(event, ensure_ascii=False, sort_keys=True) + "\n")
