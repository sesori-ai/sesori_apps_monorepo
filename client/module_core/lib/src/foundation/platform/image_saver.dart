import "dart:typed_data";

enum ImageSaveResult() { saved, accessDenied, cancelled }

/// Saves image bytes to the destination appropriate for the current platform.
abstract interface class ImageSaver() {
  Future<ImageSaveResult> saveImage({
    required Uint8List bytes,
    required String mime,
    required String filename,
  });
}
