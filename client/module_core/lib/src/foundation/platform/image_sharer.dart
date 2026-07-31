import "dart:typed_data";

final class ImageShareOrigin {
  final double left;
  final double top;
  final double width;
  final double height;

  const ImageShareOrigin({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });
}

/// Shares image bytes through the platform share surface.
abstract interface class ImageSharer {
  Future<void> shareImage({
    required Uint8List bytes,
    required String mime,
    required String filename,
    required ImageShareOrigin? origin,
  });
}
