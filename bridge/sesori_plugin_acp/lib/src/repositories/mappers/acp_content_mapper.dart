import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart"
    show
        decodedBase64Length,
        isTranscriptImageBase64LengthWithinSizeLimit,
        maxTranscriptImageBytes,
        maxTranscriptImageCandidates;

import "../../api/models/acp_content_block_dto.dart";
import "../../api/models/acp_tool_content_dto.dart";

const int acpToolImageCandidateLimit = maxTranscriptImageCandidates;

sealed class const AcpMappedContentBlock();

final class const AcpMappedTextContentBlock({required final String text}) extends AcpMappedContentBlock;

sealed class const AcpMappedImageContentBlock() extends AcpMappedContentBlock;

final class const AcpMappedInlineImageContentBlock({
    required final PluginMessageAttachmentInlineImage attachment,
    required final int decodedBytes,
  }) extends AcpMappedImageContentBlock;

final class const AcpMappedMetadataImageContentBlock({
    required final PluginMessageAttachmentMetadata attachment,
    required final AcpImageDegradationReason reason,
  }) extends AcpMappedImageContentBlock;

final class const AcpMappedUnsupportedContentBlock() extends AcpMappedContentBlock;

final class const AcpMappedUnknownContentBlock() extends AcpMappedContentBlock;

enum AcpImageDegradationReason() {
  invalid,
  unsupported,
  oversized,
}

sealed class const AcpToolContentMutation();

final class const AcpReplaceToolContentMutation({
    required final String? output,
    required final List<AcpMappedImageContentBlock> imageCandidates,
    required final bool hasDiff,
  }) extends AcpToolContentMutation;

final class const AcpUpdateToolOutputMutation({required final String? output}) extends AcpToolContentMutation;

final class const AcpUnchangedToolContentMutation() extends AcpToolContentMutation;

/// Deduplicates privacy-safe mapping warnings across chunks of one logical
/// message while retaining no payload values.
final class AcpContentMappingScope() {
  final Set<_AcpContentWarning> _warned = {};
}

/// Maps standard ACP content blocks into backend-neutral, individually
/// validated content while retaining no URI or source-path data.
///
/// Message/tool ordering, count, and aggregate-byte state belong to their
/// respective trackers. This mapper owns only one candidate's typed decoding,
/// transport-safe normalization, and tool mutation selection.
final class const AcpContentMapper() {
  static const int _maxUriCharactersForFilename = 4096;
  static const int _maxMimeCharacters = 255;
  static const String _fallbackMime = "application/octet-stream";
  /// The closed set of raster mime essences the client renders inline. Public
  /// so harness-local image sources (e.g. Cursor's generated-image reader)
  /// share this one enumeration instead of drifting copies.
  static const Set<String> supportedRasterMimeEssences = {
    "image/bmp",
    "image/gif",
    "image/jpeg",
    "image/png",
    "image/webp",
  };
  static const Set<String> _supportedFilenameUriSchemes = {
    "file",
    "http",
    "https",
  };

  List<AcpMappedContentBlock> map({required Object? content}) {
    return mapScoped(content: content, scope: AcpContentMappingScope());
  }

  List<AcpMappedContentBlock> mapScoped({
    required Object? content,
    required AcpContentMappingScope scope,
  }) {
    return _mapValue(
      content: content,
      warned: scope._warned,
      toolImagePrefix: null,
    ).toList(growable: false);
  }

  String toolName({required Map<String, dynamic> update}) {
    final kind = update["kind"];
    if (kind is String && kind.isNotEmpty) return kind;
    final title = update["title"];
    if (title is String && title.isNotEmpty) return title;
    return "tool";
  }

  PluginToolStatus? toolStatus({required Object? status}) {
    return switch (status) {
      "pending" => PluginToolStatus.pending,
      "in_progress" => PluginToolStatus.running,
      "completed" => PluginToolStatus.completed,
      "failed" => PluginToolStatus.error,
      _ => null,
    };
  }

