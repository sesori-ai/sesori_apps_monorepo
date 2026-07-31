import "dart:typed_data";

import "package:sesori_dart_core/sesori_dart_core.dart";

class UnsupportedImageSaver implements ImageSaver {
  @override
  bool get isSupported => false;

  @override
  Future<ImageSaveResult> saveImage({
    required Uint8List bytes,
    required String mime,
    required String filename,
  }) async => ImageSaveResult.cancelled;
}
