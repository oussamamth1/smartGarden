"""Garden Pi entry point: start telemetry, command listener, and automation."""
import signal
import threading
import time
from datetime import datetime

import config
import firebase_client as fb
from actuators.relay import Relay
from automation import rules
from camera import webrtc_stream
from loops import telemetry_loop, command_loop, rooms_loop

stop_event = threading.Event()


def automation_tick(relays, settings_holder):
    """Periodically apply automation rules (manual commands still take priority
    between ticks; rules re-assert on each tick)."""
    while not stop_event.is_set():
        try:
            settings = fb.get_value("settings") or {}
            actions = rules.evaluate(settings, telemetry_loop.latest, datetime.now())
            if "pump" in actions:
                relays["pump"].set(actions["pump"])
            if "light" in actions:
                relays["light"].set(actions["light"])
            if actions.get("pump") is not None or actions.get("light") is not None:
                command_loop._write_state(relays)
            for alert in actions.get("alerts", []):
                print(f"[ALERT] {alert}")  # TODO: send via FCM
        except Exception as exc:
            print(f"[automation] {exc}")
        stop_event.wait(config.AUTOMATION_INTERVAL_SEC)


def main():
    print(f"Garden Pi starting (garden={config.GARDEN_ID}, "
          f"mock={config.MOCK_HARDWARE})")
    fb.init()

    relays = {
        "pump": Relay(config.PUMP_RELAY_PIN, "pump"),
        "light": Relay(config.LIGHT_RELAY_PIN, "light"),
    }

    # real-time sensor push
    t = threading.Thread(target=telemetry_loop.run, args=(stop_event,), daemon=True)
    t.start()

    # real-time command listener
    command_loop.start(relays)

    # automation
    a = threading.Thread(
        target=automation_tick, args=(relays, None), daemon=True
    )
    a.start()

    # per-room telemetry + device control + climate automation
    rm = threading.Thread(target=rooms_loop.run, args=(stop_event,), daemon=True)
    rm.start()

    # live camera (WebRTC) — answers offers from the phone via /webrtc
    cam = threading.Thread(
        target=webrtc_stream.run, args=(stop_event,), daemon=True
    )
    cam.start()

    def shutdown(*_):
        print("\nShutting down...")
        stop_event.set()
        for r in relays.values():
            r.off()

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    print("Garden Pi running. Ctrl+C to stop.")
    while not stop_event.is_set():
        time.sleep(0.5)


if __name__ == "__main__":
    main()
