import "dart:math" as math;

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "queued_message_bubble.dart";

/// The transcript of a session that is still being created: the first message
/// as a sending bubble, resting where the session screen's transcript puts its
/// newest row, so the session screen can take over without moving it.
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
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final attachments = switch (submission) {
      NewSessionTextSubmissionSnapshot(:final attachments) => attachments,
      NewSessionCommandSubmissionSnapshot() => const <ComposerAttachment>[],
    };
    final bubble = QueuedMessageBubble(
      displayText: submission.displayText,
      isCommand: submission is NewSessionCommandSubmissionSnapshot,
      attachmentCount: attachments.length,
      localAttachments: attachments,
      presentation: QueuedMessageBubblePresentation.sending(harnessName: harnessName, sendingSince: sendingSince),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final transcriptWidth = this.transcriptWidth;
        final horizontalInset = transcriptWidth == null
            ? 0.0
            : math.max(0.0, (constraints.maxWidth - transcriptWidth) / 2);
        // The same reversed, bottom-anchored scroll and insets as the session
        // transcript, so a long first message still scrolls and the bubble
        // lands on the transcript's newest-row position.
        return PregoTopBarInsetBuilder(
          builder: (context, topInset, child) => SingleChildScrollView(
            key: const Key("session_launch_submission_scroll"),
            primary: false,
            reverse: true,
            padding: EdgeInsetsDirectional.only(
              start: horizontalInset,
              end: horizontalInset,
              top: 8 + topInset,
              bottom: 8 + MediaQuery.paddingOf(context).bottom,
            ),
            child: child,
          ),
          child: bubble,
        );
      },
    );
  }
}
