import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

import "user_message_card.dart";

sealed class const QueuedMessageBubblePresentation() {
  /// [harnessName] is null until the harness status loads.
  const factory sending({required String? harnessName}) = SendingMessageBubblePresentation;
  const factory pending({required VoidCallback onCancel}) = PendingMessageBubblePresentation;
  const factory pendingReadOnly() = ReadOnlyPendingMessageBubblePresentation;
  const factory commandUnavailable({required VoidCallback? onRemove}) = UnavailableCommandBubblePresentation;

  /// A send that failed. The callbacks are null on a read-only surface.
  const factory failed({required VoidCallback? onRetry, required VoidCallback? onRemove}) =
      FailedMessageBubblePresentation;
}

final class const SendingMessageBubblePresentation({required final String? harnessName})
    extends QueuedMessageBubblePresentation;

final class const PendingMessageBubblePresentation({required final VoidCallback onCancel})
    extends QueuedMessageBubblePresentation;

final class const ReadOnlyPendingMessageBubblePresentation() extends QueuedMessageBubblePresentation;

final class const UnavailableCommandBubblePresentation({required final VoidCallback? onRemove})
    extends QueuedMessageBubblePresentation;

final class const FailedMessageBubblePresentation({
  required final VoidCallback? onRetry,
  required final VoidCallback? onRemove,
}) extends QueuedMessageBubblePresentation;

class const QueuedMessageBubble({
  super.key,
  required final String? displayText,
  required final bool isCommand,
  required final int attachmentCount,

  /// This surface retains bounded local previews through bridge queue dispatch.
  /// Evicted previews and prompts from another surface render an attachment
  /// count instead.
  required final List<ComposerAttachment> localAttachments,
  required final QueuedMessageBubblePresentation presentation,
}) extends StatefulWidget {
  @override
  State<QueuedMessageBubble> createState() => _QueuedMessageBubbleState();
}

class _QueuedMessageBubbleState() extends State<QueuedMessageBubble> {
  /// How long a send runs before its status names the harness it waits on.
  static const _slowSendDelay = Duration(seconds: 2);

  Timer? _slowSendTimer;
  bool _isSlowSend = false;

  @override
  void initState() {
    super.initState();
    _syncSlowSendTimer();
  }

  @override
  void didUpdateWidget(QueuedMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasSending = oldWidget.presentation is SendingMessageBubblePresentation;
    if (wasSending != widget.presentation is SendingMessageBubblePresentation) _syncSlowSendTimer();
  }

  @override
  void dispose() {
    _slowSendTimer?.cancel();
    super.dispose();
  }

  void _syncSlowSendTimer() {
    _slowSendTimer?.cancel();
    _slowSendTimer = null;
    _isSlowSend = false;
    if (widget.presentation is! SendingMessageBubblePresentation) return;
    _slowSendTimer = Timer(_slowSendDelay, () {
      if (mounted) setState(() => _isSlowSend = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final reducedMotion = context.isReducedMotion;
    final duration = reducedMotion ? Duration.zero : const Duration(milliseconds: 240);
    final presentation = widget.presentation;
    final isCommand = widget.isCommand;
    final displayText = widget.displayText;
    final attachmentCount = widget.attachmentCount;
    final localAttachments = widget.localAttachments;
    final isPending =
        presentation is PendingMessageBubblePresentation ||
        presentation is ReadOnlyPendingMessageBubblePresentation ||
        presentation is UnavailableCommandBubblePresentation ||
        presentation is FailedMessageBubblePresentation;
    final status = switch (presentation) {
      SendingMessageBubblePresentation(:final harnessName) => _status(
        prego: prego,
        icon: const ExcludeSemantics(
          child: SizedBox.square(
            dimension: 14,
            child: PregoActivityIndicator(color: null),
          ),
        ),
        label: _isSlowSend && harnessName != null
            ? loc.sessionDetailSendingToHarness(harnessName)
            : loc.sessionDetailSendingMessage,
        color: prego.colors.textTertiary,
      ),
      PendingMessageBubblePresentation(:final onCancel) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _status(
            prego: prego,
            icon: Icon(
              isCommand ? TablerRegular.terminal : TablerRegular.clock,
              size: PregoIconSize.sm,
              color: prego.colors.textTertiary,
            ),
            label: isCommand ? loc.sessionDetailQueuedCommand : loc.sessionDetailQueuedMessage,
            color: prego.colors.textTertiary,
          ),
          const SizedBox(width: PregoSpacing.xs),
          TextButton.icon(
            onPressed: onCancel,
            icon: const Icon(TablerRegular.x, size: PregoIconSize.sm),
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
          size: PregoIconSize.sm,
          color: prego.colors.textTertiary,
        ),
        label: isCommand ? loc.sessionDetailQueuedCommand : loc.sessionDetailQueuedMessage,
        color: prego.colors.textTertiary,
      ),
      UnavailableCommandBubblePresentation(:final onRemove) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _status(
            prego: prego,
            icon: Icon(
              TablerRegular.alert_circle,
              size: PregoIconSize.sm,
              color: prego.colors.fgErrorPrimary,
            ),
            label: loc.sessionDetailUnavailableCommand,
            color: prego.colors.textErrorPrimary,
          ),
          if (onRemove != null) ...[
            const SizedBox(width: PregoSpacing.xs),
            TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(TablerRegular.x, size: PregoIconSize.sm),
              label: Text(loc.sessionDetailRemoveQueued),
              style: TextButton.styleFrom(
                foregroundColor: prego.colors.textErrorPrimary,
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
        ],
      ),
      FailedMessageBubblePresentation(:final onRetry, :final onRemove) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _status(
            prego: prego,
            icon: Icon(TablerRegular.alert_circle, size: PregoIconSize.sm, color: prego.colors.fgErrorPrimary),
            label: loc.sessionDetailSendFailed,
            color: prego.colors.textErrorPrimary,
          ),
          if (onRetry != null) ...[
            const SizedBox(width: PregoSpacing.xs),
            _action(prego: prego, icon: TablerRegular.refresh, label: loc.sessionDetailRetry, onPressed: onRetry),
          ],
          if (onRemove != null)
            _action(prego: prego, icon: TablerRegular.x, label: loc.sessionDetailRemoveQueued, onPressed: onRemove),
        ],
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
          // Cancelling a queued prompt must not dismiss an in-progress draft.
          child: TextFieldTapRegion(
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
        ),
      ],
    );
  }

  Widget _action({
    required PregoDesignSystem prego,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: PregoIconSize.sm),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: prego.colors.textErrorPrimary,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: PregoSpacing.md),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: prego.textTheme.textXs.medium,
        shape: const StadiumBorder(),
      ),
    );
  }

  Widget _status({
    required PregoDesignSystem prego,
    required Widget icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: PregoSpacing.xs),
        Text(
          label,
          style: prego.textTheme.textXs.medium.copyWith(color: color),
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
                    child: Icon(TablerRegular.photo_off, color: prego.colors.textSecondary),
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
          Icon(TablerRegular.photo, size: PregoIconSize.sm, color: prego.colors.textBrandPrimary),
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
