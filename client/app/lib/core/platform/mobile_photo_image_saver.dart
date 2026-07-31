import "dart:typed_data";

import "package:sesori_dart_core/sesori_dart_core.dart";

import "gal_client.dart";

class MobilePhotoImageSaver implements ImageSaver {
  final GalClient _galClient;

  MobilePhotoImageSaver({required GalClient galClient}) : _galClient = galClient;

  @override
  bool get isSupported => true;

  @override
  Future<ImageSaveResult> saveImage({
    required Uint8List bytes,
    required String mime,
    required String filename,
  }) async {
    final hasAccess = await _galClient.hasAccess() || await _galClient.requestAccess();
    if (!hasAccess) return ImageSaveResult.accessDenied;
    await _galClient.putImageBytes(
      bytes: bytes,
      name: _nameWithoutExtension(filename: filename),
    );
    return ImageSaveResult.saved;
  }

  String _nameWithoutExtension({required String filename}) {
    final extensionStart = filename.lastIndexOf(".");
    return extensionStart > 0 ? filename.substring(0, extensionStart) : filename;
  }
}
