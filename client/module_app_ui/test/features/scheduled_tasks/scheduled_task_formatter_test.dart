import "package:flutter_test/flutter_test.dart";
import "package:intl/date_symbol_data_local.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/scheduled_tasks/scheduled_task_formatter.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";

void main() {
  setUpAll(() => initializeDateFormatting("en"));

  final now = DateTime(2026, 11, 15, 12);
  final formatter = ScheduledTaskFormatter(loc: AppLocalizationsEn(), now: () => now);
  final at = DateTime(2026, 11, 14, 9).millisecondsSinceEpoch;
  final deviceOffset = DateTime.fromMillisecondsSinceEpoch(at).timeZoneOffset.inMinutes;
  final paused = scheduledTaskFixture(id: "paused", enabled: false);

  test("a paused task that ran in this device's zone names no zone", () {
    final task = paused.copyWith(
      lastRun: ScheduledTaskRun(
        id: "run",
        scheduledFor: ScheduledTaskInstant(at: at, offsetMinutes: deviceOffset),
        outcome: const ScheduledTaskRunOutcome.skipped(),
      ),
    );
    expect(formatter.schedule(task: task, deviceTimeZone: "Europe/Bucharest"), "Every day at 9:00\u202FAM");
  });

  test("a paused task that never ran names its zone unless it is the device's", () {
    expect(formatter.schedule(task: paused, deviceTimeZone: "Europe/Bucharest"), "Every day at 9:00\u202FAM (UTC)");
    expect(formatter.schedule(task: paused, deviceTimeZone: "UTC"), "Every day at 9:00\u202FAM");
    expect(formatter.schedule(task: paused, deviceTimeZone: null), "Every day at 9:00\u202FAM (UTC)");
  });

  test("a paused one-off task writes out its date", () {
    final task = paused.copyWith(
      definition: paused.definition.copyWith(
        schedule: const TaskSchedule.once(
          at: TaskLocalDateTime(year: 2026, month: 11, day: 16, hour: 9, minute: 30),
        ),
      ),
    );
    expect(formatter.schedule(task: task, deviceTimeZone: null), startsWith("Nov 16"));
  });

  test("a new task's When line names no zone, while an edited task in another zone does", () {
    const schedule = TaskSchedule.weekly(
      days: {TaskWeekday.monday, TaskWeekday.friday},
      time: TaskTimeOfDay(hour: 9, minute: 0),
    );
    expect(
      formatter.draftSchedule(schedule: schedule, editing: null, deviceTimeZone: "UTC"),
      "Mon, Fri at 9:00\u202FAM",
    );
    expect(
      formatter.draftSchedule(schedule: schedule, editing: paused, deviceTimeZone: "Europe/Bucharest"),
      "Mon, Fri at 9:00\u202FAM (UTC)",
    );
  });

  test("each weekday reads as its own initial and full name", () {
    expect(TaskWeekday.values.map((day) => formatter.weekdayInitial(day: day)), ["M", "T", "W", "T", "F", "S", "S"]);
    expect(TaskWeekday.values.map((day) => formatter.weekdayName(day: day)), [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ]);
  });
}
