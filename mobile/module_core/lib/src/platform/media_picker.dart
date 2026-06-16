import "dart:typed_data";

/// A single piece of media selected by the user, held in memory.
///
/// [bytes] are the raw file contents, [mimeType] is the detected content type
/// (e.g. `image/png`), and [filename] is the original name when the platform
/// exposes it.
class PickedMedia {
  final Uint8List bytes;
  final String mimeType;
  final String? filename;

  const PickedMedia({
    required this.bytes,
    required this.mimeType,
    required this.filename,
  });
}

/// Platform-agnostic image picker.
///
/// Flutter apps delegate to `image_picker`; other platforms can provide their
/// own implementation. Each method returns the selected image, or `null` when
/// the user cancels. Implementations throw [MediaPickerException] on failure
/// (e.g. permission denied, decode error).
abstract class MediaPicker {
  /// Pick a single image from the photo library. Returns `null` if cancelled.
  Future<PickedMedia?> pickImageFromGallery();

  /// Capture a single image with the camera. Returns `null` if cancelled.
  Future<PickedMedia?> pickImageFromCamera();
}

/// Thrown when picking media fails for a reason other than user cancellation.
class MediaPickerException implements Exception {
  final String message;

  const MediaPickerException(this.message);

  @override
  String toString() => "MediaPickerException: $message";
}
