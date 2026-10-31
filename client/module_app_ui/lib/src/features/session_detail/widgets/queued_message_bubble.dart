import "dart:async";

import "package:clock/clock.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

import "user_message_card.dart";

sealed class const QueuedMessageBubblePresentation() {
  /// [harnessName] is null until the harness status loads. [sendingSince] is
  /// the instant the send began when it predates this bubble, so a bubble
  /// rebuilt mid-send keeps its slow-send copy; null starts the clock now.
  const factory sending({required String? harnessName, required DateTime? sendingSince}) =
      SendingMessageBubblePresentation;

  /// [sentAt] is when the message was sent, as the Queued line follows the same
  /// clock as a send's status. Null for a message this surface has no send time
  /// for, which shows its line at once.
  const factory pending({required VoidCallback onCancel, required DateTime? sentAt}) = PendingMessageBubblePresentation;
  const factory pendingReadOnly({required DateTime? sentAt}) = ReadOnlyPendingMessageBubblePresentation;
  const factory commandUnavailable({required VoidCallback? onRemove}) = UnavailableCommandBubblePresentation;

  /// A send that failed. The callbacks are null on a read-only surface.
  const factory failed({required VoidCallback? onRetry, required VoidCallback? onRemove}) =
      FailedMessageBubblePresentation;
}

final class const SendingMessageBubblePresentation({
  required final String? harnessName,
  required final DateTime? sendingSince,
}) extends QueuedMessageBubblePresentation;

final class const PendingMessageBubblePresentation({
  required final VoidCallback onCancel,
  required final DateTime? sentAt,
}) extends QueuedMessageBubblePresentation;

final class const ReadOnlyPendingMessageBubblePresentation({required final DateTime? sentAt})
    extends QueuedMessageBubblePresentation;

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
  /// How long a message waits before it shows its Sending or Queued line at all.
  /// Until then its row has no status line, the same height as the delivered
  /// message, so one delivered by then moves nothing.
  static const _statusDelay = Duration(seconds: 2);

  static const _statusFade = Duration(milliseconds: 240);

  Timer? _statusTimer;
  bool _isStatusDue = false;

  /// The states whose line waits. A failure and an unavailable command need
  /// acting on, so theirs shows at once.
  static bool _waitsForStatus(QueuedMessageBubblePresentation presentation) => switch (presentation) {
    SendingMessageBubblePresentation() ||
    PendingMessageBubblePresentation() ||
    ReadOnlyPendingMessageBubblePresentation() => true,
    UnavailableCommandBubblePresentation() || FailedMessageBubblePresentation() => false,
  };

  static DateTime? _statusClock(QueuedMessageBubblePresentation presentation) => switch (presentation) {
    SendingMessageBubblePresentation(:final sendingSince) => sendingSince,
    PendingMessageBubblePresentation(:final sentAt) => sentAt,
    ReadOnlyPendingMessageBubblePresentation(:final sentAt) => sentAt,
    UnavailableCommandBubblePresentation() || FailedMessageBubblePresentation() => null,
  };

  @override
  void initState() {
    super.initState();
    _syncStatusTimer();
  }

  @override
  void didUpdateWidget(QueuedMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.presentation;
    final presentation = widget.presentation;
    final since = _statusClock(presentation);
    // A line that has shown stays, whatever waiting state the message moves on to,
    // and a state with no send time of its own carries on from the one before it.
    if (_waitsForStatus(previous) != _waitsForStatus(presentation) ||
        (!_isStatusDue && since != null && since != _statusClock(previous))) {
      _syncStatusTimer();
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  void _syncStatusTimer() {
    _statusTimer?.cancel();
    final presentation = widget.presentation;
    final remaining = switch (_statusClock(presentation)) {
      final since? => _statusDelay - clock.now().difference(since),
      null => presentation is SendingMessageBubblePresentation ? _statusDelay : Duration.zero,
    };
    _isStatusDue = remaining <= Duration.zero;
    if (_isStatusDue) return;
    _statusTimer = Timer(remaining, () {
      if (mounted) setState(() => _isStatusDue = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final reducedMotion = context.isReducedMotion;
    final duration = reducedMotion ? Duration.zero : _statusFade;
    final presentation = widget.presentation;
    final isCommand = widget.isCommand;
    final displayText = widget.displayText;
    final attachmentCount = widget.attachmentCount;
    final localAttachments = widget.localAttachments;
    final Widget? status = switch (presentation) {
      // Absent rather than hidden, so that Cancel can't be reached before it shows.
      SendingMessageBubblePresentation() ||
      PendingMessageBubblePresentation() ||
      ReadOnlyPendingMessageBubblePresentation() when !_isStatusDue => null,
      // The label names the harness, so it wraps rather than overflowing a
      // narrow pane at large text.
      SendingMessageBubblePresentation(:final harnessName) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ExcludeSemantics(
            child: SizedBox.square(
              dimension: 14,
              child: PregoActivityIndicator(color: null),
            ),
          ),
          const SizedBox(width: PregoSpacing.xs),
          Flexible(
            child: Text(
              harnessName != null ? loc.sessionDetailSendingToHarness(harnessName) : loc.sessionDetailSendingMessage,
              style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textTertiary),
            ),
          ),
        ],
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
      // Wraps so both actions stay reachable in a narrow pane or at large text.
      FailedMessageBubblePresentation(:final onRetry, :final onRemove) => Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: PregoSpacing.xs,
        children: [
          // Inside the Wrap the label is bounded, so it may wrap itself.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(TablerRegular.alert_circle, size: PregoIconSize.sm, color: prego.colors.fgErrorPrimary),
              const SizedBox(width: PregoSpacing.xs),
              Flexible(
                child: Text(
                  loc.sessionDetailSendFailed,
                  style: prego.textTheme.textXs.medium.copyWith(color: prego.colors.textErrorPrimary),
                ),
              ),
            ],
          ),
          if (onRetry != null)
            _action(prego: prego, icon: TablerRegular.refresh, label: loc.sessionDetailRetry, onPressed: onRetry),
          if (onRemove != null)
            _action(prego: prego, icon: TablerRegular.x, label: loc.sessionDetailRemoveQueued, onPressed: onRemove),
        ],
      ),
    };

    // Nothing at all without a status, padding included, so that the row is the
    // same height as the delivered message.
    final statusRail = status == null
        ? const SizedBox.shrink()
        : KeyedSubtree(
            key: ValueKey(presentation.runtimeType),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                end: PregoSpacing.x2l,
                bottom: PregoSpacing.xs,
              ),
              child: status,
            ),
          );

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
          // Nothing says it is queued before its line does.
          outlined: status != null && presentation is! SendingMessageBubblePresentation,
          transitionDuration: duration,
        ),
        // Cross-fade the status rail between its states, a line's arrival among
        // them, so the swap reads as one row changing state; the enclosing prompt
        // row eases the height difference. Reduced motion keeps the fade, which
        // moves nothing, and the row takes its height at once.
        // Cancelling a queued prompt must not dismiss an in-progress draft.
        TextFieldTapRegion(
          child: AnimatedSwitcher(duration: _statusFade, child: statusRail),
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
