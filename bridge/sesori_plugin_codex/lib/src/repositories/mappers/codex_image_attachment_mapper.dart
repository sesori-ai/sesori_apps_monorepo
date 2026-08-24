import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart"
    show
        decodedBase64Length,
        isTranscriptImageBase64LengthWithinSizeLimit,
        maxTranscriptImageBytes,
        maxTranscriptImageCandidates,
        maxTranscriptImageCollectionBytes;

sealed class const CodexImageAttachmentCandidate() {
  const factory base64({
    required String data,
    required String mime,
    required String? filenameHint,
  }) = CodexBase64ImageAttachmentCandidate;

  const factory imageUrl({
    required String imageUrl,
  }) = CodexImageUrlAttachmentCandidate;
}

final class const CodexBase64ImageAttachmentCandidate({
    required final String data,
    required final String mime,
    required final String? filenameHint,
  }) extends CodexImageAttachmentCandidate;

final class const CodexImageUrlAttachmentCandidate({required final String imageUrl}) extends CodexImageAttachmentCandidate;

final class const CodexImageAttachmentMapper() {
  static const int _maxDataUrlHeaderCharacters = 256;
  static const int _maxUrlCharactersForFilename = 4096;
  static const int _maxMimeCharacters = 255;
  static const String _fallbackMime = "application/octet-stream";
  static const Set<String> _supportedRasterMimeEssences = {
    "image/bmp",
    "image/gif",
    "image/jpeg",
    "image/png",
    "image/webp",
  };

  List<PluginMessageAttachment> map({
    required Iterable<CodexImageAttachmentCandidate> candidates,
  }) {
    final attachments = <PluginMessageAttachment>[];
    final warned = <_ImageDegradationReason>{};
    var remainingBytes = maxTranscriptImageCollectionBytes;
    var candidateIndex = 0;

    for (final candidate in candidates) {
      if (candidateIndex >= maxTranscriptImageCandidates) {
        _warnOnce(
          reason: _ImageDegradationReason.countOverflow,
          warned: warned,
        );
        candidateIndex += 1;
        continue;
      }
      candidateIndex += 1;

      final result = _mapCandidate(
        candidate: candidate,
        remainingBytes: remainingBytes,
      );
      switch (result) {
        case _InlineImageResult(:final attachment, :final decodedBytes):
          attachments.add(attachment);
          remainingBytes -= decodedBytes;
        case _MetadataImageResult(:final attachment, :final reason):
          attachments.add(attachment);
          _warnOnce(reason: reason, warned: warned);
      }
    }
    return attachments.toList(growable: false);
  }

  List<PluginMessageAttachment> boundMappedAttachments({
    required Iterable<PluginMessageAttachment> attachments,
  }) {
    final bounded = <PluginMessageAttachment>[];
    final warned = <_ImageDegradationReason>{};
    var remainingBytes = maxTranscriptImageCollectionBytes;

    for (final attachment in attachments) {
      if (bounded.contains(attachment)) continue;
      if (bounded.length >= maxTranscriptImageCandidates) {
        _warnOnce(
          reason: _ImageDegradationReason.countOverflow,
          warned: warned,
        );
        continue;
      }

      final PluginMessageAttachment mapped;
      switch (attachment) {
        case PluginMessageAttachmentInlineImage(
          :final mime,
          :final base64,
          :final filename,
        ):
          final decodedBytes = decodedBase64Length(base64Data: base64);
          if (decodedBytes > maxTranscriptImageBytes) {
            mapped = PluginMessageAttachment.metadata(
              mime: mime,
              filename: filename,
            );
            _warnOnce(
              reason: _ImageDegradationReason.oversized,
              warned: warned,
            );
          } else if (decodedBytes > remainingBytes) {
            mapped = PluginMessageAttachment.metadata(
              mime: mime,
              filename: filename,
            );
            _warnOnce(
              reason: _ImageDegradationReason.aggregateOverflow,
              warned: warned,
            );
          } else {
            mapped = attachment;
            remainingBytes -= decodedBytes;
          }
        case PluginMessageAttachmentRemoteUrl() || PluginMessageAttachmentMetadata():
          mapped = attachment;
      }
      if (!bounded.contains(mapped)) bounded.add(mapped);
    }
    return List.unmodifiable(bounded);
  }

  _ImageMappingResult _mapCandidate({
    required CodexImageAttachmentCandidate candidate,
    required int remainingBytes,
  }) {
    return switch (candidate) {
      CodexBase64ImageAttachmentCandidate(:final data, :final mime, :final filenameHint) => _mapEncoded(
        encoded: data,
        mime: mime,
        filename: normalizePluginMessageAttachmentFilename(filename: filenameHint),
        remainingBytes: remainingBytes,
      ),
      CodexImageUrlAttachmentCandidate(:final imageUrl) => _mapImageUrl(
        imageUrl: imageUrl,
        remainingBytes: remainingBytes,
      ),
    };
  }

