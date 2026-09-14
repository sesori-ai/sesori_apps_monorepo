import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

import "user_message_card.dart";

class const SendingMessageBubble({
  super.key,
  required final String? displayText,
  required final int attachmentCount,

  /// Image bytes remain local while a submission is sending or awaiting bridge acceptance.
  required final List<ComposerAttachment> localAttachments,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    return Column(
      crossAxisAlignment: .end,
      mainAxisSize: MainAxisSize.min,
      children: [
        UserMessageBubble(
          markdown: displayText,
          outlined: false,
          transitionDuration: Duration.zero,
          attachments: [
            if (localAttachments.isNotEmpty) _SendingAttachmentPreviews(attachments: localAttachments),
            if (attachmentCount > 0 && (localAttachments.isEmpty || displayText == null))
              _SendingAttachmentCount(count: attachmentCount),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            end: PregoSpacing.x2l,
            bottom: PregoSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ExcludeSemantics(child: SizedBox.square(dimension: 14, child: PregoActivityIndicator(color: null))),
              const SizedBox(width: PregoSpacing.xs),
              Text(
                loc.sessionDetailSendingMessage,
                style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class const _SendingAttachmentPreviews({required final List<ComposerAttachment> attachments}) extends StatelessWidget {
  static const double _thumbnailSize = 64;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.sm),
      child: Wrap(
        spacing: PregoSpacing.sm,
        runSpacing: PregoSpacing.sm,
        children: [
          for (final attachment in attachments)
            Semantics(
              image: true,
              label: attachment.filename ?? context.loc.sessionDetailAttachedImage,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(prego.radius.lg),
                child: Image.memory(
                  attachment.bytes,
                  width: _thumbnailSize,
                  height: _thumbnailSize,
                  cacheWidth: (_thumbnailSize * MediaQuery.devicePixelRatioOf(context)).round(),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: prego.colors.bgSurface2,
                    child: Icon(Icons.broken_image, color: prego.colors.textSecondary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class const _SendingAttachmentCount({required final int count}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(TablerRegular.photo, size: 16, color: prego.colors.textBrandPrimary),
          const SizedBox(width: PregoSpacing.xs),
          Text(
            context.loc.sessionDetailQueuedAttachmentCount(count),
            style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textBrandPrimary),
          ),
        ],
      ),
    );
  }
}
