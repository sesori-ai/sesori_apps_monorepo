import "package:freezed_annotation/freezed_annotation.dart";

part "message_handoff.freezed.dart";

part "message_handoff.g.dart";

/// Marks a user message that Sesori wrote to send one session into another.
///
/// Titles are snapshots taken at send time, null when the session had none.
/// The generated `toString` is off because [MessageHandoffReceived.summary]
/// is the agent's text and must not reach a log through a printed message.
@Freezed(unionKey: "kind", fallbackUnion: "unknown", fromJson: true, toJson: true, toStringOverride: false)
sealed class MessageHandoff with _$MessageHandoff {
  /// Sesori's request, in the source session, for the summary it sent.
  const factory sent({
    required String targetSessionId,
    required String? targetTitle,
  }) = MessageHandoffSent;

  /// Sesori's request, in the source session, for a summary whose send did
  /// not complete.
  const factory notSent({
    required String targetSessionId,
    required String? targetTitle,
  }) = MessageHandoffNotSent;

  /// The handoff prompt in the target session. [summary] and
  /// [transcriptPath] are kept apart from the prompt's wording, so clients
  /// never parse the prompt text.
  const factory received({
    required String sourceSessionId,
    required String? sourceTitle,
    required String summary,
    required String transcriptPath,
  }) = MessageHandoffReceived;

  /// A kind this build does not know.
  const factory unknown() = MessageHandoffUnknown;

  factory fromJson(Map<String, dynamic> json) => _$MessageHandoffFromJson(json);
}
