import "dart:math" show min;

import "package:sesori_shared/sesori_shared.dart"
    show
        TaskLocalDateTime,
        TaskMissedRunPolicy,
        TaskSchedule,
        TaskScheduleDaily,
        TaskScheduleEveryHours,
        TaskScheduleOnce,
        TaskScheduleUnknown,
        TaskScheduleWeekdays,
        TaskScheduleWeekly,
        TaskTimeOfDay,
        TaskWeekday;
import "package:timezone/timezone.dart" as tz;

/// What the scheduler does with a task whose time has come.
enum ScheduledTaskDueAction() {
  /// Seen within [ScheduledTaskOccurrenceCalculator.onTimeGrace] of its time.
  fireOnTime,

  /// Seen later than the grace, so the run is marked late. It is one run, however
  /// many times were missed.
  fireLate,

  /// Seen later than the grace by a task that waits for the next time. One
  /// missed row stands for every missed time.
  recordMissed,
}

/// Owns when tasks run: the instants a schedule falls on in the task's zone,
/// and what to do with a task found due.
///
/// Wall-clock schedules (once, daily, weekdays, weekly) keep their local time
/// across daylight-saving changes. A local time that does not exist (the
/// spring-forward gap) runs the same distance into the gap after the jump, so
/// 02:30 runs at 03:30; a local time that happens twice (fall-back) runs once,
/// at the first instant. Every-hours schedules are a fixed real-time interval
/// from their start.
///
/// Zone names resolve through the process-wide time-zone database, which
/// bridge startup loads.
class const ScheduledTaskOccurrenceCalculator() {
  /// A run this close to its time is on time; later is late, or missed.
  static const Duration onTimeGrace = Duration(minutes: 2);

  static const Set<TaskWeekday> _weekdays = {
    TaskWeekday.monday,
    TaskWeekday.tuesday,
    TaskWeekday.wednesday,
    TaskWeekday.thursday,
    TaskWeekday.friday,
  };
  static const int _dayMs = Duration.millisecondsPerDay;

  bool isKnownTimeZone({required String timeZone}) {
    try {
      tz.getLocation(timeZone);
      return true;
    } on tz.LocationNotFoundException {
      return false;
    }
  }

  /// When a task saved, edited or resumed at [now] falls due.
  ///
  /// A one-off task's time is returned as it is, even when it has passed:
  /// saving one in the past is refused by the caller, and one that comes due
  /// while the bridge is off still runs when it is back. A recurring task's
  /// is its first time strictly after [now], so a resume never replays the
  /// paused period. Null when the schedule never falls due.
  ///
  /// Throws [tz.LocationNotFoundException] for an unknown [timeZone].
  DateTime? firstDueAt({required TaskSchedule schedule, required String timeZone, required DateTime now}) {
    final location = tz.getLocation(timeZone);
    return switch (schedule) {
      TaskScheduleOnce(:final at) => _instantOf(location: location, local: at),
      _ => _nextRecurringAfter(location: location, schedule: schedule, now: now),
    };
  }

  /// When a task falls due next after a run, skip or missed row written at
  /// [now]: its first time strictly after [now], or null for a one-off task,
  /// which is done.
  ///
  /// Throws [tz.LocationNotFoundException] for an unknown [timeZone].
  DateTime? nextDueAfterRun({required TaskSchedule schedule, required String timeZone, required DateTime now}) {
    final location = tz.getLocation(timeZone);
    return _nextRecurringAfter(location: location, schedule: schedule, now: now);
  }

  /// The zone's UTC offset at [instant], in minutes east of UTC.
  ///
  /// Throws [tz.LocationNotFoundException] for an unknown [timeZone].
  int offsetMinutesAt({required DateTime instant, required String timeZone}) {
    final location = tz.getLocation(timeZone);
    return _offsetMs(location: location, utcMs: instant.millisecondsSinceEpoch) ~/ Duration.millisecondsPerMinute;
  }

