# 🌱 Garden Pi — Smart Garden Controller

Monitor and control a garden (plants + animals) **in real time** from your phone.
Water, lights, live camera, and climate — manual buttons **and** automatic rules —
powered by a Raspberry Pi and Firebase.

> Built from components available in Tunisia 🇹🇳 — nothing needs importing.

---

## ✨ Features

- 🌡️ **Live climate** — temperature, humidity, pressure (BME280)
- 💧 **Smart watering** — capacitive soil sensor + pump, manual or auto-water by threshold
- 💡 **Lighting** — relay-switched grow lights, manual or on a schedule
- 📷 **Live camera** — real-time WebRTC video (<1s), works from anywhere
- 📊 **Real-time dashboard** — everything updates live, no refresh
- 🔔 **Alerts** — push notifications (e.g. "temperature too high")
- 🌍 **Control from anywhere** — home, work, or vacation (no router config)

---

## 🏗️ Architecture

Firebase is the **middleman** — the phone never talks to the Pi directly. Both connect
to Firebase, so it works from anywhere with zero network setup.

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────┐
│ Raspberry   │ writes  │    FIREBASE      │ listens │  Flutter    │
│ Pi (Python) │────────▶│  Realtime DB     │◀────────│  app        │
│             │ telemetry│  Storage         │         │  (phone)    │
│ reads GPIO  │◀────────│  Auth + FCM      │ writes  │ dashboard   │
│ runs camera │ commands│                  │ commands│ + controls  │
└─────────────┘         └──────────────────┘         └─────────────┘
        └──────────── live video: WebRTC P2P (RTDB = signaling) ────────┘
```

### Everything is real-time

| Data | Transport | Latency | From anywhere |
|---|---|---|---|
| Sensor telemetry | Firebase RTDB live listener | < 1 s | ✅ |
| Pump / light control | Firebase RTDB (command → state) | < 1 s | ✅ |
| Live camera video | WebRTC (P2P; RTDB = signaling only) | < 1 s | ✅ |

**Command vs. state:** the app writes what you *want* to `/commands`; the Pi writes what
it *actually did* to `/state`. A toggle stays "pending" until the Pi confirms — the UI
never lies if a relay fails or the Pi goes offline.

---

## 🧰 Hardware (sourced in Tunisia 🇹🇳)

Suppliers: tuni-smart-innovation.com · souilah-electronique.tn · didactico.tn ·
es-online.tn · celectronix.com · 2btrading.tn · SNE Sometel *(distributeur officiel)*.

| Part | Purpose | Notes |
|---|---|---|
| Raspberry Pi 4 / 5 | The brain | Pi 4 (2GB) is plenty; Pi 5 for headroom |
| GY-BME280 | Temp + humidity + pressure | I2C, accurate |
| Capacitive soil sensor V1.2 | Soil dryness | Anti-corrosion, analog output |
| **ADS1115** (16-bit I2C ADC) | Reads the analog soil sensor | **Required** — the Pi has no analog input; 4 channels = up to 4 zones |
| Relay module 4-channel (5 V) | Switch pump + lights | Opto-isolated |
| Water pump 5 V + tubing | Watering | Switched by relay, separate power |
| Pi Camera module 5MP | Live video | |
| BH1750 light sensor *(optional)* | Light level | I2C |
| Jumper wires, breadboard, PSUs | Wiring | |

⚠️ **Safety:** pump and lights run on their own power supply, switched through the
relay — never driven directly from the Pi's GPIO.

---

## 🗂️ Repository layout

```
projet-raspberry-pi/
├── README.md          ← this file
├── PLAN.md            ← detailed build plan, data model, milestones
├── pi/                ← Python service on the Raspberry Pi
│   ├── main.py
│   ├── sensors/       ← BME280, soil (ADS1115), light (BH1750)
│   ├── actuators/     ← relay control (pump, light)
│   ├── camera/        ← WebRTC live stream (aiortc + Picamera2)
│   ├── automation/    ← auto-water, light schedule, alerts
│   └── loops/         ← telemetry loop + command listener
└── app/               ← Flutter phone app (Riverpod + GetIt)
    └── lib/
        ├── features/  ← auth, dashboard, controls, camera, settings, history
        ├── services/  ← garden_service, storage_service
        └── providers/ ← telemetry, controls, settings (Riverpod)
```

---

## 🔌 Firebase data model (Realtime Database)

```
/gardens/{gardenId}
  /telemetry   temperature, humidity, soil_moisture, light_level, updated_at
  /commands    pump, light            ← phone writes
  /state       pump, light, camera_online   ← Pi confirms
  /settings    auto_water_enabled, auto_water_below, light_schedule_on/off, temp_alert_above
  /webrtc      offer, answer, ice_*   ← live-video signaling handshake
  /history     {timestamp}: { ...readings }   ← for charts
```

---

## 🛠️ Tech stack

- **Pi:** Python · `firebase-admin` · `gpiozero`/`RPi.GPIO` · Adafruit BME280/ADS1115 ·
  `picamera2` · `aiortc`
- **App:** Flutter · `firebase_core` · `firebase_auth` · `firebase_database` ·
  `firebase_messaging` · `flutter_webrtc` · `flutter_riverpod` · `get_it` · `fl_chart`
- **Cloud:** Firebase Realtime Database · Storage · Auth · Cloud Messaging (FCM)

---

## 🗺️ Build order

1. **Firebase setup** — project, RTDB + Storage + Auth, security rules, Pi service-account key, `firebase_options.dart`
2. **Pi: telemetry** — read BME280 → push to RTDB (verify live in console)
3. **Pi: actuators** — relay on/off via `/commands`, confirm `/state`
4. **Flutter: dashboard + controls** — login, live telemetry, pump/light toggles
5. **Pi: remaining sensors** — soil (ADS1115), light (BH1750)
6. **Live camera (WebRTC)** — LAN first, then internet (STUN/TURN)
7. **Automation** — thresholds, schedules, temp alerts (FCM)
8. **History + charts** — log readings, real-time graphs
9. **Harden** — run-on-boot (systemd), offline handling, security rules, TURN server

---

## ❓ Open questions

- **Zones** — how many soil sensors / watering areas? (1 to start; up to 4 on the ADS1115)
- **Animals** 🐾 — anything beyond the camera? (spare relay channel for a feeder or
  water top-up for a drinker?)
- **Firebase plan** — Spark (free) is fine to start; Blaze (pay-as-you-go) later if
  Storage / write volume grows.

---

*Plan details live in [PLAN.md](./PLAN.md).*
