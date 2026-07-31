import "dart:typed_data";

import "package:gal/gal.dart";
import "package:injectable/injectable.dart";

/// Injectable seam around Gal's static plugin API.
@lazySingleton
class GalClient {
  Future<bool> hasAccess() => Gal.hasAccess();

  Future<bool> requestAccess() => Gal.requestAccess();

  Future<void> putImageBytes({required Uint8List bytes, required String name}) => Gal.putImageBytes(bytes, name: name);
}
