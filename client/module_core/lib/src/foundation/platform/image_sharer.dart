import "dart:typed_data";

final class const ImageShareOrigin({
  required final double left,
  required final double top,
  required final double width,
  required final double height,
});

/// Shares image bytes through the platform share surface.
abstract interface class ImageSharer() {
  Future<void> shareImage({
    required Uint8List bytes,
    required String mime,
    required String filename,
    required ImageShareOrigin? origin,
  });
}
