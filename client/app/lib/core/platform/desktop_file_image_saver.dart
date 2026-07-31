import "dart:typed_data";

import "package:sesori_dart_core/sesori_dart_core.dart";

import "file_save_client.dart";

class DesktopFileImageSaver implements ImageSaver {
  final FileSaveClient _fileSaveClient;

  DesktopFileImageSaver({required FileSaveClient fileSaveClient}) : _fileSaveClient = fileSaveClient;

  @override
  bool get isSupported => true;

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
