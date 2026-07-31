import "dart:typed_data";

import "package:gal/gal.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

@LazySingleton(as: PhotoLibrary)
class FlutterPhotoLibrary implements PhotoLibrary {
  @override
  Future<PhotoLibrarySaveResult> saveImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final hasAccess = await Gal.hasAccess() || await Gal.requestAccess();
    if (!hasAccess) return PhotoLibrarySaveResult.accessDenied;
    await Gal.putImageBytes(bytes, name: _nameWithoutExtension(filename: filename));
    return PhotoLibrarySaveResult.saved;
  }

  String _nameWithoutExtension({required String filename}) {
    final extensionStart = filename.lastIndexOf(".");
    return extensionStart > 0 ? filename.substring(0, extensionStart) : filename;
  }
}
