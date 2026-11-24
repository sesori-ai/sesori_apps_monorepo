import "package:freezed_annotation/freezed_annotation.dart";

part "session_wake_up.freezed.dart";

part "session_wake_up.g.dart";

/// A wake-up an agent set for its root session: a prompt Sesori sends the
/// session later, once or on repeat, until it fires or is cancelled.
@Freezed(fromJson: true, toJson: true)
sealed class SessionWakeUp with _$SessionWakeUp {
  const factory({
    required String id,

    /// When it fires next, in UTC milliseconds.
    required int nextDueAt,

    /// The agent's one-line label for it.
    required String label,

    /// Whether it fires again after [nextDueAt], until it is cancelled.
    required bool repeats,

    /// Whether it runs a shell command when it fires.
    required bool runsCommand,
  }) = _SessionWakeUp;

  factory fromJson(Map<String, dynamic> json) => _$SessionWakeUpFromJson(json);
}

/// Whether Sesori will wake the session again by itself: a pending wake-up,
/// or a same-session task that continues in it.
@Freezed(unionKey: "kind", fallbackUnion: "unreported", fromJson: true, toJson: true)
sealed class SessionArming with _$SessionArming {
  /// The bridge does not report arming: it predates it, or it sent a kind
  /// this build does not know. The app keeps the plain task mark.
  const factory unreported() = SessionArmingUnreported;

  /// Nothing will wake the session again.
  const factory notArmed() = SessionArmingNotArmed;

  /// The soonest thing that wakes the session: a wake-up's label or a task's
  /// name, and its time in UTC milliseconds.
  const factory armed({required String name, required int nextAt}) = SessionArmingArmed;

  factory fromJson(Map<String, dynamic> json) => _$SessionArmingFromJson(json);
}
