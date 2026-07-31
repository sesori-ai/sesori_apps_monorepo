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
  /// inline transport limit.
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
    if (bytes.length > maxInlineMessageAttachmentBytes) {
      throw const AttachmentTooLargeError();
    }

    final name = file.name.trim();
    return ComposerAttachment(
      mime: _sniffImageMime(bytes: bytes),
      bytes: bytes,
      filename: name.isEmpty ? null : name,
    );
  }

  /// Content sniffing beats the picker's metadata: `XFile.mimeType` is
  /// platform-dependent (usually null on iOS/Android) and file extensions
  /// lie after the picker's JPEG re-encode.
  static String _sniffImageMime({required Uint8List bytes}) {
    bool startsWith(List<int> signature, {int offset = 0}) {
      if (bytes.length < offset + signature.length) return false;
      for (var i = 0; i < signature.length; i++) {
        if (bytes[offset + i] != signature[i]) return false;
      }
      return true;
    }

    if (startsWith(const [0xFF, 0xD8, 0xFF])) return "image/jpeg";
    if (startsWith(const [0x89, 0x50, 0x4E, 0x47])) return "image/png";
    if (startsWith(const [0x47, 0x49, 0x46, 0x38])) return "image/gif";
    if (startsWith(const [0x52, 0x49, 0x46, 0x46]) && startsWith(const [0x57, 0x45, 0x42, 0x50], offset: 8)) {
      return "image/webp";
    }
    // "ftypheic" / "ftypheif" at offset 4 marks HEIF containers.
    if (startsWith(const [0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69], offset: 4)) {
      return "image/heic";
    }
    return "image/jpeg";
  }
}
