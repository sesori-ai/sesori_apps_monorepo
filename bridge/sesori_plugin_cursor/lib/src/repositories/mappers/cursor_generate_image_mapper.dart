import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:acp_plugin/acp_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show maxInlineMessageAttachmentBytes;

/// Reads Cursor `cursor/generate_image` host paths and maps them into the same
/// bounded inline-image content blocks used for standard ACP assistant images.
///
/// Local paths never leave this mapper; only basename metadata and inline bytes
/// cross the plugin boundary.
final class CursorGenerateImageMapper {
  const CursorGenerateImageMapper({required AcpContentMapper contentMapper}) : _contentMapper = contentMapper;

  final AcpContentMapper _contentMapper;

  List<AcpMappedContentBlock> mapPath({required String path}) {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty) {
      _logUnavailable();
      return const [];
    }

    final basename = normalizePluginMessageAttachmentFilename(
      filename: p.basename(normalizedPath),
    );
    final uri = basename == null ? null : "file:///$basename";

    try {
      final file = File(normalizedPath);
      if (!file.existsSync()) {
        _logUnavailable();
        return const [];
      }
      final length = file.lengthSync();
      if (length <= 0) {
        _logUnavailable();
        return const [];
      }
      if (length > maxInlineMessageAttachmentBytes) {
        return [
          AcpMappedMetadataImageContentBlock(
            attachment:
                PluginMessageAttachment.metadata(
                      mime: _mimeHintFromBasename(basename: basename),
                      filename: basename,
                    )
                    as PluginMessageAttachmentMetadata,
            reason: AcpImageDegradationReason.oversized,
          ),
        ];
      }

      final bytes = file.readAsBytesSync();
      final mime = _mimeFromBytes(bytes: bytes) ?? _mimeHintFromBasename(basename: basename);
      final content = <String, Object?>{
        "type": "image",
        "data": base64Encode(bytes),
        "mimeType": mime,
      };
      if (uri != null) content["uri"] = uri;
      return _contentMapper.map(content: content);
    } on Object {
      _logUnavailable();
      return const [];
    }
  }

  void _logUnavailable() {
    Log.w("[cursor] generate_image source unavailable");
  }

  static String _mimeHintFromBasename({required String? basename}) {
    final extension = basename == null ? null : p.extension(basename).toLowerCase();
    return switch (extension) {
      ".bmp" => "image/bmp",
      ".gif" => "image/gif",
      ".jpg" || ".jpeg" => "image/jpeg",
      ".png" => "image/png",
      ".webp" => "image/webp",
      _ => "application/octet-stream",
    };
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
