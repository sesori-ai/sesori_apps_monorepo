import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;

import "../foundation/models/composer/composer_attachment.dart";
import "../foundation/models/image/supported_raster_image_format.dart";
import "../foundation/platform/composer_image_picker.dart";
import "../logging/logging.dart";
import "composer_image_downscale_builder.dart";

/// The chosen bytes are not a recognized image format that the transcript
/// renderer can decode honestly.
final class const UnsupportedAttachmentImageError() implements Exception;

/// Dispatches platform picks and clipboard bytes through the shared composer
/// attachment validation pipeline.
@lazySingleton
class ComposerAttachmentDispatcher({
  required final ComposerImagePicker _imagePicker,
  required final ComposerImageDownscaleBuilder _downscaleBuilder,
}) {
  Future<ComposerAttachment?> pickImage() async {
    final image = await _imagePicker.pickImage();
    if (image == null) return null;
    return await attachmentFromBytes(bytes: image.bytes, filename: image.filename);
  }

  /// Validates [bytes] as a supported image and shrinks an oversized one
  /// before the transport limit is checked, so a large screenshot can still
  /// fit once downscaled.
  Future<ComposerAttachment> attachmentFromBytes({
    required Uint8List bytes,
    required String? filename,
  }) async {
    final format = detectSupportedRasterImageFormat(bytes: bytes);
    if (format == null) throw const UnsupportedAttachmentImageError();

    final trimmedName = filename?.trim();
    final name = trimmedName == null || trimmedName.isEmpty ? null : trimmedName;
    final original = ComposerAttachment(mime: format.mime, bytes: bytes, filename: name);
    final ComposerAttachment attachment;
    switch (await _downscaleBuilder.downscale(bytes: bytes, format: format)) {
      case ComposerImageDownscaled(bytes: final downscaled):
        const jpeg = SupportedRasterImageFormat.jpeg;
        attachment = ComposerAttachment(
          mime: jpeg.mime,
          bytes: downscaled,
          filename: name == null ? null : path.setExtension(name, jpeg.filenameExtension),
        );
      case ComposerImageKept():
        attachment = original;
      case ComposerImageDownscaleFailed(:final cause, :final stackTrace):
        logw("Downscaling a ${format.mime} composer image failed; staging the original", cause, stackTrace);
        attachment = original;
    }

    if (attachment.bytes.length > maxComposerPromptAttachmentBytes) {
      throw const AttachmentTooLargeError();
    }
    return attachment;
  }
}
