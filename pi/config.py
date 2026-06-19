"""Central configuration for the Garden Pi service.

Edit GPIO pins / intervals to match your wiring. Secrets (the Firebase service
account key and database URL) are read from environment variables so they never
get committed.

Values are loaded from a local `.env` file (next to this file) automatically, so
`python main.py` works from any shell without manually exporting variables.
Real environment variables still take precedence over `.env`.
"""
import os
from pathlib import Path

# Load pi/.env if python-dotenv is available (no-op if the package or file is
# missing — env vars set in the shell still work either way).
try:
    from dotenv import load_dotenv

    load_dotenv(Path(__file__).with_name(".env"))
except ImportError:
    pass

# ---- Firebase ----------------------------------------------------------------
# Path to the service-account JSON downloaded from the Firebase console.
SERVICE_ACCOUNT_PATH = os.environ.get(
    "GARDEN_FIREBASE_KEY", "serviceAccountKey.json"
)
# Realtime Database URL, e.g. https://garden-pi-xxxx-default-rtdb.firebaseio.com
DATABASE_URL = os.environ.get("GARDEN_DB_URL", "")
# Firebase Storage bucket, e.g. garden-pi-xxxx.appspot.com
STORAGE_BUCKET = os.environ.get("GARDEN_STORAGE_BUCKET", "")

# Which garden this Pi controls (the node under /gardens).
GARDEN_ID = os.environ.get("GARDEN_ID", "garden1")

# ---- Timing ------------------------------------------------------------------
TELEMETRY_INTERVAL_SEC = 1.0     # how often sensors are pushed (real-time feel)
HISTORY_INTERVAL_SEC = 300       # how often a reading is logged to /history
AUTOMATION_INTERVAL_SEC = 10     # how often automation rules are evaluated
ROOM_INTERVAL_SEC = 2.0          # how often each room's telemetry/state is updated

# ---- GPIO pins (BCM numbering) -----------------------------------------------
PUMP_RELAY_PIN = 17
LIGHT_RELAY_PIN = 27
# Most relay boards are ACTIVE-LOW (a LOW signal switches them ON).
RELAY_ACTIVE_HIGH = False

# ---- Sensors -----------------------------------------------------------------
BME280_I2C_ADDRESS = 0x76        # 0x76 or 0x77 depending on the board
ADS1115_SOIL_CHANNEL = 0         # which ADS1115 channel the soil sensor is on
# Calibrate these two with your sensor: raw voltage in air (dry) and in water (wet).
SOIL_DRY_VOLTAGE = 3.0
SOIL_WET_VOLTAGE = 1.2

# ---- Cameras (WebRTC) --------------------------------------------------------
# One entry per camera. `source` is the USB video device index (/dev/video<N>);
# add/remove entries to match how many cameras are plugged in. Each camera gets
# its own signaling node at /gardens/{id}/cameras/{cam id}/webrtc.
# In mock mode the `source` is ignored and a labelled test pattern is streamed.
CAMERAS = [
    {"id": "cam1", "name": "Camera 1", "source": 0},
    {"id": "cam2", "name": "Camera 2", "source": 1},
]

# ---- Run mode ----------------------------------------------------------------
# When True, sensors/actuators are simulated so you can run on a laptop (no Pi).
MOCK_HARDWARE = os.environ.get("GARDEN_MOCK", "0") == "1"
