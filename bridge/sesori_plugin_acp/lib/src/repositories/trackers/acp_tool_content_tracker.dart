import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show maxInlineMessageAttachmentBytes;

import "../mappers/acp_content_mapper.dart";

final class AcpToolContentSnapshot {
  const AcpToolContentSnapshot({
    required this.output,
    required this.attachments,
    required this.imageCandidateCount,
    required this.decodedImageBytes,
  });

  final String? output;
  final List<PluginMessageAttachment> attachments;
  final int imageCandidateCount;
  final int decodedImageBytes;
}

/// Owns the normalized output and bounded attachment collection for one ACP
/// tool call. Callers apply only mapper-produced mutations, so live and replay
/// share collection replacement and partial-update semantics.
final class AcpToolContentTracker {
  static const int _maxImageCandidates = 4;

  String? _output;
  List<PluginMessageAttachment> _attachments = const [];
  int _imageCandidateCount = 0;
  int _decodedImageBytes = 0;

  AcpToolContentSnapshot get snapshot => AcpToolContentSnapshot(
    output: _output,
    attachments: _attachments,
    imageCandidateCount: _imageCandidateCount,
    decodedImageBytes: _decodedImageBytes,
  );

  void apply({required AcpToolContentMutation mutation}) {
    switch (mutation) {
      case AcpReplaceToolContentMutation(
        :final output,
        :final imageCandidates,
      ):
        _output = output;
        _replaceAttachments(candidates: imageCandidates);
      case AcpUpdateToolOutputMutation(:final output):
        _output = output;
      case AcpUnchangedToolContentMutation():
        return;
    }
  }

  void _replaceAttachments({
    required List<AcpMappedImageContentBlock> candidates,
  }) {
    final attachments = <PluginMessageAttachment>[];
    final warned = <_AcpToolContentWarning>{};
    var decodedImageBytes = 0;
    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates[index];
      if (index >= _maxImageCandidates) {
        _warnOnce(
          reason: _AcpToolContentWarning.countOverflow,
          warned: warned,
        );
        continue;
      }
      switch (candidate) {
        case AcpMappedInlineImageContentBlock(
          :final attachment,
          :final decodedBytes,
        ):
          if (decodedImageBytes + decodedBytes > maxInlineMessageAttachmentBytes) {
            _warnOnce(
              reason: _AcpToolContentWarning.aggregateOverflow,
              warned: warned,
            );
            attachments.add(
              PluginMessageAttachment.metadata(
                mime: attachment.mime,
                filename: attachment.filename,
              ),
            );
            continue;
          }
          decodedImageBytes += decodedBytes;
          attachments.add(attachment);
        case AcpMappedMetadataImageContentBlock(
          :final attachment,
          :final reason,
        ):
          _warnOnce(
            reason: _warningFor(reason: reason),
            warned: warned,
          );
          attachments.add(attachment);
      }
    }
    _attachments = List.unmodifiable(attachments);
    _imageCandidateCount = candidates.length;
    _decodedImageBytes = decodedImageBytes;
  }

  _AcpToolContentWarning _warningFor({
    required AcpImageDegradationReason reason,
  }) {
    return switch (reason) {
      AcpImageDegradationReason.invalid => _AcpToolContentWarning.invalid,
      AcpImageDegradationReason.unsupported => _AcpToolContentWarning.unsupported,
      AcpImageDegradationReason.oversized => _AcpToolContentWarning.oversized,
    };
  }

  void _warnOnce({
    required _AcpToolContentWarning reason,
    required Set<_AcpToolContentWarning> warned,
  }) {
    if (!warned.add(reason)) return;
    Log.w(
      switch (reason) {
        _AcpToolContentWarning.invalid => "[acp] invalid tool image attachment; forwarding metadata only",
        _AcpToolContentWarning.unsupported => "[acp] unsupported tool image attachment; forwarding metadata only",
        _AcpToolContentWarning.oversized => "[acp] oversized tool image attachment; forwarding metadata only",
        _AcpToolContentWarning.aggregateOverflow =>
          "[acp] tool image attachments exceed the aggregate transport limit; forwarding metadata only",
        _AcpToolContentWarning.countOverflow =>
          "[acp] tool image attachment collection exceeds the count limit; dropping excess candidates",
      },
    );
  }
}

enum _AcpToolContentWarning {
  invalid,
  unsupported,
  oversized,
  aggregateOverflow,
  countOverflow,
}
