import 'package:firebase_storage/firebase_storage.dart';

/// Reads photo URLs from Firebase Storage: gardens/{id}/photos/latest.jpg
/// (and the timestamped archive). The Pi uploads; the app only reads.
class StorageService {
  StorageService(this.gardenId);

  final String gardenId;

  Reference get _photos =>
      FirebaseStorage.instance.ref('gardens/$gardenId/photos');

  /// Download URL for the most recent still photo.
  Future<String> latestPhotoUrl() => _photos.child('latest.jpg').getDownloadURL();

  /// URLs of archived photos (most recent first).
  Future<List<String>> archiveUrls() async {
    final result = await _photos.child('archive').listAll();
    final items = result.items.reversed.toList();
    return Future.wait(items.map((r) => r.getDownloadURL()));
  }
}
