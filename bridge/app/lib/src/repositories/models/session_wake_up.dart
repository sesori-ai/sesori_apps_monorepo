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
  required final WakeUpSchedule schedule,

  /// When it fires next.
  required final DateTime nextDueAt,
  required final DateTime createdAt,
});
