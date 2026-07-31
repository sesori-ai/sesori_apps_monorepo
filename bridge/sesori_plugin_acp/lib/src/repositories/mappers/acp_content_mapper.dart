import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart"
    show decodedBase64Length, isInlineMessageAttachmentWithinSizeLimit, maxInlineMessageAttachmentBytes;

import "../../api/models/acp_content_block_dto.dart";

sealed class AcpMappedContentBlock {
  const AcpMappedContentBlock();
}

final class AcpMappedTextContentBlock extends AcpMappedContentBlock {
  const AcpMappedTextContentBlock({required this.text});

  final String text;
}

sealed class AcpMappedImageContentBlock extends AcpMappedContentBlock {
  const AcpMappedImageContentBlock();
}

final class AcpMappedInlineImageContentBlock extends AcpMappedImageContentBlock {
  const AcpMappedInlineImageContentBlock({
    required this.attachment,
    required this.decodedBytes,
  });

  final PluginMessageAttachmentInlineImage attachment;
  final int decodedBytes;
}

final class AcpMappedMetadataImageContentBlock extends AcpMappedImageContentBlock {
  const AcpMappedMetadataImageContentBlock({
    required this.attachment,
    required this.reason,
  });

  final PluginMessageAttachmentMetadata attachment;
  final AcpImageDegradationReason reason;
}

final class AcpMappedUnsupportedContentBlock extends AcpMappedContentBlock {
  const AcpMappedUnsupportedContentBlock();
}

final class AcpMappedUnknownContentBlock extends AcpMappedContentBlock {
  const AcpMappedUnknownContentBlock();
}

enum AcpImageDegradationReason {
  invalid,
  unsupported,
  oversized,
}

/// Maps standard ACP content blocks into backend-neutral, individually
/// validated content while retaining no URI or source-path data.
///
/// Message-level ordering, count, and aggregate-byte state belong to the
/// per-message tracker introduced with image materialization. This mapper owns
/// only one candidate's typed decoding and transport-safe normalization.
final class AcpContentMapper {
  const AcpContentMapper();

  static const int _maxUriCharactersForFilename = 4096;
  static const int _maxMimeCharacters = 255;
  static const String _fallbackMime = "application/octet-stream";
  static const Set<String> _supportedRasterMimeEssences = {
    "image/bmp",
    "image/gif",
    "image/jpeg",
    "image/png",
    "image/webp",
  };

  List<AcpMappedContentBlock> map({required Object? content}) {
    final warned = <_AcpContentWarning>{};
    return _mapValue(content: content, warned: warned).toList(growable: false);
  }

  String? text({required Object? content}) {
    final buffer = StringBuffer();
    for (final block in map(content: content)) {
      if (block case AcpMappedTextContentBlock(:final text) when text.isNotEmpty) {
        buffer.write(text);
      }
    }
    final result = buffer.toString();
    return result.isEmpty ? null : result;
  }

  Iterable<AcpMappedContentBlock> _mapValue({
    required Object? content,
    required Set<_AcpContentWarning> warned,
  }) sync* {
    if (content == null) return;
    if (content is String) {
      yield AcpMappedTextContentBlock(text: content);
      return;
    }
    if (content is List) {
      for (final entry in content) {
        yield* _mapValue(content: entry, warned: warned);
      }
      return;
    }
    if (content is! Map) {
      _warnOnce(reason: _AcpContentWarning.malformed, warned: warned);
      yield const AcpMappedUnknownContentBlock();
      return;
    }

    final AcpContentBlockDto dto;
    try {
      dto = AcpContentBlockDto.fromJson(content.cast<String, dynamic>());
    } on Object {
      _warnOnce(reason: _AcpContentWarning.malformed, warned: warned);
      yield const AcpMappedUnknownContentBlock();
      return;
    }

    switch (dto) {
      case AcpTextContentBlockDto(:final text):
        yield AcpMappedTextContentBlock(text: text);
      case AcpImageContentBlockDto(:final data, :final mimeType, :final uri):
        yield _mapImage(data: data, mime: mimeType, uri: uri);
      case AcpUnsupportedAudioContentBlockDto() ||
          AcpUnsupportedResourceContentBlockDto() ||
          AcpUnsupportedResourceLinkContentBlockDto():
        yield const AcpMappedUnsupportedContentBlock();
      case AcpUnknownContentBlockDto():
        yield const AcpMappedUnknownContentBlock();
    }
  }

