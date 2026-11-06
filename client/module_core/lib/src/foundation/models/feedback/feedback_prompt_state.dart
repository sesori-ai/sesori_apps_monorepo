import "package:freezed_annotation/freezed_annotation.dart";

part "feedback_prompt_state.freezed.dart";
part "feedback_prompt_state.g.dart";

/// This device's progress toward the automatic rating prompt.
@Freezed(unionKey: "kind", fromJson: true, toJson: true)
sealed class FeedbackPromptState with _$FeedbackPromptState {
  /// Counting finished turns toward the next automatic showing.
  ///
  /// [pointsBySession] holds, per session ID, the agent turns that finished
  /// cleanly since that session's last failure or the last showing, so a
  /// failure drops only its own session's points. [lastShownAt] is when the
  /// prompt last opened by itself, or null when it never has; the cooldown runs
  /// from it.
  @FreezedUnionValue("counting")
  const factory counting({
    // COMPATIBILITY 2026-11-06 (v1.12.0): Progress stored before per-session points has a single positiveCount and
    // no pointsBySession; it starts from no points and keeps its lastShownAt. Remove @Default and require
    // pointsBySession once no public release older than v1.12.0 is supported.
    @Default(<String, int>{}) Map<String, int> pointsBySession,
    required DateTime? lastShownAt,
  }) = FeedbackPromptCounting;

  /// The user answered **Yes**, so the prompt never opens by itself again.
  @FreezedUnionValue("retired")
  const factory retired() = FeedbackPromptRetired;

  factory fromJson(Map<String, dynamic> json) => _$FeedbackPromptStateFromJson(json);
}

extension FeedbackPromptCountingX on FeedbackPromptCounting {
  /// Every session's points together; the threshold applies to this total.
  int get totalPoints => pointsBySession.values.fold(0, (sum, points) => sum + points);
}
