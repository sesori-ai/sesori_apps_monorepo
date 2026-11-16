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
  late final DateFormat _weekdayNarrow = DateFormat.EEEEE(loc.localeName);
  late final DateFormat _weekdayFull = DateFormat.EEEE(loc.localeName);

  /// The schedule in a line: "Every day at 9:00 AM", "Mon, Thu at 6:30 PM",
  /// naming the task's zone when it is not this device's, [deviceTimeZone].
  String schedule({required ScheduledTask task, required String? deviceTimeZone}) =>
      switch ((task.definition.schedule, task.nextRunAt)) {
        // A one-off task reads its instant; a paused one, its own date and time.
        (TaskScheduleOnce(), final next?) => instant(task: task, instant: next),
        (final schedule, _) => draftSchedule(schedule: schedule, editing: task, deviceTimeZone: deviceTimeZone),
      };

  /// The task editor's When line for [schedule], naming the zone of the task
  /// being edited when it is not this device's, [deviceTimeZone]. A new task
  /// is in this device's zone.
  String draftSchedule({
    required TaskSchedule schedule,
    required ScheduledTask? editing,
    required String? deviceTimeZone,
  }) {
    String inZone(String text) => switch (editing) {
      final task? => _inZone(task: task, text: text, deviceTimeZone: deviceTimeZone),
      null => text,
    };
    return switch (schedule) {
      TaskScheduleOnce(:final at) => inZone(localDateTime(at: at)),
      TaskScheduleDaily(:final time) => loc.scheduledTaskDaily(inZone(timeOfDay(time: time))),
      TaskScheduleWeekdays(:final time) => loc.scheduledTaskWeekdays(inZone(timeOfDay(time: time))),
      TaskScheduleWeekly(:final days, :final time) => loc.scheduledTaskWeekly(
        _weekdays(days: days),
        inZone(timeOfDay(time: time)),
      ),
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
    final deviceOffset = DateTime.fromMillisecondsSinceEpoch(instant.at).timeZoneOffset.inMinutes;
    final isDeviceZone = instant.offsetMinutes == deviceOffset;
    final text = loc.scheduledTaskDayAndTime(
      // In this device's zone, today is judged at today's offset, which a DST
      // change before the instant can make differ from the instant's own.
      // ponytail: a remote zone across its DST change can still be a day off
      // within an hour of midnight; the bridge would need to send the zone's
      // current offset to fix that.
      _day(wall: wall, offsetMinutes: isDeviceZone ? now().timeZoneOffset.inMinutes : instant.offsetMinutes),
      _time.format(wall),
    );
    return isDeviceZone ? text : loc.scheduledTaskInZone(text, _zoneName(task: task));
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

  /// A wall-clock date and time with no known offset, so its date is written
  /// out rather than judged against today.
  String localDateTime({required TaskLocalDateTime at}) {
    final wall = DateTime.utc(at.year, at.month, at.day, at.hour, at.minute);
    return loc.scheduledTaskDayAndTime(
      (wall.year == now().year ? _date : _dateWithYear).format(wall),
      _time.format(wall),
    );
  }

  String timeOfDay({required TaskTimeOfDay time}) => _time.format(DateTime.utc(2000, 1, 1, time.hour, time.minute));

  /// Short weekday names in week order, whatever order the set holds.
  String _weekdays({required Set<TaskWeekday> days}) => [
    for (final day in TaskWeekday.values)
      if (days.contains(day)) weekday(day: day),
  ].join(", ");

  /// [day]'s short name, such as "Mon".
  // 2024-01-01 was a Monday.
  String weekday({required TaskWeekday day}) => _weekday.format(DateTime.utc(2024, 1, day.isoWeekday));

  /// [day]'s initial, for a row of all seven.
  String weekdayInitial({required TaskWeekday day}) => _weekdayNarrow.format(DateTime.utc(2024, 1, day.isoWeekday));

  /// [day]'s full name, read out for its initial.
  String weekdayName({required TaskWeekday day}) => _weekdayFull.format(DateTime.utc(2024, 1, day.isoWeekday));

  /// Adds the task's zone to [text] when the zone's offset, read from the next
  /// or else the last run, differs from this device's. A paused task that
  /// never ran has no offset to compare, so it names its zone unless the zone
  /// is [deviceTimeZone] itself, which has this device's offset now.
  String _inZone({required ScheduledTask task, required String text, required String? deviceTimeZone}) {
    final isDeviceZone = switch (task.nextRunAt ?? task.lastRun?.scheduledFor) {
      final known? => known.offsetMinutes == DateTime.fromMillisecondsSinceEpoch(known.at).timeZoneOffset.inMinutes,
      null => task.definition.timeZone == deviceTimeZone,
    };
    return isDeviceZone ? text : loc.scheduledTaskInZone(text, _zoneName(task: task));
  }

  /// The city of an IANA zone name: "Europe/Bucharest" reads "Bucharest",
  /// "America/New_York" reads "New York".
  static String _zoneName({required ScheduledTask task}) =>
      task.definition.timeZone.split("/").last.replaceAll("_", " ");
}
