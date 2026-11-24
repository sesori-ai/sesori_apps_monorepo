import "../repositories/models/agent_approval_change.dart";
import "../repositories/models/session_notice.dart";
import "../repositories/models/session_wake_up.dart";
import "scheduled_task_change_description_builder.dart";
import "session_wake_up_description_builder.dart";

/// Writes the Markdown a user reads before allowing a wake-up's command, and
/// the notice its session gets once they answered.
///
/// The command comes first and verbatim, then where it runs, when, and the
/// wake-up's label; agent-written text is escaped, so it cannot fake a line.
class const WakeUpCommandDescriptionBuilder() {
  static const SessionWakeUpDescriptionBuilder _wakeUpWords = SessionWakeUpDescriptionBuilder();
  static const ScheduledTaskChangeDescriptionBuilder _taskWords = ScheduledTaskChangeDescriptionBuilder();

  /// The request for [change], whose command runs in [workingDirectory].
  String build({required WakeUpCommandChange change, required String workingDirectory}) {
    final (:command, :label, :timing, :closing) = switch (change) {
      ScheduleCommandWakeUp(:final command, :final label) => (
        command: command,
        label: label,
        timing: _requested(change: change),
        closing: "Allow sets the wake-up. Its command then runs at every time without asking again.",
      ),
      ConfirmByModeCommand(:final wakeUp, :final command) => (
        command: command,
        label: wakeUp.label,
        timing: _wakeUpWords.repeats(schedule: wakeUp.schedule) ?? "once",
        closing:
            "The wake-up was set while this session approved everything, and it no longer does. Allow runs "
            "the command now and at later times without asking again; Reject cancels the wake-up.",
      ),
    };
    return [
      "**A wake-up runs this command**",
      ...ScheduledTaskChangeDescriptionBuilder.commandBlock(command: command),
      "Runs in: ${ScheduledTaskChangeDescriptionBuilder.inline(text: workingDirectory)}",
      "When: ${ScheduledTaskChangeDescriptionBuilder.inline(text: timing)}",
      "Wake-up: ${ScheduledTaskChangeDescriptionBuilder.quoted(text: label)}",
      closing,
    ].join("\n\n");
  }

  /// What the session hears once the user answered a new command wake-up:
  /// [scheduled] is the stored wake-up after an Allow, null after a Reject or
  /// when its session is gone.
  SessionNotice scheduleOutcome({required ScheduleCommandWakeUp change, required StoredSessionWakeUp? scheduled}) {
    final name = ScheduledTaskChangeDescriptionBuilder.quoted(text: change.label);
    final (summary, guidance) = switch (scheduled) {
      final wakeUp? => (
        "You allowed the wake-up $name and its command.",
        "Wake-up ${wakeUp.id} is set for ${_wakeUpWords.instant(at: wakeUp.nextDueAt)}.",
      ),
      null => (
        "You didn’t allow the wake-up $name.",
        "Nothing was set. Don't set it again unless they ask.",
      ),
    };
    return SessionNotice(summary: summary, guidance: "$guidance Reply in one short line.", pageRequestId: null);
  }

  /// What the session hears when the user rejected [wakeUp]'s command at its
  /// time: the wake-up is cancelled.
  SessionNotice confirmRejected({required StoredSessionWakeUp wakeUp}) {
    return SessionNotice(
      summary:
          "You didn’t allow the wake-up ${ScheduledTaskChangeDescriptionBuilder.quoted(text: wakeUp.label)} "
          "to run its command, so it is cancelled.",
      guidance:
          "This session no longer approves everything, so the user was asked before wake-up ${wakeUp.id} ran its "
          "command. Don't set it again unless they ask. Reply in one short line.",
      pageRequestId: null,
    );
  }

  String _requested({required ScheduleCommandWakeUp change}) {
    return switch (change.when) {
      WakeUpInMinutes(:final minutes) => "once, ${_minutes(count: minutes)} after you allow it",
      WakeUpEveryMinutes(:final minutes) => "every ${_minutes(count: minutes)}, the first after you allow it",
      WakeUpOnSchedule(:final schedule) => _taskWords.scheduleIn(
        schedule: schedule,
        timeZone: change.timeZone ?? "this computer's time zone",
      ),
    };
  }

  String _minutes({required int count}) => "$count minute${count == 1 ? "" : "s"}";
}
