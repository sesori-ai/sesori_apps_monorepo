import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "user_message_card.dart";

sealed class const QueuedMessageBubblePresentation() {
  const factory sending() = SendingMessageBubblePresentation;
  const factory pending({required VoidCallback onCancel}) = PendingMessageBubblePresentation;
  const factory pendingReadOnly() = ReadOnlyPendingMessageBubblePresentation;
}

final class const SendingMessageBubblePresentation() extends QueuedMessageBubblePresentation;

final class const PendingMessageBubblePresentation({required final VoidCallback onCancel})
    extends QueuedMessageBubblePresentation;

final class const ReadOnlyPendingMessageBubblePresentation() extends QueuedMessageBubblePresentation;

class const QueuedMessageBubble({
  super.key,
  required final String? displayText,
  required final bool isCommand,
  required final int attachmentCount,

  /// Image bytes remain local while a submission is sending or awaiting the
  /// bridge queue. Once another surface owns the queue, only its bounded count
  /// is available and the bubble renders an attachment indicator instead.
  required final List<ComposerAttachment> localAttachments,
  required final QueuedMessageBubblePresentation presentation,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final reducedMotion = context.isReducedMotion;
    final duration = reducedMotion ? Duration.zero : const Duration(milliseconds: 240);
    final isPending =
        presentation is PendingMessageBubblePresentation || presentation is ReadOnlyPendingMessageBubblePresentation;
    final status = switch (presentation) {
      SendingMessageBubblePresentation() => _status(
        prego: prego,
        icon: const ExcludeSemantics(
          child: SizedBox.square(
            dimension: 14,
            child: PregoActivityIndicator(color: null),
          ),
        ),
        label: loc.sessionDetailSendingMessage,
      ),
      PendingMessageBubblePresentation(:final onCancel) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _status(
            prego: prego,
            icon: Icon(
              isCommand ? TablerRegular.terminal : TablerRegular.clock,
              size: 14,
              color: prego.colors.textTertiary,
            ),
            label: isCommand ? loc.sessionDetailQueuedCommand : loc.sessionDetailQueuedMessage,
          ),
          const SizedBox(width: PregoSpacing.xs),
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(TablerRegular.x, size: 14),
            label: Text(loc.sessionDetailCancelQueued),
            style: TextButton.styleFrom(
              foregroundColor: prego.colors.textTertiary,
              minimumSize: const Size(44, 44),
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: PregoSpacing.md,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: prego.textTheme.textXs.medium,
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
      ReadOnlyPendingMessageBubblePresentation() => _status(
        prego: prego,
        icon: Icon(
          isCommand ? TablerRegular.terminal : TablerRegular.clock,
          size: 14,
          color: prego.colors.textTertiary,
        ),
        label: isCommand ? loc.sessionDetailQueuedCommand : loc.sessionDetailQueuedMessage,
      ),
    };

    return Column(
      crossAxisAlignment: .end,
      mainAxisSize: MainAxisSize.min,
      children: [
        UserMessageBubble(
          markdown: displayText,
          attachments: [
            if (localAttachments.isNotEmpty) _QueuedAttachmentPreviews(attachments: localAttachments),
            if (attachmentCount > 0 && (localAttachments.isEmpty || displayText == null))
              _QueuedAttachmentCount(count: attachmentCount),
          ],
          outlined: isPending,
          transitionDuration: duration,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            end: PregoSpacing.x2l,
            bottom: PregoSpacing.xs,
          ),
          // Cross-fade the status rail between sending/queued so the swap
          // reads as one row changing state; the enclosing prompt row eases
          // the height difference. Reduced motion swaps instantly.
          child: reducedMotion
              ? status
              : AnimatedSwitcher(
                  duration: duration,
                  child: KeyedSubtree(
                    key: ValueKey(presentation.runtimeType),
                    child: status,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _status({
    required PregoDesignSystem prego,
    required Widget icon,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: PregoSpacing.xs),
        Text(
          label,
          style: prego.textTheme.textXs.medium.copyWith(
            color: prego.colors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class const _QueuedAttachmentPreviews({required final List<ComposerAttachment> attachments}) extends StatelessWidget {
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

class const _QueuedAttachmentCount({required final int count}) extends StatelessWidget {
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
