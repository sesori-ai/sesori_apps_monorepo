import "dart:typed_data";

import "package:injectable/injectable.dart";

import "../foundation/models/composer/composer_attachment.dart";
import "../foundation/platform/composer_image_picker.dart";

/// The chosen image cannot be sent inline because it exceeds the composer
/// transport limit.
final class const AttachmentTooLargeError() implements Exception;

/// The chosen bytes are not a recognized image format that the transcript
/// renderer can decode honestly.
final class const UnsupportedAttachmentImageError() implements Exception;

/// Dispatches platform picks and clipboard bytes through the shared composer
/// attachment validation pipeline.
@lazySingleton
class ComposerAttachmentDispatcher({
  required final ComposerImagePicker _imagePicker,
}) {
  Future<ComposerAttachment?> pickImage() async {
    final image = await _imagePicker.pickImage();
    if (image == null) return null;
    return attachmentFromBytes(bytes: image.bytes, filename: image.filename);
  }

  ComposerAttachment attachmentFromBytes({
    required Uint8List bytes,
    required String? filename,
  }) {
    if (bytes.length > maxComposerPromptAttachmentBytes) {
      throw const AttachmentTooLargeError();
    }

    final mime = _sniffImageMime(bytes: bytes);
    if (mime == null) throw const UnsupportedAttachmentImageError();

    final name = filename?.trim();
    return ComposerAttachment(
      mime: mime,
      bytes: bytes,
      filename: name == null || name.isEmpty ? null : name,
    );
  }

  /// Content sniffing is authoritative because picker metadata and extensions
  /// can be absent or wrong. The accepted signatures mirror the transcript
  /// image renderer, so every staged image can render after sending.
  static String? _sniffImageMime({required Uint8List bytes}) {
    bool startsWith(List<int> signature, {int offset = 0}) {
      if (bytes.length < offset + signature.length) return false;
      for (var index = 0; index < signature.length; index++) {
        if (bytes[offset + index] != signature[index]) return false;
      }
      return true;
    }

    if (startsWith(const [0xFF, 0xD8, 0xFF])) return "image/jpeg";
    if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return "image/png";
    if (startsWith(const [0x47, 0x49, 0x46, 0x38, 0x37, 0x61]) ||
        startsWith(const [0x47, 0x49, 0x46, 0x38, 0x39, 0x61])) {
      return "image/gif";
    }
    if (startsWith(const [0x52, 0x49, 0x46, 0x46]) && startsWith(const [0x57, 0x45, 0x42, 0x50], offset: 8)) {
      return "image/webp";
    }
    if (startsWith(const [0x42, 0x4D])) return "image/bmp";
    return null;
  }
}
