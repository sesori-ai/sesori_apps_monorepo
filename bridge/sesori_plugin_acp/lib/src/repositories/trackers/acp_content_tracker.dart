import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show maxInlineMessageAttachmentBytes;

import "../mappers/acp_content_mapper.dart";

sealed class const AcpContentMutation({required this.partIdSuffix}) {
  final String partIdSuffix;
}

final class const AcpTextDeltaMutation({
    required super.partIdSuffix,
    required this.delta,
  }) extends AcpContentMutation {
  final String delta;
}

final class const AcpImageMutation({
    required super.partIdSuffix,
    required this.attachment,
  }) extends AcpContentMutation {
  final PluginMessageAttachment attachment;
}

final class const AcpContentSnapshot({
    required this.textPartCount,
    required this.activeTextPartIdSuffix,
    required this.imageCandidateCount,
    required this.decodedImageBytes,
    required this.composition,
  }) {
  final int textPartCount;
  final String? activeTextPartIdSuffix;
  final int imageCandidateCount;
  final int decodedImageBytes;
  final AcpContentComposition composition;
}

enum AcpContentComposition() {
  empty,
  textOnly,
  mixed,
}

/// Owns ordered text/image segmentation and bounded image budgets for one
/// logical ACP assistant message.
final class AcpContentTracker() {
  static const int _maxImageCandidates = 4;

  final Set<_AcpContentWarning> _warned = {};
  final AcpContentMappingScope mappingScope = AcpContentMappingScope();
  int _textPartCount = 0;
  String? _activeTextPartIdSuffix;
  int _imageCandidateCount = 0;
  int _decodedImageBytes = 0;
  AcpContentComposition _composition = AcpContentComposition.empty;

  AcpContentSnapshot get snapshot => AcpContentSnapshot(
    textPartCount: _textPartCount,
    activeTextPartIdSuffix: _activeTextPartIdSuffix,
    imageCandidateCount: _imageCandidateCount,
    decodedImageBytes: _decodedImageBytes,
    composition: _composition,
  );

  List<AcpContentMutation> append({required Iterable<AcpMappedContentBlock> blocks}) {
    final mutations = <AcpContentMutation>[];
    for (final block in blocks) {
      switch (block) {
        case AcpMappedTextContentBlock(:final text):
          if (_composition == AcpContentComposition.empty) {
            _composition = AcpContentComposition.textOnly;
          }
          if (text.isEmpty) continue;
          final suffix = _activeTextPartIdSuffix ??= _nextTextPartIdSuffix();
          mutations.add(AcpTextDeltaMutation(partIdSuffix: suffix, delta: text));
        case AcpMappedInlineImageContentBlock(:final attachment, :final decodedBytes):
          _composition = AcpContentComposition.mixed;
          _activeTextPartIdSuffix = null;
          final imageIndex = ++_imageCandidateCount;
          if (imageIndex > _maxImageCandidates) {
            _warnOnce(reason: _AcpContentWarning.countOverflow);
            continue;
          }
          if (_decodedImageBytes + decodedBytes > maxInlineMessageAttachmentBytes) {
            _warnOnce(reason: _AcpContentWarning.aggregateOverflow);
            mutations.add(
              AcpImageMutation(
                partIdSuffix: "image-$imageIndex",
                attachment: PluginMessageAttachment.metadata(
                  mime: attachment.mime,
                  filename: attachment.filename,
                ),
              ),
            );
            continue;
          }
          _decodedImageBytes += decodedBytes;
          mutations.add(
            AcpImageMutation(
              partIdSuffix: "image-$imageIndex",
              attachment: attachment,
            ),
          );
        case AcpMappedMetadataImageContentBlock(:final attachment, :final reason):
          _composition = AcpContentComposition.mixed;
          _activeTextPartIdSuffix = null;
          final imageIndex = ++_imageCandidateCount;
          if (imageIndex > _maxImageCandidates) {
            _warnOnce(reason: _AcpContentWarning.countOverflow);
            continue;
          }
          _warnOnce(reason: _warningFor(reason: reason));
          mutations.add(
            AcpImageMutation(
              partIdSuffix: "image-$imageIndex",
              attachment: attachment,
            ),
          );
        case AcpMappedUnsupportedContentBlock() || AcpMappedUnknownContentBlock():
          _composition = AcpContentComposition.mixed;
          continue;
      }
    }
    return mutations;
  }

  void closeTextPart() {
    _activeTextPartIdSuffix = null;
  }

  String _nextTextPartIdSuffix() {
    final index = _textPartCount++;
    return index == 0 ? "text" : "text-$index";
  }

  _AcpContentWarning _warningFor({required AcpImageDegradationReason reason}) {
    return switch (reason) {
      AcpImageDegradationReason.invalid => _AcpContentWarning.invalid,
      AcpImageDegradationReason.unsupported => _AcpContentWarning.unsupported,
      AcpImageDegradationReason.oversized => _AcpContentWarning.oversized,
    };
  }

  void _warnOnce({required _AcpContentWarning reason}) {
    if (!_warned.add(reason)) return;
    Log.w(
      switch (reason) {
        _AcpContentWarning.invalid => "[acp] invalid image attachment; forwarding metadata only",
        _AcpContentWarning.unsupported => "[acp] unsupported image attachment; forwarding metadata only",
        _AcpContentWarning.oversized => "[acp] oversized image attachment; forwarding metadata only",
        _AcpContentWarning.aggregateOverflow =>
          "[acp] image attachments exceed the aggregate transport limit; forwarding metadata only",
        _AcpContentWarning.countOverflow =>
          "[acp] image attachment collection exceeds the count limit; dropping excess candidates",
      },
    );
  }
}

enum _AcpContentWarning() {
  invalid,
  unsupported,
  oversized,
  aggregateOverflow,
  countOverflow,
}
