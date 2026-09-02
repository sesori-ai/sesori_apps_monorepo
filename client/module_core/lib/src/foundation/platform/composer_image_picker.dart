import "dart:typed_data";

/// Product-shell seam for choosing one image for a composer.
///
/// Implementations own the platform picker and return raw bytes. Validation,
/// MIME sniffing, and transport limits remain in the composer attachment service.
abstract interface class ComposerImagePicker() {
  Future<ComposerPickedImage?> pickImage();
}

final class const ComposerPickedImage({
  required final Uint8List bytes,
  required final String? filename,
});
