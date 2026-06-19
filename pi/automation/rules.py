"""Evaluate automation rules from /settings against the latest telemetry.

Called periodically by main.py. Pure logic — it returns desired actions, the
caller applies them to the relays and writes /state. This keeps it testable.
"""
from datetime import datetime


def _within_schedule(now_hm: str, on_hm: str, off_hm: str) -> bool:
    """True if now_hm is inside [on, off). Handles overnight windows."""
    if on_hm == off_hm:
        return False
    if on_hm < off_hm:
        return on_hm <= now_hm < off_hm
    # overnight, e.g. on 20:00 off 06:00
    return now_hm >= on_hm or now_hm < off_hm


def evaluate(settings: dict, telemetry: dict, now: datetime) -> dict:
    """Return desired actions, e.g. {'pump': True, 'light': False, 'alerts': [...]}.

    Keys are omitted when a rule is disabled, so manual control still wins.
    """
    settings = settings or {}
    telemetry = telemetry or {}
    actions = {"alerts": []}

    # --- Auto-water by soil moisture threshold ---
    if settings.get("auto_water_enabled"):
        moisture = telemetry.get("soil_moisture")
        below = settings.get("auto_water_below", 30)
        if moisture is not None:
            actions["pump"] = moisture < below

    # --- Light schedule ---
    on_hm = settings.get("light_schedule_on")
    off_hm = settings.get("light_schedule_off")
    if on_hm and off_hm:
        now_hm = now.strftime("%H:%M")
        actions["light"] = _within_schedule(now_hm, on_hm, off_hm)

    # --- Temperature alert ---
    temp = telemetry.get("temperature")
    limit = settings.get("temp_alert_above")
    if temp is not None and limit is not None and temp > limit:
        actions["alerts"].append(f"Temperature {temp}°C is above {limit}°C")

    return actions
