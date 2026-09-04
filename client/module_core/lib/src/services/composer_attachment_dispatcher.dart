import "dart:typed_data";

import "package:injectable/injectable.dart";

import "../foundation/models/composer/composer_attachment.dart";
import "../foundation/models/image/supported_raster_image_format.dart";
import "../foundation/platform/composer_image_picker.dart";

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

    final format = detectSupportedRasterImageFormat(bytes: bytes);
    if (format == null) throw const UnsupportedAttachmentImageError();

    final name = filename?.trim();
    return ComposerAttachment(
      mime: format.mime,
      bytes: bytes,
      filename: name == null || name.isEmpty ? null : name,
    );
  }
}
