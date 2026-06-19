/// A camera published by the Pi under /gardens/{id}/cameras/{cameraId}.
class CameraInfo {
  const CameraInfo({required this.id, required this.name});

  final String id;
  final String name;

  factory CameraInfo.fromMap(String id, Map<dynamic, dynamic>? meta) {
    return CameraInfo(
      id: id,
      name: (meta?['name'] as String?) ?? id,
    );
  }
}