  AcpToolContentMutation toolContent({required Map<String, dynamic> update}) {
    if (!update.containsKey("content")) {
      if (!update.containsKey("rawOutput")) {
        return const AcpUnchangedToolContentMutation();
      }
      if (!_isValidRawOutput(raw: update["rawOutput"])) {
        return const AcpUnchangedToolContentMutation();
      }
      return AcpUpdateToolOutputMutation(
        output: _boundedToolOutput(
          text: _rawOutputText(raw: update["rawOutput"]),
        ),
      );
    }

    final content = update["content"];
    if (content is! String && content is! List && content is! Map) {
      _warnOnce(
        reason: _AcpContentWarning.malformed,
        warned: <_AcpContentWarning>{},
      );
      return const AcpUnchangedToolContentMutation();
    }
    final warned = <_AcpContentWarning>{};
    final buffer = StringBuffer();
    final imageCandidates = <AcpMappedImageContentBlock>[];
    final toolImagePrefix = _AcpToolImagePrefix();
    var hasDiff = false;
    for (final item in _mapToolValue(
      content: content,
      warned: warned,
      toolImagePrefix: toolImagePrefix,
    )) {
      switch (item) {
        case _AcpMappedToolBlock(:final block):
          switch (block) {
            case AcpMappedTextContentBlock(:final text):
              buffer.write(text);
            case AcpMappedImageContentBlock():
              imageCandidates.add(block);
            case AcpMappedUnsupportedContentBlock() || AcpMappedUnknownContentBlock():
              continue;
          }
        case _AcpMappedToolDiff():
          hasDiff = true;
      }
    }
    final contentText = buffer.toString();
    final text = contentText.isNotEmpty ? contentText : _rawOutputText(raw: update["rawOutput"]);
    return AcpReplaceToolContentMutation(
      output: _boundedToolOutput(text: text),
      imageCandidates: List.unmodifiable(imageCandidates),
      hasDiff: hasDiff,
    );
  }

