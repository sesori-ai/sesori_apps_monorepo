import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:acp_plugin/acp_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart"
    show isInlineMessageAttachmentWithinSizeLimit, maxInlineMessageAttachmentBytes;

/// Reads Cursor `cursor/generate_image` host paths from the local filesystem
/// and maps the bytes into the same bounded inline-image content blocks used
/// for standard ACP assistant images. Named a reader, not a mapper: filesystem
/// access is repository-role work, which is why it lives outside `mappers/`.
///
/// Local paths never leave this class over the transport; only basename
/// metadata and inline bytes cross the plugin boundary. Local bridge logs do
/// keep the path — that is sanctioned diagnostic context, not payload leakage.
final class CursorGeneratedImageReader {
  const CursorGeneratedImageReader();

  List<AcpMappedImageContentBlock> read({required String path}) {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      Log.w("[cursor] generate_image dropped: empty source path");
      return const [];
    }

    final basename = normalizePluginMessageAttachmentFilename(
      filename: p.basename(normalizedPath),
    );

    try {
      // Bounded read from a single opened descriptor: a file that grows after
      // any size check (cursor-agent may still be writing it) can never pull
      // more than the inline budget + 1 byte into memory.
      final raf = File(normalizedPath).openSync();
      final Uint8List bytes;
      try {
        bytes = raf.readSync(maxInlineMessageAttachmentBytes + 1);
      } finally {
        raf.closeSync();
      }

      final mime = _mimeFromBytes(bytes: bytes);
      if (bytes.length > maxInlineMessageAttachmentBytes) {
        return [
          AcpContentMapper.metadataImageBlock(
            mime: mime ?? _mimeHintFromBasename(basename: basename),
            filename: basename,
            reason: AcpImageDegradationReason.oversized,
          ),
        ];
      }
      if (mime == null) {
        // No image signature (including an empty file): never promote arbitrary
        // bytes to an image on the strength of a filename extension — degrade
        // to metadata.
        return [
          AcpContentMapper.metadataImageBlock(
            mime: _mimeHintFromBasename(basename: basename),
            filename: basename,
            reason: AcpImageDegradationReason.invalid,
          ),
        ];
      }

      final base64 = base64Encode(bytes);
      // The transport bound applies to the encoded payload, not the raw bytes
      // (same policy as the standard ACP image path).
      if (!isInlineMessageAttachmentWithinSizeLimit(base64Length: base64.length)) {
        return [
          AcpContentMapper.metadataImageBlock(
            mime: mime,
            filename: basename,
            reason: AcpImageDegradationReason.oversized,
          ),
        ];
      }
      return [
        AcpMappedInlineImageContentBlock(
          attachment:
              PluginMessageAttachment.inlineImage(
                    mime: mime,
                    base64: base64,
                    filename: basename,
                  )
                  as PluginMessageAttachmentInlineImage,
          decodedBytes: bytes.length,
        ),
      ];
    } on Object catch (error, stack) {
      Log.w("[cursor] generate_image source unreadable: $normalizedPath", error, stack);
      return const [];
    }
  }

  static const String _unsupportedMime = "application/octet-stream";

  /// Extension-derived mime for degraded metadata blocks. Only the `.jpg`
  /// alias is local knowledge; the supported set itself is
  /// [AcpContentMapper.supportedRasterMimeEssences], so adding an inline-able
  /// type there extends this hint automatically.
  static String _mimeHintFromBasename({required String? basename}) {
    final extension = basename == null ? null : p.extension(basename).toLowerCase();
    if (extension == null || extension.length < 2) return _unsupportedMime;
    final essence = "image/${extension == ".jpg" ? "jpeg" : extension.substring(1)}";
    if (AcpContentMapper.supportedRasterMimeEssences.contains(essence)) return essence;
    return _unsupportedMime;
  }

  static String? _mimeFromBytes({required Uint8List bytes}) {
    if (_startsWith(bytes: bytes, signature: const [0x42, 0x4D])) return "image/bmp";
    if (_startsWith(bytes: bytes, signature: const [0x47, 0x49, 0x46, 0x38, 0x37, 0x61]) ||
        _startsWith(bytes: bytes, signature: const [0x47, 0x49, 0x46, 0x38, 0x39, 0x61])) {
      return "image/gif";
    }
    if (_startsWith(bytes: bytes, signature: const [0xFF, 0xD8, 0xFF])) return "image/jpeg";
    if (_startsWith(
      bytes: bytes,
      signature: const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    )) {
      return "image/png";
    }
    if (_startsWith(bytes: bytes, signature: const [0x52, 0x49, 0x46, 0x46]) &&
        bytes.length >= 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return "image/webp";
    }
    return null;
  }

  static bool _startsWith({required Uint8List bytes, required List<int> signature}) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }
}
