# Garden Pi — Raspberry Pi service

Python service that reads sensors, controls the pump + lights, streams the camera,
and syncs everything with Firebase in real time.

## Setup

```bash
cd pi
python -m venv .venv && source .venv/bin/activate   # on the Pi
pip install -r requirements.txt

# Firebase credentials
#  1. Firebase console > Project settings > Service accounts > Generate new private key
#  2. Save it here as serviceAccountKey.json   (already git-ignored)
cp .env.example .env        # then edit GARDEN_DB_URL + GARDEN_STORAGE_BUCKET
set -a; source .env; set +a
```

## Run

```bash
python main.py
```

Test on a laptop without hardware:

```bash
GARDEN_MOCK=1 python main.py
```

## Wiring (BCM pins — edit in config.py)

| Component | Pin / bus |
|---|---|
| Pump relay | GPIO 17 |
| Light relay | GPIO 27 |
| BME280 | I2C (SDA/SCL), addr 0x76 |
| ADS1115 (soil) | I2C, channel A0 |
| BH1750 (light) | I2C |

Calibrate the soil sensor: read `voltage` in dry air and in water, then set
`SOIL_DRY_VOLTAGE` / `SOIL_WET_VOLTAGE` in `config.py`.

## Run on boot (systemd)

```ini
# /etc/systemd/system/garden-pi.service
[Unit]
Description=Garden Pi
After=network-online.target

[Service]
WorkingDirectory=/home/pi/garden/pi
EnvironmentFile=/home/pi/garden/pi/.env
ExecStart=/home/pi/garden/pi/.venv/bin/python main.py
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable --now garden-pi
```

## Layout

- `main.py` — wires loops together
- `config.py` — pins, intervals, calibration
- `firebase_client.py` — RTDB helpers
- `sensors/` — BME280, soil (ADS1115), light (BH1750)
- `actuators/relay.py` — pump / light relays
- `automation/rules.py` — auto-water, light schedule, alerts
- `automation/room_rules.py` — per-room climate (heater/fan toward target temp)
- `loops/` — telemetry push + command listener + per-room loop (`rooms_loop.py`)
- `camera/webrtc_stream.py` — live multi-camera WebRTC streaming