  _ImageMappingResult _mapImageUrl({
    required String imageUrl,
    required int remainingBytes,
  }) {
    if (!_isDataUrl(url: imageUrl)) {
      return _metadata(
        mime: _fallbackMime,
        filename: _filenameFromUrl(url: imageUrl),
        reason: _ImageDegradationReason.unsupported,
      );
    }

    final prefixLength = imageUrl.length < 5 + _maxDataUrlHeaderCharacters + 1
        ? imageUrl.length
        : 5 + _maxDataUrlHeaderCharacters + 1;
    final separator = imageUrl.substring(0, prefixLength).indexOf(",", 5);
    if (separator < 5) {
      return _metadata(
        mime: _fallbackMime,
        filename: null,
        reason: _ImageDegradationReason.invalid,
      );
    }

    final headerParts = imageUrl.substring(5, separator).split(";");
    final mime = _normalizeMime(raw: headerParts.first);
    final isBase64 = headerParts.skip(1).any((part) => part.trim().toLowerCase() == "base64");
    if (!isBase64) {
      return _metadata(
        mime: mime,
        filename: null,
        reason: _ImageDegradationReason.invalid,
      );
    }
    if (!_supportedRasterMimeEssences.contains(_mimeEssence(mime: mime))) {
      return _metadata(
        mime: mime,
        filename: null,
        reason: _ImageDegradationReason.unsupported,
      );
    }
    final encodedLength = imageUrl.length - separator - 1;
    if (encodedLength == 0) {
      return _metadata(
        mime: mime,
        filename: null,
        reason: _ImageDegradationReason.invalid,
      );
    }
    if (!isTranscriptImageBase64LengthWithinSizeLimit(base64Length: encodedLength)) {
      return _metadata(
        mime: mime,
        filename: null,
        reason: _ImageDegradationReason.oversized,
      );
    }
    return _mapEncoded(
      encoded: imageUrl.substring(separator + 1),
      mime: mime,
      filename: null,
      remainingBytes: remainingBytes,
    );
  }

  _ImageMappingResult _mapEncoded({
    required String encoded,
    required String mime,
    required String? filename,
    required int remainingBytes,
  }) {
    final normalizedMime = _normalizeMime(raw: mime);
    if (!_supportedRasterMimeEssences.contains(_mimeEssence(mime: normalizedMime))) {
      return _metadata(
        mime: normalizedMime,
        filename: filename,
        reason: _ImageDegradationReason.unsupported,
      );
    }
    if (encoded.isEmpty) {
      return _metadata(
        mime: normalizedMime,
        filename: filename,
        reason: _ImageDegradationReason.invalid,
      );
    }
    if (!isTranscriptImageBase64LengthWithinSizeLimit(base64Length: encoded.length)) {
      return _metadata(
        mime: normalizedMime,
        filename: filename,
        reason: _ImageDegradationReason.oversized,
      );
    }

    final normalized = normalizeAttachmentBase64(encoded: encoded);
    if (normalized == null) {
      return _metadata(
        mime: normalizedMime,
        filename: filename,
        reason: _ImageDegradationReason.invalid,
      );
    }
    if (!isTranscriptImageBase64LengthWithinSizeLimit(base64Length: normalized.length)) {
      return _metadata(
        mime: normalizedMime,
        filename: filename,
        reason: _ImageDegradationReason.oversized,
      );
    }

    final decodedBytes = decodedBase64Length(base64Data: normalized);
    if (decodedBytes > maxTranscriptImageBytes) {
      return _metadata(
        mime: normalizedMime,
        filename: filename,
        reason: _ImageDegradationReason.oversized,
      );
    }
    if (decodedBytes > remainingBytes) {
      return _metadata(
        mime: normalizedMime,
        filename: filename,
        reason: _ImageDegradationReason.aggregateOverflow,
      );
    }
    return _InlineImageResult(
      attachment: PluginMessageAttachment.inlineImage(
        mime: normalizedMime,
        base64: normalized,
        filename: filename,
      ),
      decodedBytes: decodedBytes,
    );
  }

  _MetadataImageResult _metadata({
    required String mime,
    required String? filename,
    required _ImageDegradationReason reason,
  }) {
    return _MetadataImageResult(
      attachment: PluginMessageAttachment.metadata(
        mime: _normalizeMime(raw: mime),
        filename: filename,
      ),
      reason: reason,
    );
  }

  String _normalizeMime({required String? raw}) => normalizeAttachmentMime(
    raw: raw,
    fallback: _fallbackMime,
    maxCharacters: _maxMimeCharacters,
  );

  String _mimeEssence({required String mime}) => attachmentMimeEssence(mime: mime);

  bool _isDataUrl({required String url}) => url.length >= 5 && url.substring(0, 5).toLowerCase() == "data:";

  String? _filenameFromUrl({required String url}) {
    if (url.length > _maxUrlCharactersForFilename) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) return null;
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    return segments.isEmpty ? null : normalizePluginMessageAttachmentFilename(filename: segments.last);
  }

  void _warnOnce({
    required _ImageDegradationReason reason,
    required Set<_ImageDegradationReason> warned,
  }) {
    if (!warned.add(reason)) return;
    Log.w(
      switch (reason) {
        _ImageDegradationReason.invalid => "[codex] invalid image attachment; forwarding metadata only",
        _ImageDegradationReason.unsupported => "[codex] unsupported image attachment; forwarding metadata only",
        _ImageDegradationReason.oversized =>
          "[codex] image attachment exceeds the retention limit; forwarding metadata only",
        _ImageDegradationReason.aggregateOverflow =>
          "[codex] image attachments exceed the aggregate retention limit; forwarding metadata only",
        _ImageDegradationReason.countOverflow =>
          "[codex] image attachment collection exceeds the count limit; dropping excess candidates",
      },
    );
  }
}

enum _ImageDegradationReason() {
  invalid,
  unsupported,
  oversized,
  aggregateOverflow,
  countOverflow,
}

sealed class const _ImageMappingResult();

final class const _InlineImageResult({
    required final PluginMessageAttachment attachment,
    required final int decodedBytes,
  }) extends _ImageMappingResult;

final class const _MetadataImageResult({
    required final PluginMessageAttachment attachment,
    required final _ImageDegradationReason reason,
  }) extends _ImageMappingResult;
