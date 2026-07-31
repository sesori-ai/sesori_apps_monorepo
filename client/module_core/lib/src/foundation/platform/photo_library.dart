import "dart:typed_data";

enum PhotoLibrarySaveResult { saved, accessDenied }

/// Saves image bytes to the user's platform photo library.
abstract interface class PhotoLibrary {
  Future<PhotoLibrarySaveResult> saveImage({
    required Uint8List bytes,
    required String filename,
  });
}
