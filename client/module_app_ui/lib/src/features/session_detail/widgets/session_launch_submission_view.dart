import "dart:math" as math;

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "queued_message_bubble.dart";
import "transcript_motion.dart";

typedef LaunchFollowUpAction = void Function({required String promptId});

/// The transcript of a session that is still being created: the first message
/// as a sending bubble, then the messages sent after it, resting where the
/// session screen's transcript puts its newest rows, so the session screen can
/// take over without moving them.
class const SessionLaunchSubmissionView({
  super.key,
  required final NewSessionSubmissionSnapshot submission,

  /// Null until the harness is known; the bubble then only says "Sending".
  required final String? harnessName,

  /// When the send began, so every rendering of this bubble reaches its
  /// slow-send copy at the same instant.
  required final DateTime? sendingSince,

  /// Caps the reading column the way a pointer surface's transcript does; null
  /// spans the pane, as the phone does.
  required final double? transcriptWidth,

  /// Follow-ups the session screen already parked as accepted, then the
  /// launch's own, then the prompts sent on the session screen — the order the
  /// session's transcript lists them in.
  required final List<QueuedSessionSubmission> awaitingBridgeSubmissions,
  required final List<LaunchFollowUp> launchFollowUps,
  required final List<QueuedSessionSubmission> queuedMessages,
  required final LaunchFollowUpAction? onRetryLaunchFollowUp,
  required final LaunchFollowUpAction? onRemoveLaunchFollowUp,
  required final ValueChanged<int>? onCancelQueuedMessage,

  /// What covers the bottom of the pane: the composer floating over it, or
  /// null for the device's own inset when nothing does.
  required final double? bottomInset,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    QueuedMessageBubble bubble({
      required Key key,
      required String? displayText,
      required bool isCommand,
      required List<ComposerAttachment> attachments,
      required QueuedMessageBubblePresentation presentation,
    }) => QueuedMessageBubble(
      key: key,
      displayText: displayText,
      isCommand: isCommand,
      attachmentCount: attachments.length,
      localAttachments: attachments,
      presentation: presentation,
    );
    QueuedMessageBubble queued({
      required QueuedSessionSubmission submission,
      required QueuedMessageBubblePresentation presentation,
    }) => bubble(
      key: ValueKey(submission.promptId),
      displayText: submission.displayText,
      isCommand: submission.isCommand,
      attachments: submission.attachments,
      presentation: presentation,
    );
    final onCancelQueuedMessage = this.onCancelQueuedMessage;
    final rows = [
      bubble(
        key: const ValueKey("session-launch-first"),
        displayText: submission.displayText,
        isCommand: submission is NewSessionCommandSubmissionSnapshot,
        attachments: switch (submission) {
          NewSessionTextSubmissionSnapshot(:final attachments) => attachments,
          NewSessionCommandSubmissionSnapshot() => const <ComposerAttachment>[],
        },
        presentation: QueuedMessageBubblePresentation.sending(harnessName: harnessName, sendingSince: sendingSince),
      ),
      for (final submission in awaitingBridgeSubmissions)
        queued(submission: submission, presentation: const QueuedMessageBubblePresentation.pendingReadOnly()),
      for (final followUp in launchFollowUps)
        queued(
          submission: followUp.submission,
          presentation: launchFollowUpPresentation(
            followUp: followUp,
            harnessName: harnessName,
            onRetry: onRetryLaunchFollowUp,
            onRemove: onRemoveLaunchFollowUp,
          ),
        ),
      for (final (index, submission) in queuedMessages.indexed)
        queued(
          submission: submission,
          presentation: onCancelQueuedMessage == null
              ? const QueuedMessageBubblePresentation.pendingReadOnly()
              : QueuedMessageBubblePresentation.pending(onCancel: () => onCancelQueuedMessage(index)),
        ),
    ];
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final transcriptWidth = this.transcriptWidth;
        final horizontalInset = transcriptWidth == null
            ? 0.0
            : math.max(0.0, (constraints.maxWidth - transcriptWidth) / 2);
        // The same reversed, bottom-anchored scroll and insets as the session
        // transcript, so a long first message still scrolls and the bubbles
        // land on the transcript's newest-row positions.
        return PregoTopBarInsetBuilder(
          builder: (context, topInset, child) => SingleChildScrollView(
            key: const Key("session_launch_submission_scroll"),
            primary: false,
            reverse: true,
            padding: EdgeInsetsDirectional.only(
              start: horizontalInset,
              end: horizontalInset,
              top: 8 + topInset,
              bottom: 8 + (bottomInset ?? MediaQuery.paddingOf(context).bottom),
            ),
            child: child,
          ),
          // A message sent while this shows grows the column instead of
          // popping in below the ones before it.
          child: context.isReducedMotion
              ? column
              : AnimatedSize(
                  duration: transcriptMotionDuration,
                  curve: transcriptMotionCurve,
                  alignment: AlignmentDirectional.topStart,
                  child: column,
                ),
        );
      },
    );
  }
}

/// How a launch follow-up's bubble reads in each of its states.
QueuedMessageBubblePresentation launchFollowUpPresentation({
  required LaunchFollowUp followUp,
  required String? harnessName,
  required LaunchFollowUpAction? onRetry,
  required LaunchFollowUpAction? onRemove,
}) {
  final promptId = followUp.submission.promptId;
  return switch (followUp) {
    SendingLaunchFollowUp(:final since) => QueuedMessageBubblePresentation.sending(
      harnessName: harnessName,
      sendingSince: since,
    ),
    QueuedLaunchFollowUp() when onRemove != null => QueuedMessageBubblePresentation.pending(
      onCancel: () => onRemove(promptId: promptId),
    ),
    QueuedLaunchFollowUp() || AcceptedLaunchFollowUp() => const QueuedMessageBubblePresentation.pendingReadOnly(),
    // A lost response may already have reached the bridge, so only an
    // authoritative rejection can be removed; Retry is safe either way,
    // since the bridge drops a promptId it already took.
    FailedLaunchFollowUp(:final failure) => QueuedMessageBubblePresentation.failed(
      onRetry: onRetry == null ? null : () => onRetry(promptId: promptId),
      onRemove: onRemove == null || failure != PromptSendFailure.rejected ? null : () => onRemove(promptId: promptId),
    ),
  };
}
