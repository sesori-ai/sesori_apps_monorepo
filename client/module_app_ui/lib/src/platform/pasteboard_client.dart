import "dart:typed_data";

import "package:pasteboard/pasteboard.dart";

/// Seam around Pasteboard's static plugin API, so tests can replace it.
class PasteboardClient() {
  Future<Uint8List?> readImage() => Pasteboard.image;

  Future<void> writeImage({required Uint8List bytes}) => Pasteboard.writeImage(bytes);
}
