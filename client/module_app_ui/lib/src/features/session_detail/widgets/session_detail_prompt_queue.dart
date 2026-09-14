import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
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
      required VoidCallback? onRemove,
    }) => PregoQueuedMessageRow(
      key: ValueKey("session-detail-queued-$id"),
      preview: preview(text: text, attachmentCount: attachmentCount),
      statusLabel: unavailable
          ? loc.sessionDetailUnavailableCommand
          : isCommand
          ? loc.sessionDetailQueuedCommand
          : loc.sessionDetailQueuedMessage,
      warning: unavailable ? loc.sessionDetailUnavailableCommand : null,
      removeLabel: unavailable ? loc.sessionDetailRemoveQueued : loc.sessionDetailCancelQueued,
      onRemove: onRemove,
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
              onRemove: onCancelBridge == null ? null : () => onCancelBridge?.call(prompt.id),
            ),
        for (final submission in state.awaitingBridgeSubmissions)
          if (seen.add(submission.promptId))
            row(
              id: submission.promptId,
              text: submission.displayText,
              attachmentCount: submission.attachments.length,
              isCommand: submission.isCommand,
              unavailable: false,
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
              onRemove: onCancelLocal == null ? null : () => onCancelLocal?.call(index),
            ),
      ],
    );
  }
}
