import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:pasteboard/pasteboard.dart";

/// Injectable seam around Pasteboard's static desktop plugin API.
@lazySingleton
class DesktopPasteboardClient() {
  Future<Uint8List?> readImage() => Pasteboard.image;

  Future<void> writeImage({required Uint8List bytes}) => Pasteboard.writeImage(bytes);
}
