import 'package:firebase_database/firebase_database.dart';

/// Realtime Database URL for the garden-pi-app project (us-central1 default
/// instance). Set explicitly because firebase_options.dart only carries it
/// after the RTDB instance exists; pinning it here works regardless.
const String kDatabaseUrl = 'https://garden-pi-app-default-rtdb.firebaseio.com';

/// Central place for the garden's Realtime Database paths.
class GardenRefs {
  GardenRefs(this.gardenId);

  /// Which garden this app controls (matches GARDEN_ID on the Pi).
  final String gardenId;

  DatabaseReference get _root => FirebaseDatabase.instance
      .refFromURL('$kDatabaseUrl/gardens/$gardenId');

  DatabaseReference get telemetry => _root.child('telemetry');
  DatabaseReference get commands => _root.child('commands');
  DatabaseReference get state => _root.child('state');
  DatabaseReference get settings => _root.child('settings');
  DatabaseReference get history => _root.child('history');

  /// All rooms (each child is a room id with `meta`/`telemetry`/`commands`/
  /// `state`/`settings`).
  DatabaseReference get rooms => _root.child('rooms');
  DatabaseReference room(String roomId) => rooms.child(roomId);

  /// All cameras (each child is a camera id with `meta` + `webrtc`).
  DatabaseReference get cameras => _root.child('cameras');

  /// The /webrtc signaling node for one camera (offer/answer handshake).
  DatabaseReference webrtcForCamera(String cameraId) =>
      cameras.child(cameraId).child('webrtc');
}
