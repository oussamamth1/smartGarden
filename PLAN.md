# Garden Pi — Smart Garden Controller

Control and monitor a garden (plants + animals) from your phone via a Raspberry Pi
and Firebase. Water, lights, camera, and temperature — manual and automatic.

---

## 1. System overview

Three layers, with **Firebase as the middleman** — the phone never talks to the Pi
directly. Both connect to Firebase, so it works from anywhere (no router config).

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────┐
│ Raspberry   │ writes  │    FIREBASE      │ listens │  Flutter    │
│ Pi (Python) │────────▶│  Realtime DB     │◀────────│  app        │
│             │ telemetry│  Storage         │         │  (phone)    │
│ reads GPIO  │◀────────│  Auth + FCM      │ writes  │ dashboard   │
│ runs camera │ commands│                  │ commands│ + controls  │
└─────────────┘         └──────────────────┘         └─────────────┘
```

### Decisions locked in
- **Backbone:** Firebase (Realtime Database + Storage + Auth + Cloud Messaging)
- **App:** Flutter (reuse Riverpod + service/provider patterns from Zenify Trip)
- **Pi backend:** Python (best GPIO/sensor/camera support)
- **Everything real-time:**
  - Telemetry (temp/humidity/soil/light) → RTDB live streams, Pi pushes ~1 s
  - Controls (pump/light) → RTDB command→state, live confirmation
  - **Camera → live WebRTC video** (low latency, works from anywhere; Firebase used
    only for signaling). Not snapshots.
- **Automation:** Both — manual buttons AND threshold/schedule rules

---

## 2. Hardware — sourced in Tunisia 🇹🇳

All components below are in stock at Tunisian shops — nothing needs importing.
Main suppliers: **tuni-smart-innovation.com**, **souilah-electronique.tn**,
**didactico.tn**, **es-online.tn**, **celectronix.com**, **2btrading.tn**,
**bestbuytunisie.tn**. Most offer livraison partout en Tunisie (Souilah: free over 150 DT).

| Part | Purpose | Where in Tunisia / notes |
|---|---|---|
| Raspberry Pi 4 / 5 (or Zero 2 W) | The brain | tuni-smart, es-online, celectronix, SNE Sometel (distributeur officiel). Pi 3B+ ≈ 135 DT; Pi 4/5 more |
| **GY-BME280** | Temp + humidity + pressure | Souilah (`/modules-et-capteurs/63`). I2C, high precision. **Chosen over DHT22** |
| Capacitive soil moisture sensor V1.2 | Soil dryness | seli.tn, tuni-smart, souilah, didactico, 2btrading. Anti-corrosion. Analog 0–3 V output |
| **ADS1115** (16-bit I2C ADC) | Reads the analog soil sensor | Souilah (`/modules-et-capteurs/122`), didactico. **Required** — the Pi has NO analog input |
| Relay module 4-channel (5 V, opto-isolated) | Switch pump + lights | tuni-smart `/products/module-relais-4-canaux` |
| Water pump 5 V (+ tubing) / solenoid valve | Watering | tuni-smart collection "Pompe et Ventilateur" |
| Pi Camera module 5MP | Camera | Souilah (`/modules-et-capteurs/198`) |
| BH1750 light sensor *(optional)* | Light level | I2C; common in TN shops. Or skip and infer from camera |
| Jumper wires, breadboard, PSUs | Wiring | All TN shops |

**Why BME280 over DHT22:** both are widely stocked in Tunisia, but the GY-BME280 is
more accurate, uses I2C (cleaner wiring, shares the bus with ADS1115 + BH1750), and adds
pressure for free. DHT22 (≈ available everywhere) stays a cheap fallback if needed.

**Key dependency:** the capacitive soil sensor is *analog*; the Raspberry Pi cannot read
analog directly, so the **ADS1115** is not optional — it's the bridge between the soil
sensor and the Pi (over I2C).

**Safety:** pump/valve and lights run on their own power supply, switched through the
relay — never drive them off the Pi's GPIO directly.

---

## 2b. Real-time transport summary

| Data | Transport | Latency | From anywhere? |
|---|---|---|---|
| Sensor telemetry | Firebase RTDB live listener | < 1 s | ✅ |
| Pump / light control | Firebase RTDB (command → state) | < 1 s | ✅ |
| **Live camera video** | **WebRTC** (P2P; RTDB = signaling only) | < 1 s | ✅ |

WebRTC pieces: Pi runs `aiortc` + Picamera2; app uses `flutter_webrtc`; the
offer/answer/ICE handshake is written under `/gardens/{id}/webrtc` in RTDB. After the
handshake, video flows **directly** Pi → phone (Firebase is no longer in the path).
A STUN server (free, public) handles NAT traversal; a TURN relay is the fallback for
strict networks.

## 3. Firebase data model (Realtime Database)

```
/gardens/{gardenId}
  /telemetry            ← Pi writes every few seconds (live snapshot of state)
      temperature: 24.5
      humidity: 60
      soil_moisture: 38
      light_level: 720
      pump_state: "off"
      light_state: "on"
      updated_at: 1718600000
  /commands             ← phone writes; Pi listens and acts
      pump: "off"       ← set to "on" → Pi switches relay
      light: "on"
  /state                ← Pi writes back what it ACTUALLY did (source of truth)
      pump: "off"
      light: "on"
      camera_online: true
  /webrtc               ← live-video signaling handshake (transient)
      offer: { ... }    ← phone (or Pi) posts SDP offer
      answer: { ... }   ← peer posts SDP answer
      ice_caller: [..]  ← ICE candidates
      ice_callee: [..]
  /settings             ← automation rules, editable from the app
      auto_water_enabled: true
      auto_water_below: 30        # soil moisture %
      auto_water_seconds: 20      # how long to run the pump
      light_schedule_on: "06:00"
      light_schedule_off: "20:00"
      temp_alert_above: 35
  /history              ← (optional) periodic logged readings for charts
      /{timestamp}: { temperature, humidity, soil_moisture, ... }
