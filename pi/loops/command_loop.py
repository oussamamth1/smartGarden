"""Listen to RTDB /commands in real time; drive relays; confirm into /state."""
import firebase_client as fb


def _apply(relays: dict, commands: dict):
    if not commands:
        return
    if "pump" in commands:
        relays["pump"].set(commands["pump"] in (True, "on", "ON", 1))
    if "light" in commands:
        relays["light"].set(commands["light"] in (True, "on", "ON", 1))
    _write_state(relays)


def _write_state(relays: dict):
    fb.update(
        "state",
        {
            "pump": "on" if relays["pump"].is_on else "off",
            "light": "on" if relays["light"].is_on else "off",
            "camera_online": True,
        },
    )


def start(relays: dict):
    """Subscribe to /commands. Returns the listener handle."""
    _write_state(relays)  # publish initial state

    def on_event(event):
        # event.data is the full /commands dict on first call, or a single
        # changed value on later calls; re-read the whole node to be safe.
        commands = fb.get_value("commands") or {}
        _apply(relays, commands)

    return fb.listen("commands", on_event)
