import "package:freezed_annotation/freezed_annotation.dart";

part "active_session.freezed.dart";
part "active_session.g.dart";

/// A root session that is currently active, along with the active (busy or
/// retrying) descendant sessions nested beneath it.
///
/// A session is considered active when either the main agent or any task in its
/// subtree is running. Active descendants at any depth are attributed to their
/// root session; [childSessionIds] therefore lists every active descendant, not
/// only direct children.
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
