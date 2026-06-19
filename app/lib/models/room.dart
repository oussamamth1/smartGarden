/// A room/zone in the garden, created by the user under
/// /gardens/{id}/rooms/{roomId}.
class Room {
  const Room({required this.id, required this.name});

  final String id;
  final String name;

  factory Room.fromMap(String id, Map<dynamic, dynamic>? meta) {
    return Room(id: id, name: (meta?['name'] as String?) ?? id);
  }
}

/// A room's live sensor reading (from /rooms/{id}/telemetry).
class RoomTelemetry {
  const RoomTelemetry({this.temperature, this.humidity, this.updatedAt});

  final double? temperature; // °C
  final double? humidity; // %
  final int? updatedAt;

  static double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

  factory RoomTelemetry.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const RoomTelemetry();
    return RoomTelemetry(
      temperature: _d(map['temperature']),
      humidity: _d(map['humidity']),
      updatedAt: (map['updated_at'] as num?)?.toInt(),
    );
  }
}

/// A room's confirmed device state (from /rooms/{id}/state).
class RoomState {
  const RoomState({this.heater = false, this.fan = false, this.light = false});

  final bool heater;
  final bool fan;
  final bool light;

  static bool _b(dynamic v) => v == true || v == 'on' || v == 'ON' || v == 1;

  factory RoomState.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const RoomState();
    return RoomState(
      heater: _b(map['heater']),
      fan: _b(map['fan']),
      light: _b(map['light']),
    );
  }
}
