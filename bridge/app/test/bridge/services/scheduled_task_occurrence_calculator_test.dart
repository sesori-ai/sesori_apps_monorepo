import "package:sesori_bridge/src/services/scheduled_task_occurrence_calculator.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";
import "package:timezone/data/latest_all.dart" as tz_data;
import "package:timezone/timezone.dart" as tz;

void main() {
  const calculator = ScheduledTaskOccurrenceCalculator();

  setUpAll(tz_data.initializeTimeZones);

  DateTime utc(String iso) => DateTime.parse(iso);

  TaskTimeOfDay at(int hour, int minute) => TaskTimeOfDay(hour: hour, minute: minute);

  TaskLocalDateTime local(int year, int month, int day, int hour, int minute) =>
      TaskLocalDateTime(year: year, month: month, day: day, hour: hour, minute: minute);

  DateTime? first(TaskSchedule schedule, String zone, String now) =>
      calculator.firstDueAt(schedule: schedule, timeZone: zone, now: utc(now));

  DateTime? next(TaskSchedule schedule, String zone, String now) =>
      calculator.nextDueAfterRun(schedule: schedule, timeZone: zone, now: utc(now));

  group("time zones", () {
    test("knows canonical and legacy link names and refuses others", () {
      expect(calculator.isKnownTimeZone(timeZone: "Europe/Bucharest"), isTrue);
      expect(calculator.isKnownTimeZone(timeZone: "Asia/Calcutta"), isTrue);
      expect(calculator.isKnownTimeZone(timeZone: "UTC"), isTrue);
      expect(calculator.isKnownTimeZone(timeZone: "Mars/Olympus_Mons"), isFalse);
    });

    test("an unknown zone throws instead of guessing", () {
      expect(
        () => first(TaskSchedule.daily(time: at(9, 0)), "Mars/Olympus_Mons", "2026-11-15T00:00:00Z"),
        throwsA(isA<tz.LocationNotFoundException>()),
      );
    });

    test("reports the zone's offset at the instant", () {
      expect(calculator.offsetMinutesAt(instant: utc("2026-07-01T12:00:00Z"), timeZone: "Europe/Bucharest"), 180);
      expect(calculator.offsetMinutesAt(instant: utc("2026-01-01T12:00:00Z"), timeZone: "Europe/Bucharest"), 120);
      expect(calculator.offsetMinutesAt(instant: utc("2026-01-01T12:00:00Z"), timeZone: "Asia/Kolkata"), 330);
      expect(calculator.offsetMinutesAt(instant: utc("2026-01-01T12:00:00Z"), timeZone: "America/New_York"), -300);
    });

    test("computes in the task's zone, not the host's", () {
      final schedule = TaskSchedule.daily(time: at(9, 0));
      expect(first(schedule, "Asia/Kolkata", "2026-11-15T00:00:00Z"), utc("2026-11-15T03:30:00Z"));
      expect(first(schedule, "America/Los_Angeles", "2026-11-15T00:00:00Z"), utc("2026-11-15T17:00:00Z"));
      expect(first(schedule, "Pacific/Auckland", "2026-11-15T00:00:00Z"), utc("2026-11-15T20:00:00Z"));
    });
  });

  group("once", () {
    final schedule = TaskSchedule.once(at: local(2026, 7, 1, 9, 0));

    test("falls due at its own instant", () {
      expect(first(schedule, "Europe/Bucharest", "2026-06-01T00:00:00Z"), utc("2026-07-01T06:00:00Z"));
    });

    test("keeps its instant once it has passed, so it still runs when the bridge is back", () {
      expect(first(schedule, "Europe/Bucharest", "2026-07-03T00:00:00Z"), utc("2026-07-01T06:00:00Z"));
    });

    test("has nothing left after it runs", () {
      expect(next(schedule, "Europe/Bucharest", "2026-07-01T06:00:05Z"), isNull);
    });
  });

  group("daily", () {
    final schedule = TaskSchedule.daily(time: at(9, 0));

    test("runs today when the time is still ahead", () {
      expect(first(schedule, "Europe/Bucharest", "2026-11-15T06:00:00Z"), utc("2026-11-15T07:00:00Z"));
    });

    test("runs tomorrow when the time has passed", () {
      expect(first(schedule, "Europe/Bucharest", "2026-11-15T08:00:00Z"), utc("2026-11-16T07:00:00Z"));
    });

    test("the next time is strictly after now", () {
      expect(next(schedule, "Europe/Bucharest", "2026-11-15T07:00:00Z"), utc("2026-11-16T07:00:00Z"));
    });

    test("keeps its local time across a daylight-saving change", () {
      expect(next(schedule, "Europe/Bucharest", "2026-03-28T07:00:00Z"), utc("2026-03-29T06:00:00Z"));
      expect(next(schedule, "Europe/Bucharest", "2026-10-24T06:00:00Z"), utc("2026-10-25T07:00:00Z"));
    });

    test("keeps its local time across a southern-hemisphere change", () {
      // Sydney leaves daylight saving (+11 to +10) on 2026-04-05.
      expect(next(schedule, "Australia/Sydney", "2026-04-03T22:00:00Z"), utc("2026-04-04T23:00:00Z"));
    });

    test("a week away yields one next time, not a backlog", () {
      expect(next(schedule, "Europe/Bucharest", "2026-11-22T10:00:00Z"), utc("2026-11-23T07:00:00Z"));
    });
  });

  group("daylight-saving gap", () {
    test("a missing local time runs as far past the jump as it was into the gap", () {
      // New York jumps from 02:00 EST to 03:00 EDT on 2026-03-08, so 02:30 runs at 03:30 EDT.
      final schedule = TaskSchedule.daily(time: at(2, 30));
      expect(next(schedule, "America/New_York", "2026-03-07T12:00:00Z"), utc("2026-03-08T07:30:00Z"));
      // The day after, 02:30 exists again.
      expect(next(schedule, "America/New_York", "2026-03-08T07:30:00Z"), utc("2026-03-09T06:30:00Z"));
    });

    test("a European gap at 03:00 moves 03:30 to 04:30", () {
      final schedule = TaskSchedule.daily(time: at(3, 30));
      expect(next(schedule, "Europe/Bucharest", "2026-03-28T12:00:00Z"), utc("2026-03-29T01:30:00Z"));
      expect(calculator.offsetMinutesAt(instant: utc("2026-03-29T01:30:00Z"), timeZone: "Europe/Bucharest"), 180);
    });

    test("a half-hour jump moves the time by half an hour", () {
      // Lord Howe Island jumps from 02:00 (+10:30) to 02:30 (+11) on 2026-10-04.
      final schedule = TaskSchedule.daily(time: at(2, 15));
      expect(next(schedule, "Australia/Lord_Howe", "2026-10-03T00:00:00Z"), utc("2026-10-03T15:45:00Z"));
    });

    test("a one-off time in the gap resolves the same way", () {
      final schedule = TaskSchedule.once(at: local(2026, 3, 8, 2, 30));
      expect(first(schedule, "America/New_York", "2026-03-01T00:00:00Z"), utc("2026-03-08T07:30:00Z"));
    });
  });

  group("daylight-saving overlap", () {
    // New York falls back from 02:00 EDT to 01:00 EST on 2026-11-01, so 01:30 happens twice.
    final schedule = TaskSchedule.daily(time: at(1, 30));

    test("a repeated local time runs at its first instant", () {
      expect(next(schedule, "America/New_York", "2026-10-31T12:00:00Z"), utc("2026-11-01T05:30:00Z"));
    });

    test("it runs once: the second 01:30 is not another occurrence", () {
      expect(next(schedule, "America/New_York", "2026-11-01T05:30:00Z"), utc("2026-11-02T06:30:00Z"));
    });

    test("a European overlap at 04:00 runs 03:30 in summer time", () {
      final european = TaskSchedule.daily(time: at(3, 30));
      expect(next(european, "Europe/Bucharest", "2026-10-24T12:00:00Z"), utc("2026-10-25T00:30:00Z"));
    });
  });

  group("weekdays", () {
    final schedule = TaskSchedule.weekdays(time: at(9, 0));

    test("skips from Friday evening to Monday", () {
      // 2026-11-13 is a Friday.
      expect(next(schedule, "Europe/Bucharest", "2026-11-13T12:00:00Z"), utc("2026-11-16T07:00:00Z"));
    });

    test("skips the weekend when saved on a Saturday", () {
      expect(first(schedule, "Europe/Bucharest", "2026-11-14T05:00:00Z"), utc("2026-11-16T07:00:00Z"));
    });

    test("uses the date in the task's zone, not in UTC", () {
      // 02:00 UTC on Saturday 2026-11-14 is still Friday 21:00 in New York.
      expect(
        next(TaskSchedule.weekdays(time: at(22, 0)), "America/New_York", "2026-11-14T02:00:00Z"),
        utc("2026-11-14T03:00:00Z"),
      );
    });
  });

  group("weekly", () {
    test("runs on the next chosen day", () {
      final schedule = TaskSchedule.weekly(days: {TaskWeekday.tuesday, TaskWeekday.thursday}, time: at(9, 0));
      // 2026-11-17 is a Tuesday.
      expect(next(schedule, "Europe/Bucharest", "2026-11-17T07:00:00Z"), utc("2026-11-19T07:00:00Z"));
      expect(next(schedule, "Europe/Bucharest", "2026-11-19T07:00:00Z"), utc("2026-11-24T07:00:00Z"));
    });

    test("a single day whose time passed today is a week out", () {
      final schedule = TaskSchedule.weekly(days: {TaskWeekday.sunday}, time: at(9, 0));
      // 2026-11-15 is a Sunday.
      expect(next(schedule, "Europe/Bucharest", "2026-11-15T07:00:00Z"), utc("2026-11-22T07:00:00Z"));
    });

    test("a single day later today runs today", () {
      final schedule = TaskSchedule.weekly(days: {TaskWeekday.sunday}, time: at(21, 0));
      expect(next(schedule, "Europe/Bucharest", "2026-11-15T07:00:00Z"), utc("2026-11-15T19:00:00Z"));
    });

    test("no days never falls due", () {
      final schedule = TaskSchedule.weekly(days: const {}, time: at(9, 0));
      expect(first(schedule, "Europe/Bucharest", "2026-11-15T07:00:00Z"), isNull);
    });
  });

  group("every few hours", () {
    final schedule = TaskSchedule.everyHours(hours: 3, start: local(2026, 11, 15, 8, 0));

    test("waits for a start that is still ahead", () {
      expect(first(schedule, "Europe/Bucharest", "2026-11-15T05:00:00Z"), utc("2026-11-15T06:00:00Z"));
    });

    test("steps whole intervals from the start, strictly after now", () {
      expect(next(schedule, "Europe/Bucharest", "2026-11-15T06:00:00Z"), utc("2026-11-15T09:00:00Z"));
      expect(next(schedule, "Europe/Bucharest", "2026-11-15T13:00:00Z"), utc("2026-11-15T15:00:00Z"));
      expect(first(schedule, "Europe/Bucharest", "2026-11-15T13:00:00Z"), utc("2026-11-15T15:00:00Z"));
    });

    test("a long gap yields the next interval, not a backlog", () {
      expect(next(schedule, "Europe/Bucharest", "2026-11-22T10:30:00Z"), utc("2026-11-22T12:00:00Z"));
    });

    test("stays a fixed real-time interval across daylight saving", () {
      // Starts 22:00 EST on 2026-03-07; New York jumps an hour at 07:00 UTC on 2026-03-08.
      final interval = TaskSchedule.everyHours(hours: 6, start: local(2026, 3, 7, 22, 0));
      expect(next(interval, "America/New_York", "2026-03-08T03:00:00Z"), utc("2026-03-08T09:00:00Z"));
      // The local time moves from 04:00 to 05:00 instead of the interval shrinking.
      expect(calculator.offsetMinutesAt(instant: utc("2026-03-08T09:00:00Z"), timeZone: "America/New_York"), -240);
    });

    test("drifts across days when 24 is not a multiple of the interval", () {
      final interval = TaskSchedule.everyHours(hours: 5, start: local(2026, 11, 15, 0, 0));
      // Starts 00:00 UTC; 25 hours later is 01:00 the next day.
      expect(next(interval, "UTC", "2026-11-15T21:00:00Z"), utc("2026-11-16T01:00:00Z"));
    });
  });

  test("an unknown schedule never falls due", () {
    expect(first(const TaskSchedule.unknown(), "Europe/Bucharest", "2026-11-15T00:00:00Z"), isNull);
    expect(next(const TaskSchedule.unknown(), "Europe/Bucharest", "2026-11-15T00:00:00Z"), isNull);
  });

  group("due action", () {
    final dueAt = utc("2026-11-16T07:00:00Z");
    final daily = TaskSchedule.daily(time: at(9, 0));
    final once = TaskSchedule.once(at: local(2026, 11, 16, 9, 0));

    ScheduledTaskDueAction action(TaskSchedule schedule, TaskMissedRunPolicy policy, Duration seenAfter) =>
        calculator.dueAction(schedule: schedule, missedRunPolicy: policy, dueAt: dueAt, now: dueAt.add(seenAfter));

    test("within the grace is on time, whatever the policy", () {
      for (final policy in TaskMissedRunPolicy.values) {
        expect(action(daily, policy, Duration.zero), ScheduledTaskDueAction.fireOnTime);
        expect(action(daily, policy, const Duration(minutes: 2)), ScheduledTaskDueAction.fireOnTime);
      }
    });

    test("past the grace, run when back fires once, late", () {
      expect(
        action(daily, TaskMissedRunPolicy.runWhenBack, const Duration(minutes: 2, seconds: 1)),
        ScheduledTaskDueAction.fireLate,
      );
      expect(action(daily, TaskMissedRunPolicy.runWhenBack, const Duration(days: 7)), ScheduledTaskDueAction.fireLate);
    });

    test("past the grace, wait for the next time records one missed run", () {
      expect(
        action(daily, TaskMissedRunPolicy.waitForNext, const Duration(minutes: 3)),
        ScheduledTaskDueAction.recordMissed,
      );
    });

    test("a one-off task always runs when back", () {
      expect(action(once, TaskMissedRunPolicy.waitForNext, const Duration(hours: 5)), ScheduledTaskDueAction.fireLate);
    });

    test("an unknown policy reads as run when back", () {
      expect(action(daily, TaskMissedRunPolicy.unknown, const Duration(hours: 1)), ScheduledTaskDueAction.fireLate);
    });
  });
}
