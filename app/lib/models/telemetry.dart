/// A live snapshot of the garden's sensors, read from /telemetry.
class Telemetry {
  const Telemetry({
    this.temperature,
    this.humidity,
    this.pressure,
    this.soilMoisture,
    this.lightLevel,
    this.updatedAt,
  });

  final double? temperature; // °C
  final double? humidity; // %
  final double? pressure; // hPa
  final double? soilMoisture; // %
  final double? lightLevel; // lux
  final int? updatedAt; // unix seconds

  static double? _d(dynamic v) => v == null ? null : (v as num).toDouble();

  factory Telemetry.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const Telemetry();
    return Telemetry(
      temperature: _d(map['temperature']),
      humidity: _d(map['humidity']),
      pressure: _d(map['pressure']),
      soilMoisture: _d(map['soil_moisture']),
      lightLevel: _d(map['light_level']),
      updatedAt: (map['updated_at'] as num?)?.toInt(),
    );
  }
}

/// What the Pi reports it is ACTUALLY doing, read from /state.
class GardenState {
  const GardenState({this.pump = false, this.light = false, this.cameraOnline = false});

  final bool pump;
  final bool light;
  final bool cameraOnline;

  static bool _b(dynamic v) => v == true || v == 'on' || v == 'ON' || v == 1;

  factory GardenState.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const GardenState();
    return GardenState(
      pump: _b(map['pump']),
      light: _b(map['light']),
      cameraOnline: _b(map['camera_online']),
    );
  }
}
