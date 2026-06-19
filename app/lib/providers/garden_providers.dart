import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/garden_refs.dart';
import '../models/camera.dart';
import '../models/room.dart';
import '../models/telemetry.dart';
import '../services/auth_service.dart';
import '../services/garden_service.dart';
import '../services/storage_service.dart';

/// Change this to match GARDEN_ID on the Pi.
///
/// For a 1-user-1-garden setup you can instead use the signed-in user's uid
/// (see `authStateProvider`) so it lines up with the security rules.
const String kGardenId = 'garden1';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Live auth state — drives the login gate in main.dart.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authState();
});

final gardenServiceProvider = Provider<GardenService>((ref) {
  return GardenService(GardenRefs(kGardenId));
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(kGardenId);
});

/// Live sensor stream — the dashboard rebuilds on every Pi push (~1s).
final telemetryProvider = StreamProvider<Telemetry>((ref) {
  return ref.watch(gardenServiceProvider).watchTelemetry();
});

/// Live actual state (what the Pi confirms it is doing).
final stateProvider = StreamProvider<GardenState>((ref) {
  return ref.watch(gardenServiceProvider).watchState();
});

/// True when the Pi has pushed telemetry recently. The Pi can't reach Firebase
/// without internet, so stale/absent telemetry means it's offline (e.g. WiFi
/// not set up yet). Re-checked every few seconds since "going stale" is the
/// absence of new events.
const int kPiOfflineAfterSec = 30;

final piOnlineProvider = StreamProvider<bool>((ref) async* {
  // Keep telemetry subscribed without rebuilding this stream on every push.
  ref.listen(telemetryProvider, (_, __) {});
  while (true) {
    final t = ref.read(telemetryProvider).asData?.value;
    final updatedAt = t?.updatedAt;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    yield updatedAt != null && (nowSec - updatedAt) < kPiOfflineAfterSec;
    await Future<void>.delayed(const Duration(seconds: 5));
  }
});

/// Live automation settings.
final settingsProvider = StreamProvider<Map<dynamic, dynamic>>((ref) {
  return ref.watch(gardenServiceProvider).watchSettings();
});

/// Live history (recent logged readings) for the charts.
final historyProvider = StreamProvider<List<Telemetry>>((ref) {
  return ref.watch(gardenServiceProvider).watchHistory();
});

/// Live list of cameras the Pi has published.
final camerasProvider = StreamProvider<List<CameraInfo>>((ref) {
  return ref.watch(gardenServiceProvider).watchCameras();
});

/// Live list of rooms.
final roomsProvider = StreamProvider<List<Room>>((ref) {
  return ref.watch(gardenServiceProvider).watchRooms();
});

/// Per-room live streams (keyed by room id).
final roomTelemetryProvider =
    StreamProvider.family<RoomTelemetry, String>((ref, id) {
  return ref.watch(gardenServiceProvider).watchRoomTelemetry(id);
});

final roomStateProvider = StreamProvider.family<RoomState, String>((ref, id) {
  return ref.watch(gardenServiceProvider).watchRoomState(id);
});

final roomSettingsProvider =
    StreamProvider.family<Map<dynamic, dynamic>, String>((ref, id) {
  return ref.watch(gardenServiceProvider).watchRoomSettings(id);
});
