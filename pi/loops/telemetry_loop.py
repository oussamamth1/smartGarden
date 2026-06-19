"""Read all sensors and push to RTDB /telemetry in real time (~1s)."""
import time
import traceback

import config
import firebase_client as fb
from sensors import temperature, soil, light

# the most recent reading, shared with the automation tick
latest = {}


def run(stop_event):
    last_history = 0.0
    while not stop_event.is_set():
        try:
            reading = {}
            reading.update(temperature.read())
            reading.update(soil.read())
            try:
                reading.update(light.read())
            except Exception:
                pass  # light sensor is optional
            reading["updated_at"] = int(time.time())

            latest.clear()
            latest.update(reading)
            fb.set_value("telemetry", reading)

            now = time.time()
            if now - last_history >= config.HISTORY_INTERVAL_SEC:
                fb.set_value(f"history/{reading['updated_at']}", reading)
                last_history = now
        except Exception:
            traceback.print_exc()
        stop_event.wait(config.TELEMETRY_INTERVAL_SEC)
