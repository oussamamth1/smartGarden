# Garden Pi — Hardware Build Guide

Step-by-step, from parts on the table to the service running on boot. Follow the
steps in order. Pins are given as **physical** header pin numbers and the **BCM**
GPIO number used in `pi/config.py`.

---

## 1. Materials (bill of materials)

| # | Part | Qty | Notes |
|---|---|---|---|
| 1 | Raspberry Pi 4 (or 5) | 1 | The brain. 2 GB RAM is plenty. |
| 2 | USB-C power supply (official, 5 V/3 A) | 1 | Underpowered supplies cause crashes. |
| 3 | microSD card 32 GB (Class 10 / A1) | 1 | OS + service. |
| 4 | GY-BME280 (temp/humidity/pressure) | 1 | I2C sensor. |
| 5 | Capacitive soil moisture sensor v1.2 | 1+ | Analog output. |
| 6 | ADS1115 16-bit ADC | 1 | Reads the analog soil sensor (Pi has no analog input). |
| 7 | BH1750 light sensor | 1 (optional) | I2C. |
| 8 | 4-channel relay module (5 V, opto-isolated) | 1 | Switches pump / light / heater / fan. |
| 9 | Water pump 5 V (+ tubing) or solenoid valve | 1 | The load. |
| 10 | Separate power supply for the pump/load | 1 | e.g. a 5 V or 12 V supply matching the pump. |
| 11 | Pi Camera module **or** USB webcam(s) | 1+ | CSI ribbon, or USB for several cameras. |
| 12 | Breadboard + jumper wires (M-M, M-F) | — | For the 3.3 V / 5 V / SDA / SCL rails. |
| 13 | (Multi-room) TCA9548A I2C multiplexer | 1 | Only if you want >2 BME280s (one per room). |
| 14 | (Multi-room) extra relay channels / MCP23017 | — | More room devices than 4 relay channels. |

**Tools:** small screwdriver (for relay screw terminals), and a computer with an
SD-card slot.

---

## 2. Flash the SD card and set up WiFi (do this on your PC)

This is where WiFi is configured — **before** the first boot, so the Pi comes up
online and headless (no monitor needed).

1. Install **Raspberry Pi Imager**: https://www.raspberrypi.com/software/
2. Insert the microSD card into your PC.
3. Open Imager →
   - **Choose Device:** your Pi model
   - **Choose OS:** *Raspberry Pi OS Lite (64-bit)* — no desktop needed
   - **Choose Storage:** the microSD card
4. Click **Next → Edit Settings** (the ⚙ / "OS Customisation" dialog). Set:
   - **Hostname:** `gardenpi`
   - ✅ **Enable SSH** → *Use password authentication*
   - **Username / password:** e.g. `pi` / a password you'll remember
   - **Configure wireless LAN:**
     - **SSID:** your WiFi network name
     - **Password:** your WiFi password
     - **Wireless LAN country:** `TN` (Tunisia) — *required*, or WiFi won't turn on
   - **Locale / timezone:** `Africa/Tunis`
5. **Save → Write.** Wait for it to finish, then eject the card.

> The WiFi credentials are baked into the card here, so on first boot the Pi joins
> your network automatically. (2.4 GHz networks are the most reliable on a Pi.)

---

## 3. First boot and connect (SSH from your PC)

1. Put the microSD card into the Pi, connect the camera now if using CSI (step 6),
   then plug in the **USB-C power**. Wait ~60 s for first boot.
2. From your PC terminal:
   ```bash
   ssh pi@gardenpi.local
   ```
   (If `gardenpi.local` doesn't resolve, find the Pi's IP in your router's device
   list and use `ssh pi@192.168.x.x`.)
3. Update the system:
   ```bash
   sudo apt update && sudo apt full-upgrade -y
   ```

---

## 4. Enable the interfaces

