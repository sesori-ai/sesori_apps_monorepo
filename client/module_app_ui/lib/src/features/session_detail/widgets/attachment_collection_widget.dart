import "dart:math" as math;

import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "file_part_widget.dart";

class const AttachmentCollectionWidget({
  super.key,
  required final String sessionId,
  required final List<MessageAttachment> attachments,
}) extends StatelessWidget {
  static const surfaceKey = ValueKey("attachmentCollection.surface");

  @override
  Widget build(BuildContext context) {
    final visibleAttachments = attachments.where((attachment) => attachment is! MessageAttachmentUnknown).toList();
    if (visibleAttachments.isEmpty) return const SizedBox.shrink();
    final prego = context.prego;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = math.min(constraints.maxWidth, FilePartWidget.previewSize);
        final runWidth = visibleAttachments.length * tileWidth + (visibleAttachments.length - 1) * prego.spacing.sm;
        final duplicateCounts = <String, int>{};

        return Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: SizedBox(
            key: surfaceKey,
            width: math.min(constraints.maxWidth, runWidth),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: prego.spacing.xs),
              child: Wrap(
                spacing: prego.spacing.sm,
                runSpacing: prego.spacing.sm,
                children: [
                  for (final attachment in visibleAttachments)
                    SizedBox(
                      width: tileWidth,
                      child: _tile(
                        attachment: attachment,
                        duplicateCounts: duplicateCounts,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _tile({required MessageAttachment attachment, required Map<String, int> duplicateCounts}) {
    final identity = _identity(attachment: attachment);
    final duplicate = duplicateCounts.update(identity, (count) => count + 1, ifAbsent: () => 0);
    return FilePartWidget(
      key: ValueKey((identity, duplicate)),
      sessionId: sessionId,
      attachment: attachment,
    );
  }

  String _identity({required MessageAttachment attachment}) => switch (attachment) {
    MessageAttachmentStoredImage(:final attachmentId, :final bridgeId) => "stored:$bridgeId:$attachmentId",
    MessageAttachmentRemoteUrl(:final url) => "remote:$url",
    MessageAttachmentInlineImage(:final mime, :final filename) => "inline:$mime:$filename",
    MessageAttachmentMetadata(:final mime, :final filename) => "metadata:$mime:$filename",
    MessageAttachmentUnknown() => throw StateError("Unknown attachments are filtered before layout"),
  };
}
