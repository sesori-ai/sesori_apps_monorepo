import "package:freezed_annotation/freezed_annotation.dart";

part "session_activity_info.freezed.dart";

/// Describes the activity state of a single root session.
///
/// Used by the session list to show whether the main agent is running and
/// how many background (child) tasks are active.
@Freezed()
sealed class SessionActivityInfo with _$SessionActivityInfo {
  const factory SessionActivityInfo({
    @Default(false) bool mainAgentRunning,
    @Default(false) bool awaitingInput,
    @Default(0) int backgroundTaskCount,
  }) = _SessionActivityInfo;
}
