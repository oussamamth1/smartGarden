"""Per-room loop: telemetry + command handling + climate automation.

Rooms are created/renamed/deleted by the app under /gardens/{id}/rooms/{roomId}.
This loop reads the current room list each cycle and, for every room:
  1. applies any device commands the app wrote (heater/fan/light),
  2. reads (or simulates) the room temperature,
  3. runs climate automation (heater/fan toward the target temp),
  4. writes the room's telemetry + confirmed device state back.

Because rooms are dynamic, this polls rather than registering listeners.

Real hardware note: with several rooms you need one temp sensor per room (e.g.
BME280s behind a TCA9548A I2C multiplexer). Mapping sensor->room would live in
config; until then real mode reads the single sensor for every room. Mock mode
simulates a distinct, device-reactive temperature per room.
"""
import time
import traceback

import config
import firebase_client as fb
from automation import room_rules

# In-memory per-room state (mock simulation + confirmed device state).
_sim_temp = {}       # room_id -> float °C
_device_state = {}   # room_id -> {"heater": bool, "fan": bool, "light": bool}

DEVICES = ("heater", "fan", "light")


def _truthy(v):
    return v in (True, "on", "ON", 1)


def _read_temp(room_id: str, devices: dict) -> dict:
    """Simulated (mock) or real room temperature + humidity."""
    if config.MOCK_HARDWARE:
        t = _sim_temp.get(room_id, 22.0)
        if devices["heater"]:
            t += 0.4
        elif devices["fan"]:
            t -= 0.4
        else:
            t += (22.0 - t) * 0.05  # drift back toward ambient
        t = max(5.0, min(40.0, t))
        _sim_temp[room_id] = t
        return {"temperature": round(t, 1), "humidity": 55.0}

    from sensors import temperature

    r = temperature.read()
    return {"temperature": r["temperature"], "humidity": r["humidity"]}


def run(stop_event):
    while not stop_event.is_set():
        try:
            rooms = fb.get_value("rooms") or {}
            for room_id, room in rooms.items():
                room = room or {}
                devices = _device_state.setdefault(
                    room_id, {"heater": False, "fan": False, "light": False}
                )

                # 1. apply commands written by the app
                commands = room.get("commands") or {}
                for d in DEVICES:
                    if d in commands:
                        devices[d] = _truthy(commands[d])

                # 2. read/simulate the sensor
                reading = _read_temp(room_id, devices)
                reading["updated_at"] = int(time.time())
                fb.set_value(f"rooms/{room_id}/telemetry", reading)

                # 3. climate automation (overrides heater/fan when enabled)
                settings = room.get("settings") or {}
                devices.update(room_rules.evaluate(settings, reading, devices))
                for msg in room_rules.alerts(settings, reading):
                    print(f"[ALERT room={room_id}] {msg}")  # TODO: FCM

                # 4. confirm device state
                fb.set_value(
                    f"rooms/{room_id}/state",
                    {d: "on" if devices[d] else "off" for d in DEVICES},
                )

            # forget state for rooms the user deleted
            for gone in set(_device_state) - set(rooms):
                _device_state.pop(gone, None)
                _sim_temp.pop(gone, None)
        except Exception:
            traceback.print_exc()
        stop_event.wait(config.ROOM_INTERVAL_SEC)