```

- **Storage:** `gardens/{gardenId}/photos/latest.jpg` (+ timestamped archive).
- **Why command/state split:** the app shows *desired* (command) vs *actual* (state),
  so the UI never lies if the Pi is offline or a relay fails.

### Security rules
- Only authenticated users (Firebase Auth) can read/write their own `/gardens/{uid}`.
- The Pi authenticates with a service account (firebase-admin) — full access to its
  garden node only (admin SDK bypasses these rules).

```json
{
  "rules": {
    "gardens": {
      "$gardenId": {
        ".read":  "auth != null && auth.uid === $gardenId",
        ".write": "auth != null && auth.uid === $gardenId",
        "telemetry": {
          // Pi (admin) writes; clients only read. Admin SDK bypasses rules,
          // so no extra write rule is needed for the Pi here.
          ".write": false
        },
        "state": {
          ".write": false
        },
        "commands": {
          // Phone writes desired state; Pi (admin) reads + clears.
          ".validate": "newData.hasChildren(['pump', 'light']) || true"
        }
      }
    }
  }
}
```

> Using the user's `uid` as the `gardenId` is the simplest 1-user-1-garden model. For
> shared gardens, replace it with a `/gardens/{gardenId}/members/{uid}` membership check.

---

## 4. Raspberry Pi service (Python)

Repo: `pi/`

```
pi/
  main.py                 # entry point: start loops + command listener
  config.py               # GPIO pins, intervals, gardenId, Firebase creds path
  firebase_client.py      # firebase-admin init, read/write helpers
  sensors/
    temperature.py        # DHT22 / BME280 read
    soil.py               # ADS1115 + capacitive sensor read
    light.py              # BH1750 read
  actuators/
    relay.py              # generic relay on/off (pump, light)
  camera/
    webrtc_stream.py      # aiortc + Picamera2 live video; signaling via RTDB /webrtc
  automation/
    rules.py              # auto-water + light schedule + temp alerts
  loops/
    telemetry_loop.py     # read sensors → push telemetry every N sec
    command_loop.py       # listen to /commands → drive actuators → write /state
  requirements.txt        # firebase-admin, RPi.GPIO/gpiozero, adafruit libs, picamera2
  README.md               # wiring diagram + setup + run-on-boot (systemd)
```

**Core loops**
1. **Telemetry loop** — read all sensors, push to `/telemetry` every ~5s; append to
   `/history` every few minutes.
2. **Command loop** — subscribe to `/commands`; on change, switch the relay, confirm
   into `/state`. Handle `capture_photo`.
3. **Automation tick** — evaluate `/settings`: if `soil_moisture < auto_water_below`
   run pump for `auto_water_seconds`; apply light schedule; fire FCM on temp alerts.

**Run on boot** via `systemd` so the garden keeps running headless.

---

## 5. Flutter app

Repo: `app/` — mirror the Zenify Trip structure (Riverpod + GetIt + service/provider).

```
app/lib/
  main.dart
  firebase_options.dart           # from flutterfire configure
  core/
    di/ service_locator.dart      # GetIt
    theme/
  features/
    auth/        # Firebase Auth login
    dashboard/   # temp/humidity/soil/light cards, live telemetry
    controls/    # pump + light toggles (write /commands, reflect /state)
    camera/      # live WebRTC video view (flutter_webrtc)
    settings/    # edit automation thresholds & schedules
    history/     # charts from /history
  services/
    garden_service.dart           # RTDB streams + command writes
    storage_service.dart          # photo URLs from Firebase Storage
  providers/
    telemetry_provider.dart       # StreamProvider on /telemetry
    controls_provider.dart        # command writes + /state stream
    settings_provider.dart