  /// What to do with a task due at [dueAt] that the scheduler sees at [now].
  ///
  /// A one-off task always runs when the bridge is back, since it has no next
  /// time to wait for. An unknown policy never reaches storage; it reads as the
  /// default, run when back.
  ScheduledTaskDueAction dueAction({
    required TaskSchedule schedule,
    required TaskMissedRunPolicy missedRunPolicy,
    required DateTime dueAt,
    required DateTime now,
  }) {
    if (now.difference(dueAt) <= onTimeGrace) return ScheduledTaskDueAction.fireOnTime;
    if (schedule is TaskScheduleOnce) return ScheduledTaskDueAction.fireLate;
    return switch (missedRunPolicy) {
      TaskMissedRunPolicy.runWhenBack || TaskMissedRunPolicy.unknown => ScheduledTaskDueAction.fireLate,
      TaskMissedRunPolicy.waitForNext => ScheduledTaskDueAction.recordMissed,
    };
  }

  DateTime? _nextRecurringAfter({
    required tz.Location location,
    required TaskSchedule schedule,
    required DateTime now,
  }) {
    return switch (schedule) {
      TaskScheduleOnce() || TaskScheduleUnknown() => null,
      TaskScheduleDaily(:final time) => _nextOnDays(
        location: location,
        days: TaskWeekday.values.toSet(),
        time: time,
        now: now,
      ),
      TaskScheduleWeekdays(:final time) => _nextOnDays(location: location, days: _weekdays, time: time, now: now),
      TaskScheduleWeekly(:final days, :final time) => _nextOnDays(
        location: location,
        days: days,
        time: time,
        now: now,
      ),
      TaskScheduleEveryHours(:final hours, :final start) => _nextInterval(
        start: _instantOf(location: location, local: start),
        interval: Duration(hours: hours),
        now: now,
      ),
    };
  }

  DateTime? _nextOnDays({
    required tz.Location location,
    required Set<TaskWeekday> days,
    required TaskTimeOfDay time,
    required DateTime now,
  }) {
    final today = tz.TZDateTime.from(now, location);
    // Today's time may have passed, so a single weekly day can be 7 days out.
    for (var offset = 0; offset <= 7; offset++) {
      // A UTC date steps whole calendar days without zone effects.
      final date = DateTime.utc(today.year, today.month, today.day + offset);
      if (!days.any((day) => day.isoWeekday == date.weekday)) continue;
      final candidate = _instantOf(
        location: location,
        local: TaskLocalDateTime(
          year: date.year,
          month: date.month,
          day: date.day,
          hour: time.hour,
          minute: time.minute,
        ),
      );
      if (candidate.isAfter(now)) return candidate;
    }
    return null;
  }

  DateTime _nextInterval({required DateTime start, required Duration interval, required DateTime now}) {
    if (start.isAfter(now)) return start;
    final elapsedIntervals = now.difference(start).inMilliseconds ~/ interval.inMilliseconds;
    return start.add(interval * (elapsedIntervals + 1));
  }

  /// The UTC instant [local] names in [location], resolving gaps and overlaps
  /// as the class documents.
  DateTime _instantOf({required tz.Location location, required TaskLocalDateTime local}) {
    // The wall-clock fields read as if they were UTC.
    final wallMs = DateTime.utc(local.year, local.month, local.day, local.hour, local.minute).millisecondsSinceEpoch;
    // Zone transitions are months apart, so the offsets a day either side are
    // the only two this wall time can mean.
    final offsetBefore = _offsetMs(location: location, utcMs: wallMs - _dayMs);
    final offsetAfter = _offsetMs(location: location, utcMs: wallMs + _dayMs);
    final valid = [
      for (final offset in {offsetBefore, offsetAfter})
        if (_offsetMs(location: location, utcMs: wallMs - offset) == offset) wallMs - offset,
    ];
    // No valid instant means a gap: keep the pre-jump offset, which lands as
    // far past the jump as the wall time was into the gap.
    final utcMs = valid.isEmpty ? wallMs - offsetBefore : valid.reduce(min);
    return DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true);
  }

  int _offsetMs({required tz.Location location, required int utcMs}) => location.timeZone(utcMs).offset.inMilliseconds;
}
