# Garden Pi — Flutter app

Real-time phone app: live dashboard, pump/light controls, camera, settings.

## Setup

This folder holds the `lib/` source and `pubspec.yaml`. Generate the platform
folders and Firebase config once:

```bash
cd app
flutter create .                 # adds android/ ios/ etc. around lib/
flutter pub get

# Firebase wiring
dart pub global activate flutterfire_cli
flutterfire configure            # creates lib/firebase_options.dart
```

Then in `lib/main.dart`, uncomment the two `firebase_options` lines.

## Run

```bash
flutter run
```

Set `kGardenId` in `lib/providers/garden_providers.dart` to match `GARDEN_ID`
on the Pi (default `garden1`).

## Layout

- `core/garden_refs.dart` — Realtime Database paths
- `models/telemetry.dart` — Telemetry + GardenState models
- `services/garden_service.dart` — live streams + command writes + history
- `services/auth_service.dart` — Firebase Auth (email/password)
- `services/storage_service.dart` — photo URLs from Firebase Storage
- `providers/garden_providers.dart` — Riverpod providers (auth, telemetry, state, settings, history)
- `features/auth/` — login / register (the auth gate lives in `main.dart`)
- `features/home/` — bottom-nav shell tying the tabs together
- `features/dashboard/` — live sensor cards
- `features/rooms/` — user-managed rooms (add/rename/delete); per-room temp, device toggles (heater/fan/light) + climate settings
- `features/controls/` — pump / light switches (reflect /state)
- `features/camera/` — live WebRTC view (offer/answer signaling via `/webrtc`)
- `features/settings/` — edit automation thresholds & schedules
- `features/history/` — fl_chart graphs over /history

## How real-time works

Every provider is a `StreamProvider` over an RTDB `onValue` stream, so the UI
rebuilds the instant the Pi pushes a change — no polling, no refresh button.
Controls write to `/commands`; the switches reflect `/state` (what the Pi
confirms), so the UI never lies.

## Live camera (WebRTC)

The camera tab works end-to-end: the phone creates an SDP offer (waiting for ICE
gathering so the SDP is complete), writes it to `/gardens/{id}/webrtc/offer`, and
applies the Pi's answer from `/webrtc/answer`. Video then flows peer-to-peer
Pi → phone; Firebase is only the signaling channel. On a real Pi it streams the
camera module; in mock mode the Pi streams a synthetic test pattern.

## Still to build

- **FCM push alerts** — handle the temp-alert messages the Pi sends.
- **Photo gallery** — `StorageService` is ready; add a view for the archive.
- **TURN relay** — STUN-only today; add TURN for strict/cellular NATs (milestone 9).