```bash
sudo raspi-config
```
- **Interface Options → I2C → Enable**  (for BME280 / ADS1115 / BH1750)
- **Interface Options → Camera → Enable**  (only on older OS; Bookworm auto-detects)
Then:
```bash
sudo apt install -y i2c-tools python3-venv git
sudo reboot
```

---

## 5. Power & safety rules (read before wiring)

- **Power off the Pi before wiring** (`sudo shutdown -h now`, then unplug).
- **Never** drive the pump / valve / grow-light from a GPIO pin — they go through
  the **relay**, on their **own** power supply.
- Sensors use **3.3 V**. The relay board and soil sensor use **5 V**.
- **All grounds must be connected together** (Pi GND + relay-supply GND +
  pump-supply GND). A shared ground is mandatory.

---

## 6. Wiring — which port for each part

Raspberry Pi 40-pin header, key pins:

```
        3V3  (1) (2)  5V
 GPIO2/SDA  (3) (4)  5V
 GPIO3/SCL  (5) (6)  GND
            (7) (8)
        GND  (9) (10)
   GPIO17  (11) (12)
   GPIO27  (13) (14) GND
            ...        (39) GND  (40)
```

### 6a. I2C sensors — share ONE bus
BME280, ADS1115 and BH1750 all connect to the **same four pins** (different I2C
addresses let them coexist). Use the breadboard to split 3.3 V / GND / SDA / SCL.

| Each sensor pin | → Pi pin |
|---|---|
| VCC / VIN | Pin **1** (3.3 V) |
| GND | Pin **6** or **9** (GND) |
| SDA | Pin **3** (GPIO2 / SDA) |
| SCL | Pin **5** (GPIO3 / SCL) |

### 6b. Soil moisture sensor (analog) → ADS1115
| Soil sensor | → |
|---|---|
| VCC | 5 V (Pin **2**) |
| GND | GND |
| AOUT | **ADS1115 channel A0** |

Matches `ADS1115_SOIL_CHANNEL = 0`. The ADS1115 is already on I2C (6a).

### 6c. Relay module (control side: Pi → relay)
| Relay pin | → Pi pin | Role (code) |
|---|---|---|
| VCC | Pin **4** (5 V) | — |
| GND | Pin **14** (GND) | — |
| IN1 | Pin **11** | **GPIO17** → pump |
| IN2 | Pin **13** | **GPIO27** → light |
| IN3 / IN4 | spare GPIO | heater / fan (add to config) |

### 6d. Relay module (load side: the actual device)
Each channel has three screw terminals: **COM / NO / NC**. Wire the load through
**NO** (normally-open = off until switched):
```
  pump supply (+) ──► COM
  relay NO        ──► pump (+)
  pump (–) ──► pump supply (–) ──► (shared GND with the Pi)
```

> Most boards are **active-LOW** (LOW = ON), which is why `RELAY_ACTIVE_HIGH = False`
> in `config.py`. If a relay is ON when the app says OFF, set it to `True`.

### 6e. Camera
- **Pi Camera (CSI):** ribbon cable into the **CSI** port (contacts facing the
  correct way), with the Pi powered off.
- **USB camera(s):** plug into any USB port. Each appears as `/dev/video0`,
  `/dev/video1`, … — put those numbers in the `CAMERAS` list (`source`) in config.

---

## 7. Verify the wiring

Power the Pi back on, SSH in, then:
```bash
i2cdetect -y 1
```
Expect to see:
- `76` (or `77`) → BME280
- `48` → ADS1115
- `23` → BH1750

List cameras:
```bash
ls /dev/video*
v4l2-ctl --list-devices    # sudo apt install v4l-utils
```

If a device is missing, recheck its VCC / GND / SDA / SCL before continuing.

---

## 8. Install and configure the software

```bash
git clone <your-repo-url> garden && cd garden/pi
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
```

Firebase credentials:
1. Copy your **service-account key** to `pi/serviceAccountKey.json`
   (from your PC: `scp serviceAccountKey.json pi@gardenpi.local:~/garden/pi/`).
