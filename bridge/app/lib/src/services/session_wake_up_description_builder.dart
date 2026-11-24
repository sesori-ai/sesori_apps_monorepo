import "../repositories/models/session_notice.dart";
import "../repositories/models/session_wake_up.dart";
import "scheduled_task_change_description_builder.dart";
import "scheduled_task_occurrence_calculator.dart";

/// A wake-up command that ran: its text, the folder it ran in, and the block
/// that reports its result.
typedef WakeUpCommandRun = ({String command, String workingDirectory, String result});

/// Words for wake-ups, the same in tool results as in the notice a wake-up
/// sends. Times read in the bridge computer's local time with their UTC
/// offset.
///
/// The notice carries the agent's own prompt, so nothing here is logged.
class const SessionWakeUpDescriptionBuilder() {
  /// Calendar schedules read as they do for tasks.
  static const ScheduledTaskChangeDescriptionBuilder _schedules = ScheduledTaskChangeDescriptionBuilder();

  /// How [schedule] repeats, or null for a one-time wake-up.
  String? repeats({required WakeUpSchedule schedule}) {
    return switch (schedule) {
      WakeUpOnce() => null,
      WakeUpEvery(:final minutes) => "every ${_count(count: minutes, unit: "minute")}",
      WakeUpCalendar(:final schedule, :final timeZone) => _schedules.scheduleIn(schedule: schedule, timeZone: timeZone),
    };
  }

  /// [at] in the bridge computer's local time, with its UTC offset.
  String instant({required DateTime at}) {
    final local = at.toLocal();
    final offset = local.timeZoneOffset;
    final offsetMinutes = offset.inMinutes.abs();
    return "${local.year.toString().padLeft(4, "0")}-${_two(value: local.month)}-${_two(value: local.day)} "
        "${_two(value: local.hour)}:${_two(value: local.minute)} "
        "(UTC${offset.isNegative ? "-" : "+"}${_two(value: offsetMinutes ~/ 60)}:${_two(value: offsetMinutes % 60)})";
  }

  /// What [wakeUp] sends when the bridge fires it at [firedAt] for its due
  /// time, with the result of the command it [ran], if any. The user's line
  /// names only its label; the agent also reads when it asked, how late the
  /// wake-up is when the bridge was off, whether it repeats, its prompt, and
  /// the command's result.
  SessionNotice notice({
    required StoredSessionWakeUp wakeUp,
    required DateTime firedAt,
    required WakeUpCommandRun? ran,
  }) {
    final lateBy = firedAt.difference(wakeUp.nextDueAt);
    final repeats = this.repeats(schedule: wakeUp.schedule);
    return SessionNotice(
      summary: "Wake-up: ${wakeUp.label}",
      guidance: [
        "This is the wake-up ${wakeUp.id} you set at ${instant(at: wakeUp.createdAt)}, due at ${instant(at: wakeUp.nextDueAt)}.",
        if (lateBy > ScheduledTaskOccurrenceCalculator.onTimeGrace)
          "It is ${_lateness(late: lateBy)} late: the bridge was off or asleep at its time.",
        if (repeats == null)
          "It does not repeat."
        else
          "It repeats $repeats until you call cancel_wakeup with wakeup_id ${wakeUp.id}, so don't set it again.",
        "Your prompt:",
        wakeUp.prompt,
        if (ran case (:final command, :final workingDirectory, :final result)) ...[
          "",
          "Before this message, Sesori ran your command in $workingDirectory:",
          _fenced(text: command),
          result,
        ],
      ].join("\n"),
      pageRequestId: null,
    );
  }

  String _fenced({required String text}) {
    final marker = ScheduledTaskChangeDescriptionBuilder.fence(text: text);
    return "$marker\n$text\n$marker";
  }

  String _lateness({required Duration late}) {
    if (late.inMinutes < 120) return _count(count: late.inMinutes, unit: "minute");
    if (late.inHours < 48) return _count(count: late.inHours, unit: "hour");
    return _count(count: late.inDays, unit: "day");
  }

  String _count({required int count, required String unit}) => "$count $unit${count == 1 ? "" : "s"}";

  String _two({required int value}) => value.toString().padLeft(2, "0");
}
