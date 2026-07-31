import "dart:typed_data";

import "package:file_selector/file_selector.dart";
import "package:injectable/injectable.dart";

/// Injectable seam around file_selector's static plugin API.
@lazySingleton
class FileSaveClient {
  Future<bool> saveFile({
    required Uint8List bytes,
    required String mime,
    required String filename,
  }) async {
    final location = await getSaveLocation(suggestedName: filename);
    if (location == null) return false;
    await XFile.fromData(bytes, mimeType: mime, name: filename).saveTo(location.path);
    return true;
  }
}
