import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "gal_client.dart";

@LazySingleton(as: PhotoLibrary)
class FlutterPhotoLibrary implements PhotoLibrary {
  final GalClient _galClient;

  FlutterPhotoLibrary({required GalClient galClient}) : _galClient = galClient;

  @override
  Future<PhotoLibrarySaveResult> saveImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final hasAccess = await _galClient.hasAccess() || await _galClient.requestAccess();
    if (!hasAccess) return PhotoLibrarySaveResult.accessDenied;
    await _galClient.putImageBytes(
      bytes: bytes,
      name: _nameWithoutExtension(filename: filename),
    );
    return PhotoLibrarySaveResult.saved;
  }

  String _nameWithoutExtension({required String filename}) {
    final extensionStart = filename.lastIndexOf(".");
    return extensionStart > 0 ? filename.substring(0, extensionStart) : filename;
  }
}
