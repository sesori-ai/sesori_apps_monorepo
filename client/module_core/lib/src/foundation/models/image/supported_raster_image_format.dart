import "dart:typed_data";

/// Raster formats that the shared transcript renderer accepts.
enum SupportedRasterImageFormat({
  required final String mime,
  required final String filenameExtension,
}) {
  bmp(mime: "image/bmp", filenameExtension: ".bmp"),
  gif(mime: "image/gif", filenameExtension: ".gif"),
  jpeg(mime: "image/jpeg", filenameExtension: ".jpg"),
  png(mime: "image/png", filenameExtension: ".png"),
  webp(mime: "image/webp", filenameExtension: ".webp");

  bool hasExpectedSignature({required Uint8List bytes}) => switch (this) {
    SupportedRasterImageFormat.bmp => _startsWith(bytes: bytes, signature: const [0x42, 0x4D]),
    SupportedRasterImageFormat.gif =>
      _startsWith(bytes: bytes, signature: const [0x47, 0x49, 0x46, 0x38, 0x37, 0x61]) ||
          _startsWith(bytes: bytes, signature: const [0x47, 0x49, 0x46, 0x38, 0x39, 0x61]),
    SupportedRasterImageFormat.jpeg => _startsWith(bytes: bytes, signature: const [0xFF, 0xD8, 0xFF]),
    SupportedRasterImageFormat.png => _startsWith(
      bytes: bytes,
      signature: const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    ),
    SupportedRasterImageFormat.webp =>
      _startsWith(bytes: bytes, signature: const [0x52, 0x49, 0x46, 0x46]) &&
          _startsWith(bytes: bytes, signature: const [0x57, 0x45, 0x42, 0x50], offset: 8),
  };
}

SupportedRasterImageFormat? supportedRasterImageFormatForMime({required String mime}) {
  final normalizedMime = mime.split(";").first.trim().toLowerCase();
  for (final format in SupportedRasterImageFormat.values) {
    if (format.mime == normalizedMime) return format;
  }
  return null;
}

SupportedRasterImageFormat? detectSupportedRasterImageFormat({required Uint8List bytes}) {
  for (final format in SupportedRasterImageFormat.values) {
    if (format.hasExpectedSignature(bytes: bytes)) return format;
  }
  return null;
}

bool _startsWith({
  required Uint8List bytes,
  required List<int> signature,
  int offset = 0,
}) {
  if (bytes.length < offset + signature.length) return false;
  for (var index = 0; index < signature.length; index++) {
    if (bytes[offset + index] != signature[index]) return false;
  }
  return true;
}
