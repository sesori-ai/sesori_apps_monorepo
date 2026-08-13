import "dart:typed_data";

/// Reads and writes image bytes on the platform clipboard.
abstract interface class ImageClipboard() {
  Future<Uint8List?> readImage();

  Future<void> writeImage({required Uint8List bytes});
}