```

**Packages:** `firebase_core`, `firebase_auth`, `firebase_database`,
`firebase_storage`, `firebase_messaging`, `flutter_webrtc`, `flutter_riverpod`,
`get_it`, `fl_chart`.

**Key UX**
- Dashboard auto-updates live (RTDB stream — no refresh button needed).
- Control toggles show "pending" until `/state` confirms the Pi acted.
- Camera tab shows **live WebRTC video** (sub-second), connect/disconnect button.
- Settings tab edits the automation rules that the Pi reads.

---

## 6. Build order (milestones)

1. **Firebase project setup** — create project, enable RTDB + Storage + Auth, set rules,
   generate Pi service-account key and Flutter `firebase_options.dart`.
2. **Pi: telemetry first** — read one sensor (temp), push to RTDB. Verify in console.
3. **Pi: actuators** — relay on/off via `/commands`, confirm `/state`.
4. **Flutter: dashboard + controls** — login, live telemetry, pump/light toggles.
5. **Pi: remaining sensors** — soil moisture (ADS1115), light, humidity.
6. **Live camera (WebRTC)** — `aiortc`+Picamera2 on Pi, `flutter_webrtc` in app,
   signaling via RTDB `/webrtc`. Test on LAN first, then over internet (STUN/TURN).
7. **Automation** — thresholds + schedules + temp alerts (FCM).
8. **History + charts** — log readings, draw real-time-updating graphs in app.
9. **Harden** — run-on-boot (systemd), offline handling, security rules, TURN server.

---

## 7. Open questions / to confirm later
- Firebase free (Spark) plan is fine to start; Storage + frequent writes may later need
  the Blaze (pay-as-you-go) plan.
- ~~DHT22 vs BME280~~ → **resolved: GY-BME280** (in stock in TN, I2C, more accurate).
- How many soil sensors / zones? ADS1115 has **4 channels**, so up to 4 soil sensors on
  one ADC before needing a second board.
- "Animals" 🐾 — any specific needs? (e.g. feeder via a spare relay channel, separate
  temp zone, water level sensor for a drinker?)
- Confirm exact Pi model to buy (Pi 4 2GB is plenty; Pi 5 if you want headroom).

---

## 8. Estimated budget (Tunisia 🇹🇳, indicative TND)

Rough order-of-magnitude — confirm against current shop listings before buying.

| Part | Qty | ~Price (DT) | Notes |
|---|---|---|---|
| Raspberry Pi 4 (2 GB) + PSU | 1 | 220–320 | Pi 3B+ ≈ 135 DT as a cheaper option |
| microSD 32 GB (class 10) | 1 | 25–40 | OS + service |
| GY-BME280 (temp/humidity/pressure) | 1 | 15–25 | I2C |
| Capacitive soil sensor V1.2 | 1 | 10–18 | per zone |
| ADS1115 16-bit ADC | 1 | 20–30 | required for analog soil sensor |
| 4-channel relay (opto-isolated) | 1 | 18–30 | switches pump + lights |
| Water pump 5 V + tubing | 1 | 20–40 | or solenoid valve |
| Pi Camera module 5MP | 1 | 35–60 | for WebRTC stream |
| BH1750 light sensor *(optional)* | 1 | 10–18 | or infer from camera |
| Jumper wires + breadboard + 5 V PSU | — | 25–40 | wiring |
| **Total (core build)** | | **≈ 400–650 DT** | excludes optional/extra zones |

Recurring: Firebase **Spark (free)** to start; expect **Blaze (pay-as-you-go)** once
Storage + frequent RTDB writes + a TURN relay are in play (typically a few DT/month at
this scale).

---

## 9. Testing & validation

- **Sensors:** print raw + converted readings locally on the Pi before wiring to
  Firebase; sanity-check ranges (temp, soil %, light) against a reference.
- **Actuators:** dry-run relays with the pump/light **disconnected** (listen for the
  click + check `/state`) before connecting mains/pump power.
- **Command/state round-trip:** write a command from the Firebase console, confirm the
  Pi acts and writes `/state` back within ~1 s.
- **Camera:** validate WebRTC on the **same LAN** first, then across networks (mobile
  data) to exercise STUN, then behind a strict NAT to confirm the TURN fallback.
- **Automation:** force-trigger each rule (e.g. fake a low soil reading) and verify the
  pump runs for exactly `auto_water_seconds` and stops.
- **Offline resilience:** kill the Pi process / network and confirm the app shows stale
  state clearly (last `updated_at`) instead of pretending the garden is live.