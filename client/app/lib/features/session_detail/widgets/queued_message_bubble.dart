import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";
import "user_message_card.dart";

sealed class QueuedMessageBubblePresentation {
  const QueuedMessageBubblePresentation();

  const factory QueuedMessageBubblePresentation.sending() = SendingMessageBubblePresentation;
  const factory QueuedMessageBubblePresentation.pending({required VoidCallback onCancel}) =
      PendingMessageBubblePresentation;
}

final class SendingMessageBubblePresentation extends QueuedMessageBubblePresentation {
  const SendingMessageBubblePresentation();
}

final class PendingMessageBubblePresentation extends QueuedMessageBubblePresentation {
  final VoidCallback onCancel;

  const PendingMessageBubblePresentation({required this.onCancel});
}

class QueuedMessageBubble extends StatelessWidget {
  final QueuedSessionSubmission submission;
  final QueuedMessageBubblePresentation presentation;

  const QueuedMessageBubble({
    super.key,
    required this.submission,
    required this.presentation,
  });

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final reducedMotion = context.isReducedMotion;
    final duration = reducedMotion ? Duration.zero : const Duration(milliseconds: 240);
    final isPending = presentation is PendingMessageBubblePresentation;
    final status = KeyedSubtree(
      key: ValueKey(presentation.runtimeType),
      child: switch (presentation) {
        SendingMessageBubblePresentation() => _status(
          prego: prego,
          icon: ExcludeSemantics(
            child: SizedBox.square(
              dimension: 14,
              child: CircularProgressIndicator(
                value: reducedMotion ? 0.75 : null,
                strokeWidth: 1.5,
                strokeCap: StrokeCap.round,
                color: prego.colors.textTertiary,
              ),
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
                submission.isCommand ? TablerRegular.terminal : TablerRegular.clock,
                size: 14,
                color: prego.colors.textTertiary,
              ),
              label: submission.isCommand ? loc.sessionDetailQueuedCommand : loc.sessionDetailQueuedMessage,
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
      },
    );

    return Column(
      crossAxisAlignment: .end,
      mainAxisSize: MainAxisSize.min,
      children: [
        UserMessageBubble(
          markdown: submission.displayText ?? loc.sessionDetailQueuedAttachmentCount(submission.attachments.length),
          attachments: const [],
          outlined: isPending,
          transitionDuration: duration,
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(
            end: PregoSpacing.x2l,
            bottom: PregoSpacing.xs,
          ),
          child: reducedMotion
              ? status
              : AnimatedSize(
                  duration: duration,
                  curve: Curves.easeInOutCubic,
                  alignment: AlignmentDirectional.centerEnd,
                  child: AnimatedSwitcher(
                    duration: duration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SizeTransition(
                        axis: Axis.horizontal,
                        alignment: AlignmentDirectional.centerEnd,
                        sizeFactor: animation,
                        child: child,
                      ),
                    ),
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      alignment: AlignmentDirectional.centerEnd,
                      children: [
                        for (final child in previousChildren)
                          IgnorePointer(
                            child: ExcludeFocus(
                              child: ExcludeSemantics(child: child),
                            ),
                          ),
                        ?currentChild,
                      ],
                    ),
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
