import "package:intl/intl.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../l10n/app_localizations.dart";

/// The words the Scheduled page and task page use for schedules, times and
/// run outcomes. Times read in the task zone's wall clock from the bridge's
/// UTC-plus-offset pairs, so the app needs no time-zone database.
class ScheduledTaskFormatter({required final AppLocalizations loc, required final DateTime Function() now}) {
  late final DateFormat _time = DateFormat.jm(loc.localeName);
  late final DateFormat _date = DateFormat.MMMd(loc.localeName);
  late final DateFormat _dateWithYear = DateFormat.yMMMd(loc.localeName);
  late final DateFormat _weekday = DateFormat.E(loc.localeName);

  /// The schedule in a line: "Every day at 9:00 AM", "Mon, Thu at 6:30 PM",
  /// naming the task's zone when it is not this device's.
  String schedule({required ScheduledTask task}) {
    String at(TaskTimeOfDay time) => _inZone(
      task: task,
      text: _timeOfDay(time: time),
    );
    return switch (task.definition.schedule) {
      // A paused one-off task has no instant; its own date and time stand in.
      TaskScheduleOnce(:final at) => switch (task.nextRunAt) {
        final next? => instant(task: task, instant: next),
        null => _localDateTime(at: at),
      },
      TaskScheduleDaily(:final time) => loc.scheduledTaskDaily(at(time)),
      TaskScheduleWeekdays(:final time) => loc.scheduledTaskWeekdays(at(time)),
      TaskScheduleWeekly(:final days, :final time) => loc.scheduledTaskWeekly(_weekdays(days: days), at(time)),
      TaskScheduleEveryHours(:final hours) => loc.scheduledTaskEveryHours(hours),
      TaskScheduleUnknown() => loc.scheduledTaskNewerApp,
    };
  }

  /// When the task runs next, or that it is paused or has nothing left.
  String nextRun({required ScheduledTask task}) => switch (task.nextRunAt) {
    final next? => instant(task: task, instant: next),
    null => task.enabled ? loc.scheduledTaskNoNextRun : loc.scheduledTaskPaused,
  };

  /// [instant] as the task zone's wall clock: "Tomorrow, 9:00 AM", with the
  /// zone added when its offset at that moment differs from this device's.
  String instant({required ScheduledTask task, required ScheduledTaskInstant instant}) {
    final wall = _wallClock(instant: instant);
    final text = loc.scheduledTaskDayAndTime(
      _day(wall: wall, offsetMinutes: instant.offsetMinutes),
      _time.format(wall),
    );
    final deviceOffset = DateTime.fromMillisecondsSinceEpoch(instant.at).timeZoneOffset.inMinutes;
    return instant.offsetMinutes == deviceOffset ? text : loc.scheduledTaskInZone(text, _zoneName(task: task));
  }

  String runOutcome({required ScheduledTaskRunOutcome outcome}) => switch (outcome) {
    ScheduledTaskRunStarted(late: false) => loc.scheduledTaskRunRan,
    ScheduledTaskRunStarted(late: true) => loc.scheduledTaskRunRanLate,
    ScheduledTaskRunSkipped() => loc.scheduledTaskRunSkipped,
    ScheduledTaskRunMissed() => loc.scheduledTaskRunMissed,
    ScheduledTaskRunFailed(:final reason) => loc.scheduledTaskRunFailed(failureReason(reason: reason)),
    ScheduledTaskRunOutcomeUnknown() => loc.scheduledTaskRunUnknown,
  };

  String failureReason({required TaskRunFailureReason reason}) => switch (reason) {
    TaskRunFailureReason.projectMissing => loc.scheduledTaskFailureProjectMissing,
    TaskRunFailureReason.harnessUnavailable => loc.scheduledTaskFailureHarnessUnavailable,
    TaskRunFailureReason.modelUnavailable => loc.scheduledTaskFailureModelUnavailable,
    TaskRunFailureReason.startFailed => loc.scheduledTaskFailureStartFailed,
    TaskRunFailureReason.unknown => loc.scheduledTaskFailureUnknown,
  };

  /// The instant's wall-clock fields, carried in a UTC value so formatting
  /// reads them unchanged.
  DateTime _wallClock({required ScheduledTaskInstant instant}) => DateTime.fromMillisecondsSinceEpoch(
    instant.at + instant.offsetMinutes * Duration.millisecondsPerMinute,
    isUtc: true,
  );

  /// Today, Tomorrow or Yesterday in the task's zone, else the date.
  String _day({required DateTime wall, required int offsetMinutes}) {
    final today = now().toUtc().add(Duration(minutes: offsetMinutes));
    final dayDelta = DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
    ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    return switch (dayDelta) {
      0 => loc.scheduledTaskToday,
      1 => loc.scheduledTaskTomorrow,
      -1 => loc.scheduledTaskYesterday,
      _ => (wall.year == today.year ? _date : _dateWithYear).format(wall),
    };
  }

  /// A wall-clock date and time, its day judged by this device's date.
  String _localDateTime({required TaskLocalDateTime at}) {
    final wall = DateTime.utc(at.year, at.month, at.day, at.hour, at.minute);
    return loc.scheduledTaskDayAndTime(
      _day(wall: wall, offsetMinutes: now().timeZoneOffset.inMinutes),
      _time.format(wall),
    );
  }

  String _timeOfDay({required TaskTimeOfDay time}) => _time.format(DateTime.utc(2000, 1, 1, time.hour, time.minute));

  /// Short weekday names in week order, whatever order the set holds.
  String _weekdays({required Set<TaskWeekday> days}) => [
    for (final day in TaskWeekday.values)
      // 2024-01-01 was a Monday.
      if (days.contains(day)) _weekday.format(DateTime.utc(2024, 1, day.isoWeekday)),
  ].join(", ");

  /// Adds the task's zone to [text] when the zone's offset, read from the next
  /// run, differs from this device's. A task with no next run says nothing.
  String _inZone({required ScheduledTask task, required String text}) {
    final next = task.nextRunAt;
    if (next == null) return text;
    final deviceOffset = DateTime.fromMillisecondsSinceEpoch(next.at).timeZoneOffset.inMinutes;
    return next.offsetMinutes == deviceOffset ? text : loc.scheduledTaskInZone(text, _zoneName(task: task));
  }

  /// The city of an IANA zone name: "Europe/Bucharest" reads "Bucharest",
  /// "America/New_York" reads "New York".
  static String _zoneName({required ScheduledTask task}) =>
      task.definition.timeZone.split("/").last.replaceAll("_", " ");
}
