import "dart:typed_data";

/// Writes image bytes to the platform clipboard.
abstract interface class ImageClipboard {
  Future<void> writeImage({required Uint8List bytes});
}
