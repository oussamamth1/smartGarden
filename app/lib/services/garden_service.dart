import 'package:firebase_database/firebase_database.dart';

import '../core/garden_refs.dart';
import '../models/camera.dart';
import '../models/room.dart';
import '../models/telemetry.dart';

/// Real-time reads/writes for one garden. Streams update the moment the Pi
/// pushes a change (RTDB live listeners — no polling).
class GardenService {
  GardenService(this._refs);

  final GardenRefs _refs;

  /// The /webrtc signaling node for one camera (offer/answer handshake).
  DatabaseReference webrtcForCamera(String cameraId) =>
      _refs.webrtcForCamera(cameraId);

  // ---- Rooms ----------------------------------------------------------------

  /// Live list of rooms (sorted by name).
  Stream<List<Room>> watchRooms() => _refs.rooms.onValue.map((e) {
        final map = (e.snapshot.value as Map?) ?? {};
        final rooms = [
          for (final entry in map.entries)
            Room.fromMap(
              entry.key.toString(),
              (entry.value as Map?)?['meta'] as Map?,
            )
        ];
        rooms.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return rooms;
      });

  /// Create a room with a generated id; seeds default climate settings.
  Future<void> addRoom(String name) async {
    final ref = _refs.rooms.push();
    await ref.child('meta').set({'name': name});
    await ref.child('settings').set({
      'auto_climate_enabled': false,
      'target_temp': 22,
      'temp_alert_above': 30,
    });
  }

  Future<void> renameRoom(String id, String name) =>
      _refs.room(id).child('meta').update({'name': name});

  Future<void> deleteRoom(String id) => _refs.room(id).remove();

  Stream<RoomTelemetry> watchRoomTelemetry(String id) =>
      _refs.room(id).child('telemetry').onValue.map(
            (e) => RoomTelemetry.fromMap(e.snapshot.value as Map?),
          );

  Stream<RoomState> watchRoomState(String id) =>
      _refs.room(id).child('state').onValue.map(
            (e) => RoomState.fromMap(e.snapshot.value as Map?),
          );

  Stream<Map<dynamic, dynamic>> watchRoomSettings(String id) => _refs
      .room(id)
      .child('settings')
      .onValue
      .map((e) => (e.snapshot.value as Map?) ?? {});

  /// Toggle a room device (heater/fan/light) — the Pi confirms via /state.
  Future<void> setRoomDevice(String id, String device, bool on) =>
      _refs.room(id).child('commands').update({device: on ? 'on' : 'off'});

  Future<void> updateRoomSettings(String id, Map<String, dynamic> values) =>
      _refs.room(id).child('settings').update(values);

  /// Live list of cameras the Pi has published under /cameras.
  Stream<List<CameraInfo>> watchCameras() => _refs.cameras.onValue.map((e) {
        final map = (e.snapshot.value as Map?) ?? {};
        final cams = [
          for (final entry in map.entries)
            CameraInfo.fromMap(
              entry.key.toString(),
              (entry.value as Map?)?['meta'] as Map?,
            )
        ];
        cams.sort((a, b) => a.id.compareTo(b.id));
        return cams;
      });

  Stream<Telemetry> watchTelemetry() => _refs.telemetry.onValue
      .map((e) => Telemetry.fromMap(e.snapshot.value as Map?));

  Stream<GardenState> watchState() => _refs.state.onValue
      .map((e) => GardenState.fromMap(e.snapshot.value as Map?));

  Stream<Map<dynamic, dynamic>> watchSettings() => _refs.settings.onValue
      .map((e) => (e.snapshot.value as Map?) ?? {});

  /// Recent logged readings for charts, oldest-first. Updates live as the Pi
  /// appends to /history.
  Stream<List<Telemetry>> watchHistory({int limit = 100}) =>
      _refs.history.orderByKey().limitToLast(limit).onValue.map((e) {
        final map = (e.snapshot.value as Map?) ?? {};
        final keys = map.keys.toList()..sort();
        return [for (final k in keys) Telemetry.fromMap(map[k] as Map?)];
      });

  /// Write a desired command. The Pi acts on it and confirms via /state.
  Future<void> setPump(bool on) =>
      _refs.commands.update({'pump': on ? 'on' : 'off'});

  Future<void> setLight(bool on) =>
      _refs.commands.update({'light': on ? 'on' : 'off'});

  Future<void> updateSettings(Map<String, dynamic> values) =>
      _refs.settings.update(values);
}