2. Create the env file:
   ```bash
   cp .env.example .env
   nano .env          # set GARDEN_DB_URL + GARDEN_STORAGE_BUCKET; set GARDEN_MOCK=0
   ```

Edit `pi/config.py` to match your build:
- relay pins (if you used different GPIOs), `RELAY_ACTIVE_HIGH`
- soil dry/wet calibration voltages
- the `CAMERAS` list (one entry per USB camera, `source` = its `/dev/videoN`)

---

## 9. Run and test

```bash
# load env and run
set -a; source .env; set +a
python main.py
```
You should see telemetry appear in the Firebase console and in the phone app.

Test without hardware first if you like: `GARDEN_MOCK=1 python main.py`.

---

## 10. Run on boot (systemd)

```bash
sudo nano /etc/systemd/system/garden-pi.service
```
```ini
[Unit]
Description=Garden Pi
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=/home/pi/garden/pi
EnvironmentFile=/home/pi/garden/pi/.env
ExecStart=/home/pi/garden/pi/.venv/bin/python main.py
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
```
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now garden-pi
journalctl -u garden-pi -f      # watch the logs
```

The garden now runs headless and restarts on reboot or crash.

---

## 11. Multi-room hardware (when you add rooms)

Each room needs its **own temperature sensor** and its **own relay channels**
(heater / fan / light):
- **Sensors:** BME280s share an I2C address, so put each behind a **TCA9548A**
  multiplexer (channels 0..7) and map sensor→room in `config.py`.
- **Devices:** a 4-channel relay covers ~1 room + a garden device. For more, use
  an **8/16-channel relay board** or an **MCP23017** GPIO expander.
- The app already lets you add rooms; the remaining work is the sensor→room
  mapping in the Pi config. Ask and I'll wire that up.

---

## 12. Let the end-user set their own WiFi (captive portal)

Step 2 bakes WiFi into the card — fine for *your* network, but not if someone
else sets up the device on *their* network. For that, use a **setup hotspot +
captive portal**: when the Pi can't find a known network it broadcasts its own
WiFi; the user joins it from a phone, picks their network, and types the password.

Provisioning files live in `pi/provisioning/`. On the Pi (Raspberry Pi OS
**Bookworm**, which uses NetworkManager), run once:
```bash
cd ~/garden/pi/provisioning
bash setup_wifi_portal.sh
sudo reboot
```

**What the end-user then does (no SSH, no flashing):**
1. Power on the Pi. If it has no known WiFi, after ~20 s it broadcasts
   **`GardenPi-Setup`**.
2. On their phone: Settings → WiFi → join **GardenPi-Setup**.
3. A setup page opens automatically (captive portal) listing nearby networks.
4. They pick their WiFi, enter the password, **Submit**.
5. The Pi saves it, the hotspot closes, and it joins their network. Future boots
   reconnect automatically; the portal only returns if no known network is found.

Pieces:
- `setup_wifi_portal.sh` — one-time installer (installs balena wifi-connect + the service)
- `start-wifi-connect.sh` — launches the portal only when offline
- `garden-wifi.service` — runs it at boot, before `garden-pi.service`

> Requires NetworkManager (default on Bookworm). On older images enable it via
> `raspi-config → Advanced → Network Config → NetworkManager`.

## Quick troubleshooting

| Symptom | Check |
|---|---|
| Can't SSH | Right hostname/IP? WiFi country set? On the 2.4 GHz network? |
| `i2cdetect` shows nothing | I2C enabled in raspi-config? SDA→Pin3, SCL→Pin5, 3.3 V? |
| Relay inverted (on when off) | Flip `RELAY_ACTIVE_HIGH` in `config.py`. |
| Pi randomly reboots | Use the official 5 V/3 A supply; the pump must be on its own supply. |
| Soil % stuck at 0/100 | Calibrate `SOIL_DRY_VOLTAGE` / `SOIL_WET_VOLTAGE` (read in air vs water). |
| Camera not found | CSI seated/enabled, or `ls /dev/video*` for USB; set `CAMERAS` source. |
