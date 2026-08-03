import "dart:typed_data";

import "package:image_picker/image_picker.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";

/// The picked image cannot be sent inline: even after the picker's downscale
/// pass it decodes past [maxInlineMessageAttachmentBytes].
final class AttachmentTooLargeError implements Exception {
  const AttachmentTooLargeError();
}

/// The picked file's content is not a recognized image format, so it cannot
/// be labeled with an honest mime type for the backend.
final class UnsupportedAttachmentImageError implements Exception {
  const UnsupportedAttachmentImageError();
}

/// Stages gallery images as inline composer attachments.
///
/// Picks are re-encoded down to a bounded longest edge and JPEG quality so a
/// modern camera photo lands well under the inline transport limit; the limit
/// is still enforced afterwards because animated/exotic formats can skip the
/// downscale pass.
@lazySingleton
class ComposerImagePicker {
  final ImagePicker _picker;

  ComposerImagePicker({required ImagePicker picker}) : _picker = picker;

  /// Longest-edge cap for picked images. Plenty for a model reading a
  /// screenshot or photo, and it keeps the base64 payload a relay frame
  /// carries per image in the low hundreds of kilobytes.
  static const double _maxDimension = 2048;
  static const int _jpegQuality = 85;

  /// Returns the staged attachment, or null when the user dismissed the
  /// picker. Throws [AttachmentTooLargeError] when the image cannot fit the
  /// inline transport limit, and [UnsupportedAttachmentImageError] when the
  /// content is not a recognized image format.
  Future<ComposerAttachment?> pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _jpegQuality,
      requestFullMetadata: false,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    // Judge size by the conservative decoded estimate of the base64 form the
    // wire carries, so anything accepted here also passes receivers using the
    // shared [isInlineMessageAttachmentWithinSizeLimit] check.
    final base64Length = 4 * ((bytes.length + 2) ~/ 3);
    if (!isInlineMessageAttachmentWithinSizeLimit(base64Length: base64Length)) {
      throw const AttachmentTooLargeError();
    }

    final mime = _sniffImageMime(bytes: bytes);
    if (mime == null) throw const UnsupportedAttachmentImageError();

    final name = file.name.trim();
    return ComposerAttachment(
      mime: mime,
      bytes: bytes,
      filename: name.isEmpty ? null : name,
    );
  }

  /// Content sniffing beats the picker's metadata: `XFile.mimeType` is
  /// platform-dependent (usually null on iOS/Android) and file extensions
  /// lie after the picker's JPEG re-encode. Null means the content is not a
  /// format this client's own inline renderer decodes — the accepted set and
  /// signatures mirror `MessageImageRepository`, so anything staged here also
  /// renders in message history. HEIF is deliberately absent: the renderer
  /// cannot decode it, and iOS re-encodes HEIC picks to JPEG anyway.
  static String? _sniffImageMime({required Uint8List bytes}) {
    bool startsWith(List<int> signature, {int offset = 0}) {
      if (bytes.length < offset + signature.length) return false;
      for (var i = 0; i < signature.length; i++) {
        if (bytes[offset + i] != signature[i]) return false;
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
