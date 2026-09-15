import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// Maps existing queue snapshots to composer rows without owning queue state.
class const SessionDetailPromptQueue({
  super.key,
  required final SessionDetailLoaded state,
  required final ValueChanged<int>? onCancelLocal,
  required final ValueChanged<String>? onCancelBridge,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final seen = <String>{
      for (final message in state.messages)
        if (message.hasRenderableUserContent)
          if (message.info case MessageUser(promptId: final id?)) id,
    };
    String preview({required String? text, required int attachmentCount}) => [
      ?text,
      if (attachmentCount > 0) loc.sessionDetailQueuedAttachmentCount(attachmentCount),
    ].join(" · ");
    PregoQueuedMessageRow row({
      required String id,
      required String? text,
      required int attachmentCount,
      required bool isCommand,
      required bool unavailable,
      required ({String label, Widget indicator})? deliveryStatus,
      required VoidCallback? onRemove,
    }) => PregoQueuedMessageRow(
      key: ValueKey("session-detail-queued-$id"),
      preview: preview(text: text, attachmentCount: attachmentCount),
      statusLabel:
          deliveryStatus?.label ??
          (unavailable
              ? loc.sessionDetailUnavailableCommand
              : isCommand
              ? loc.sessionDetailQueuedCommand
              : loc.sessionDetailQueuedMessage),
      warning: unavailable ? loc.sessionDetailUnavailableCommand : null,
      trailing: deliveryStatus != null
          ? Tooltip(
              message: deliveryStatus.label,
              excludeFromSemantics: true,
              child: SizedBox.square(
                dimension: 36,
                child: Center(child: deliveryStatus.indicator),
              ),
            )
          : onRemove != null
          ? Tooltip(
              message: unavailable ? loc.sessionDetailRemoveQueued : loc.sessionDetailCancelQueued,
              child: PregoButtonsSolid.iconOnly(
                leadingIcon: TablerRegular.trash,
                hierarchy: PregoButtonsSolidHierarchy.tertiary,
                size: PregoButtonsSolidSize.sm,
                onPressed: onRemove,
              ),
            )
          : const SizedBox.square(dimension: 36),
    );
    return PregoQueuedMessageList(
      rows: [
        for (final prompt in state.bridgeQueuedPrompts)
          if (seen.add(prompt.id))
            row(
              id: prompt.id,
              text: prompt.command == null ? prompt.text : ["/${prompt.command}", ?prompt.text].join(" "),
              attachmentCount: prompt.attachmentCount,
              isCommand: prompt.command != null,
              unavailable: false,
              deliveryStatus: switch (prompt.dispatchState) {
                QueuedPromptDispatchState.queued || QueuedPromptDispatchState.unknown => null,
                QueuedPromptDispatchState.dispatched => (
                  label: loc.sessionDetailSendingMessage,
                  indicator: const SizedBox.square(dimension: 14, child: PregoActivityIndicator(color: null)),
                ),
              },
              onRemove: prompt.dispatchState != QueuedPromptDispatchState.dispatched && onCancelBridge != null
                  ? () => onCancelBridge?.call(prompt.id)
                  : null,
            ),
        for (final submission in state.awaitingBridgeSubmissions)
          if (seen.add(submission.promptId))
            row(
              id: submission.promptId,
              text: submission.displayText,
              attachmentCount: submission.attachments.length,
              isCommand: submission.isCommand,
              unavailable: false,
              deliveryStatus: null,
              onRemove: null,
            ),
        for (final (index, submission) in state.queuedMessages.indexed)
          if (seen.add(submission.promptId))
            row(
              id: submission.promptId,
              text: submission.displayText,
              attachmentCount: submission.attachments.length,
              isCommand: submission.isCommand,
              unavailable: submission is UnavailableQueuedCommandSubmission,
              deliveryStatus: null,
              onRemove: onCancelLocal == null ? null : () => onCancelLocal?.call(index),
            ),
      ],
    );
  }
}
