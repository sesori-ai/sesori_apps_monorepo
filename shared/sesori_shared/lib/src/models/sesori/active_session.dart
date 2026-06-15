import "package:freezed_annotation/freezed_annotation.dart";

part "active_session.freezed.dart";
part "active_session.g.dart";

/// A root session that is currently active — either because its own main agent
/// is running, or because a task somewhere in its subtree is.
///
/// [childSessionIds] lists only the root's DIRECT active children. Deeper active
/// descendants still cause the root to surface here (so the session list shows
/// it as running), but they are not listed individually — the field represents
/// a single level of parent→child hierarchy, which is what consumers rely on.
@Freezed(fromJson: true, toJson: true)
sealed class ActiveSession with _$ActiveSession {
  const factory ActiveSession({
    required String id,
    @Default(false) bool mainAgentRunning,
    @Default(false) bool awaitingInput,
    @Default([]) List<String> childSessionIds,
    @Default(false) bool isRetrying,
  }) = _ActiveSession;

  factory ActiveSession.fromJson(Map<String, dynamic> json) => _$ActiveSessionFromJson(json);
}
