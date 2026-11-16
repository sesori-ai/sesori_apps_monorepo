import "package:freezed_annotation/freezed_annotation.dart";

part "session_composer_mode.freezed.dart";

/// What the session composer's Send does.
@Freezed()
sealed class SessionComposerMode with _$SessionComposerMode {
  /// Send adds a prompt to the session.
  const factory normal() = SessionComposerNormal;

  /// The composer holds an edit of [messageId]: Resend replaces that message
  /// and everything after it. [leftOutCount] attachments of the message could
  /// not be brought back.
  const factory editing({
    required String messageId,
    required SessionEditPhase phase,
    required int leftOutCount,
  }) = SessionComposerEditing;
}

enum SessionEditPhase() {
  /// The message's text and attachments are being brought back.
  restoring,

  /// The user is changing the message.
  composing,

  /// The session is stopping so the edit can go.
  stopping,

  /// The edit awaits the bridge.
  sending,
}
