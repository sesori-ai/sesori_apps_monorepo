import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart" show TaskSchedule;

part "session_wake_up.freezed.dart";
part "session_wake_up.g.dart";

/// When a wake-up fires.
@Freezed(unionKey: "kind", fromJson: true, toJson: true, copyWith: false)
sealed class WakeUpSchedule with _$WakeUpSchedule {
  /// Once, at its due time.
  const factory once() = WakeUpOnce;

  /// Every [minutes] real minutes from when it was set.
  const factory every({required int minutes}) = WakeUpEvery;

  /// At [schedule]'s wall-clock times in [timeZone]: a daily, weekdays or
  /// weekly schedule.
  const factory calendar({required TaskSchedule schedule, required String timeZone}) = WakeUpCalendar;

  factory fromJson(Map<String, dynamic> json) => _$WakeUpScheduleFromJson(json);
}

/// A pending or repeating wake-up.
final class const StoredSessionWakeUp({
  required final String id,

  /// The root session it is sent to.
  required final String sessionId,
  required final String label,
  required final String prompt,

  /// The shell command run before the prompt is sent, if any.
  required final WakeUpCommand? command,
  required final WakeUpSchedule schedule,

  /// When it fires next.
  required final DateTime nextDueAt,
  required final DateTime createdAt,
});

/// A shell command a wake-up runs right before its prompt is sent; the result
/// goes into the prompt.
final class const WakeUpCommand({required final String command, required final WakeUpCommandApproval approval});

enum WakeUpCommandApproval() {
  /// The user allowed it, so it never asks again.
  allowed,

  /// Set while its session approved everything, so no one allowed it. It asks
  /// before it runs once the session no longer approves everything.
  byMode,
}

/// When a requested wake-up fires.
sealed class const WakeUpRequestedTime();

/// Once, [minutes] from now.
final class const WakeUpInMinutes({required final int minutes}) extends WakeUpRequestedTime;

/// Every [minutes], the first [minutes] from now.
final class const WakeUpEveryMinutes({required final int minutes}) extends WakeUpRequestedTime;

/// On a daily, weekdays or weekly [schedule].
final class const WakeUpOnSchedule({required final TaskSchedule schedule}) extends WakeUpRequestedTime;
