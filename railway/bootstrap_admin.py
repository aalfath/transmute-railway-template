"""Create Transmute's first admin from TRANSMUTE_ADMIN_USERNAME / TRANSMUTE_ADMIN_PASSWORD.

Upstream makes whoever first opens the app the admin. On a public Railway URL that
could be a stranger, so the template creates the admin before the server starts.
Runs on every boot; does nothing once any (non-guest) user exists.
"""
import os
import sqlite3
import sys
import uuid

sys.path.insert(0, "/app/backend")

from core.auth import get_password_hash_str  # noqa: E402
from db import UserDB  # noqa: E402

username = os.environ.get("TRANSMUTE_ADMIN_USERNAME", "").strip() or "admin"
password = os.environ.get("TRANSMUTE_ADMIN_PASSWORD", "")

db = UserDB()
if db.has_non_guest_users():
    print("[railway] users already exist, admin bootstrap skipped", flush=True)
    sys.exit(0)

if len(password) < 8:
    print(
        "[railway] no users yet and TRANSMUTE_ADMIN_PASSWORD is missing or shorter than 8 characters; "
        "refusing to start, because the first visitor would become admin",
        file=sys.stderr,
        flush=True,
    )
    sys.exit(1)

try:
    db.insert_user({
        "uuid": str(uuid.uuid4()),
        "username": username,
        "email": None,
        "full_name": "Administrator",
        "hashed_password": get_password_hash_str(password),
        "role": "admin",
        "disabled": False,
    })
except sqlite3.IntegrityError:
    print("[railway] admin already exists", flush=True)
    sys.exit(0)

print(f"[railway] created admin user '{username}' (password: TRANSMUTE_ADMIN_PASSWORD variable)", flush=True)