  String? _boundedToolOutput({required String? text}) {
    if (text == null || text.isEmpty) return null;
    final prefix = text.runes.take(maxToolOutputLength + 1).toList(growable: false);
    if (prefix.length <= maxToolOutputLength) return text;
    return "${String.fromCharCodes(prefix.take(maxToolOutputLength))}…";
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
    required _AcpToolImagePrefix? toolImagePrefix,
  }) sync* {
    if (content == null) return;
    if (content is String) {
      yield AcpMappedTextContentBlock(text: content);
      return;
    }
    if (content is List) {
      for (final entry in content) {
        yield* _mapValue(
          content: entry,
          warned: warned,
          toolImagePrefix: toolImagePrefix,
        );
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
      final fallback = _legacyMapContent(
        content: content,
        warned: warned,
        toolImagePrefix: toolImagePrefix,
      );
      if (fallback.isEmpty) {
        yield const AcpMappedUnknownContentBlock();
      } else {
        yield* fallback;
      }
      return;
    }

    switch (dto) {
      case AcpTextContentBlockDto(:final text):
        yield AcpMappedTextContentBlock(text: text);
      case AcpImageContentBlockDto(:final data, :final mimeType, :final uri):
        if (toolImagePrefix != null && !toolImagePrefix.take()) {
          _warnOnce(
            reason: _AcpContentWarning.toolImageCountOverflow,
            warned: warned,
          );
          return;
        }
        yield _mapImage(data: data, mime: mimeType, uri: uri);
      case AcpUnsupportedAudioContentBlockDto() ||
          AcpUnsupportedResourceContentBlockDto() ||
          AcpUnsupportedResourceLinkContentBlockDto():
        yield const AcpMappedUnsupportedContentBlock();
      case AcpUnknownContentBlockDto():
        final fallback = _legacyMapContent(
          content: content,
          warned: warned,
          toolImagePrefix: toolImagePrefix,
        );
        if (fallback.isEmpty) {
          yield const AcpMappedUnknownContentBlock();
        } else {
          yield* fallback;
        }
    }
  }

  Iterable<_AcpMappedToolItem> _mapToolValue({
    required Object? content,
    required Set<_AcpContentWarning> warned,
    required _AcpToolImagePrefix toolImagePrefix,
  }) sync* {
    if (content == null) return;
    if (content is List) {
      for (final entry in content) {
        yield* _mapToolValue(
          content: entry,
          warned: warned,
          toolImagePrefix: toolImagePrefix,
        );
      }
      return;
    }
    if (content is! Map) {
      for (final block in _mapValue(
        content: content,
        warned: warned,
        toolImagePrefix: toolImagePrefix,
      )) {
        yield _AcpMappedToolBlock(block: block);
      }
      return;
    }

    final AcpToolContentDto dto;
    try {
      dto = AcpToolContentDto.fromJson(content.cast<String, dynamic>());
    } on Object {
      if (content["type"] == "diff") {
        yield const _AcpMappedToolDiff();
        return;
      }
      for (final block in _mapValue(
        content: content,
        warned: warned,
        toolImagePrefix: toolImagePrefix,
      )) {
        yield _AcpMappedToolBlock(block: block);
      }
      return;
    }

    switch (dto) {
      case AcpStandardToolContentDto():
        for (final block in _mapValue(
          content: content["content"],
          warned: warned,
          toolImagePrefix: toolImagePrefix,
        )) {
          yield _AcpMappedToolBlock(block: block);
        }
      case AcpDiffToolContentDto():
        yield const _AcpMappedToolDiff();
      case AcpTerminalToolContentDto():
        return;
      case AcpUnknownToolContentDto():
        for (final block in _mapValue(
          content: content,
          warned: warned,
          toolImagePrefix: toolImagePrefix,
        )) {
          yield _AcpMappedToolBlock(block: block);
        }
    }
  }

  String? _textFromMappedBlocks(Iterable<AcpMappedContentBlock> blocks) {
    final buffer = StringBuffer();
    for (final block in blocks) {
      if (block case AcpMappedTextContentBlock(:final text) when text.isNotEmpty) {
        buffer.write(text);
      }
    }
    final text = buffer.toString();
    return text.isEmpty ? null : text;
  }

  String? _rawOutputText({required Object? raw}) {
    if (raw is String) return raw.isEmpty ? null : raw;
    if (raw is! Map) return null;
    final outValue = raw["stdout"];
    final errorValue = raw["stderr"];
    final out = outValue is String ? outValue.trimRight() : "";
    final error = errorValue is String ? errorValue.trimRight() : "";
    if (out.isNotEmpty || error.isNotEmpty) {
      final buffer = StringBuffer(out);
      if (error.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.write("\n");
        buffer.write(error);
      }
      return buffer.toString();
    }
    final content = _textFromMappedBlocks(
      _mapValue(
        content: raw["content"],
        warned: <_AcpContentWarning>{},
        toolImagePrefix: null,
      ),
    )?.trimRight();
    if (content != null && content.isNotEmpty) return content;
    final exitCode = raw["exitCode"];
    if (exitCode is int && exitCode != 0) return "exited with code $exitCode";
    return null;
  }

  bool _isValidRawOutput({required Object? raw}) {
    if (raw is String) return true;
    if (raw is! Map) return false;
    if (raw.isEmpty) return true;
    if (raw["stdout"] is String || raw["stderr"] is String || raw["exitCode"] is int) return true;
    final content = raw["content"];
    return content is String || content is List || content is Map;
  }

  List<AcpMappedContentBlock> _legacyMapContent({
    required Map<dynamic, dynamic> content,
    required Set<_AcpContentWarning> warned,
    required _AcpToolImagePrefix? toolImagePrefix,
  }) {
    final text = content["text"];
    if (text is String && text.isNotEmpty) {
      return [AcpMappedTextContentBlock(text: text)];
    }
    final nested = content["content"];
    if (nested == null) return const [];
    return _mapValue(
      content: nested,
      warned: warned,
      toolImagePrefix: toolImagePrefix,
    ).toList(growable: false);
  }

  AcpMappedImageContentBlock _mapImage({
    required String data,
    required String mime,
    required String? uri,
  }) {
    final normalizedMime = _normalizeMime(raw: mime);
    final filename = _filenameFromUri(uri: uri);
    if (!supportedRasterMimeEssences.contains(_mimeEssence(mime: normalizedMime))) {
      return metadataImageBlock(
        mime: normalizedMime,
        filename: filename,
        reason: AcpImageDegradationReason.unsupported,
      );
    }
    if (data.isEmpty) {
      return metadataImageBlock(
        mime: normalizedMime,
        filename: filename,
        reason: AcpImageDegradationReason.invalid,
      );
    }
    if (!isTranscriptImageBase64LengthWithinSizeLimit(base64Length: data.length)) {
      return metadataImageBlock(
        mime: normalizedMime,
        filename: filename,
        reason: AcpImageDegradationReason.oversized,
      );
    }

    final normalized = normalizeAttachmentBase64(encoded: data);
    if (normalized == null) {
      return metadataImageBlock(
        mime: normalizedMime,
        filename: filename,
        reason: AcpImageDegradationReason.invalid,
      );
    }
    if (!isTranscriptImageBase64LengthWithinSizeLimit(base64Length: normalized.length)) {
      return metadataImageBlock(
        mime: normalizedMime,
        filename: filename,
        reason: AcpImageDegradationReason.oversized,
      );
    }

    final decodedBytes = decodedBase64Length(base64Data: normalized);
    if (decodedBytes > maxTranscriptImageBytes) {
      return metadataImageBlock(
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

  /// Builds the degraded metadata-only image block. Public and static for the
  /// same reason as [supportedRasterMimeEssences]: harness-local image sources
  /// must produce the identical shape without maintaining a copy.
  static AcpMappedMetadataImageContentBlock metadataImageBlock({
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

  String _normalizeMime({required String? raw}) => normalizeAttachmentMime(
    raw: raw,
    fallback: _fallbackMime,
    maxCharacters: _maxMimeCharacters,
  );

  String _mimeEssence({required String mime}) => attachmentMimeEssence(mime: mime);

  String? _filenameFromUri({required String? uri}) {
    if (uri == null || uri.isEmpty || uri.length > _maxUriCharactersForFilename) {
      return null;
    }
    final parsed = Uri.tryParse(uri);
    if (parsed == null ||
        !_supportedFilenameUriSchemes.contains(parsed.scheme) ||
        (!parsed.hasAuthority && !parsed.path.startsWith("/")) ||
        parsed.pathSegments.isEmpty) {
      return null;
    }
    final segments = parsed.pathSegments.where((segment) => segment.isNotEmpty);
    return segments.isEmpty ? null : normalizePluginMessageAttachmentFilename(filename: segments.last);
  }

  void _warnOnce({
    required _AcpContentWarning reason,
    required Set<_AcpContentWarning> warned,
  }) {
    if (!warned.add(reason)) return;
    Log.w(
      switch (reason) {
        _AcpContentWarning.malformed => "[acp] skipping malformed content block",
        _AcpContentWarning.toolImageCountOverflow =>
          "[acp] tool image attachment collection exceeds the count limit; dropping excess candidates",
      },
    );
  }
}

enum _AcpContentWarning() {
  malformed,
  toolImageCountOverflow,
}

final class _AcpToolImagePrefix() {
  int _candidateCount = 0;

  bool take() {
    if (_candidateCount >= acpToolImageCandidateLimit) return false;
    _candidateCount++;
    return true;
  }
}

sealed class const _AcpMappedToolItem();

final class const _AcpMappedToolBlock({required final AcpMappedContentBlock block}) extends _AcpMappedToolItem;

final class const _AcpMappedToolDiff() extends _AcpMappedToolItem;