  AcpMappedImageContentBlock _mapImage({
    required String data,
    required String mime,
    required String? uri,
  }) {
    final normalizedMime = _normalizeMime(raw: mime);
    final filename = _filenameFromUri(uri: uri);
    if (!_supportedRasterMimeEssences.contains(_mimeEssence(mime: normalizedMime))) {
      return _metadata(
        mime: normalizedMime,
        filename: filename,
        reason: AcpImageDegradationReason.unsupported,
      );
    }
    if (data.isEmpty) {
      return _metadata(
        mime: normalizedMime,
        filename: filename,
        reason: AcpImageDegradationReason.invalid,
      );
    }
    if (!isInlineMessageAttachmentWithinSizeLimit(base64Length: data.length)) {
      return _metadata(
        mime: normalizedMime,
        filename: filename,
        reason: AcpImageDegradationReason.oversized,
      );
    }

    final normalized = _tryNormalizeBase64(encoded: data);
    if (normalized == null) {
      return _metadata(
        mime: normalizedMime,
        filename: filename,
        reason: AcpImageDegradationReason.invalid,
      );
    }
    if (!isInlineMessageAttachmentWithinSizeLimit(base64Length: normalized.length)) {
      return _metadata(
        mime: normalizedMime,
        filename: filename,
        reason: AcpImageDegradationReason.oversized,
      );
    }

    final decodedBytes = decodedBase64Length(base64Data: normalized);
    if (decodedBytes > maxInlineMessageAttachmentBytes) {
      return _metadata(
        mime: normalizedMime,
        filename: filename,
        reason: AcpImageDegradationReason.oversized,
      );
    }
    return AcpMappedInlineImageContentBlock(
      attachment:
          PluginMessageAttachment.inlineImage(
                mime: normalizedMime,
                base64: normalized,
                filename: filename,
              )
              as PluginMessageAttachmentInlineImage,
      decodedBytes: decodedBytes,
    );
  }

  AcpMappedMetadataImageContentBlock _metadata({
    required String mime,
    required String? filename,
    required AcpImageDegradationReason reason,
  }) {
    return AcpMappedMetadataImageContentBlock(
      attachment:
          PluginMessageAttachment.metadata(
                mime: mime,
                filename: filename,
              )
              as PluginMessageAttachmentMetadata,
      reason: reason,
    );
  }

  String? _tryNormalizeBase64({required String encoded}) {
    try {
      return base64.normalize(encoded);
    } on FormatException {
      return null;
    }
  }

  String _normalizeMime({required String? raw}) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return _fallbackMime;
    return String.fromCharCodes(trimmed.runes.take(_maxMimeCharacters)).toLowerCase();
  }

  String _mimeEssence({required String mime}) => mime.split(";").first.trim();

  String? _filenameFromUri({required String? uri}) {
    if (uri == null || uri.isEmpty || uri.length > _maxUriCharactersForFilename) {
      return null;
    }
    final parsed = Uri.tryParse(uri);
    if (parsed == null || parsed.pathSegments.isEmpty) return null;
    final segments = parsed.pathSegments.where((segment) => segment.isNotEmpty);
    return segments.isEmpty ? null : normalizePluginMessageAttachmentFilename(filename: segments.last);
  }

  void _warnOnce({
    required _AcpContentWarning reason,
    required Set<_AcpContentWarning> warned,
  }) {
    if (!warned.add(reason)) return;
    Log.w("[acp] skipping malformed content block");
  }
}

enum _AcpContentWarning {
  malformed,
}
