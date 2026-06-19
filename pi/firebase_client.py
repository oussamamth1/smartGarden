"""Thin wrapper around firebase-admin for the garden's Realtime Database node."""
import firebase_admin
from firebase_admin import credentials, db

import config

_app = None


def init():
    """Initialise the Firebase app once, using the service-account key."""
    global _app
    if _app is not None:
        return _app
    if not config.DATABASE_URL:
        raise RuntimeError("GARDEN_DB_URL is not set (see config.py / .env).")
    cred = credentials.Certificate(config.SERVICE_ACCOUNT_PATH)
    _app = firebase_admin.initialize_app(
        cred,
        {
            "databaseURL": config.DATABASE_URL,
            "storageBucket": config.STORAGE_BUCKET,
        },
    )
    return _app


def ref(path: str):
    """Return a DB reference under this garden, e.g. ref('telemetry')."""
    return db.reference(f"/gardens/{config.GARDEN_ID}/{path}")


def set_value(path: str, value):
    # firebase-admin rejects set(None); treat None as "delete this node".
    if value is None:
        ref(path).delete()
    else:
        ref(path).set(value)


def update(path: str, value: dict):
    ref(path).update(value)


def get_value(path: str):
    return ref(path).get()


def listen(path: str, callback):
    """Subscribe to changes under `path`. callback(event) fires on every change."""
    return ref(path).listen(callback)
