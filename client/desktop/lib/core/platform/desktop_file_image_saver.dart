import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "desktop_file_save_client.dart";

@LazySingleton(as: ImageSaver)
class DesktopFileImageSaver({required final DesktopFileSaveClient _fileSaveClient}) implements ImageSaver {
  @override
  Future<ImageSaveResult> saveImage({
    required Uint8List bytes,
    required String mime,
    required String filename,
  }) async {
    final saved = await _fileSaveClient.saveFile(bytes: bytes, mime: mime, filename: filename);
    return saved ? ImageSaveResult.saved : ImageSaveResult.cancelled;
  }
}
