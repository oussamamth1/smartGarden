"""Per-room climate automation.

Pure logic: given a room's settings + latest telemetry + current device state,
return which climate devices (heater/fan) should be on to hold the target temp.
Light is always manual, so it's never returned here.
"""

HYSTERESIS = 0.5  # °C dead-band around the target to avoid rapid toggling


def evaluate(settings: dict, telemetry: dict, devices: dict) -> dict:
    """Return desired climate device overrides, e.g. {'heater': True, 'fan': False}.

    Empty when auto-climate is disabled, so manual control wins.
    """
    settings = settings or {}
    if not settings.get("auto_climate_enabled"):
        return {}

    temp = (telemetry or {}).get("temperature")
    if temp is None:
        return {}

    target = settings.get("target_temp", 22)
    if temp < target - HYSTERESIS:
        return {"heater": True, "fan": False}   # too cold -> heat
    if temp > target + HYSTERESIS:
        return {"heater": False, "fan": True}    # too warm -> cool
    return {"heater": False, "fan": False}        # within band -> idle


def alerts(settings: dict, telemetry: dict) -> list:
    """Temperature alert messages for this room (empty when none)."""
    settings = settings or {}
    temp = (telemetry or {}).get("temperature")
    limit = settings.get("temp_alert_above")
    if temp is not None and limit is not None and temp > limit:
        return [f"Temperature {temp}°C is above {limit}°C"]
    return []
