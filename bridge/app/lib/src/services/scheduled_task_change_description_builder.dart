import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/scheduled_task_agent_change.dart";

/// Writes the Markdown a user reads before allowing an agent's task change.
///
/// The security model relies on this text: it opens with the Approve
/// everything warning whenever the task keeps running and acts without
/// asking, and names the project before the action. Agent-written names and
/// titles are escaped, so they cannot fake a line.
class const ScheduledTaskChangeDescriptionBuilder() {
  String build({
    required ScheduledTaskAgentChange change,
    required String projectName,
    required AgentRequester requester,
  }) {
    // Pausing stops the runs, so it needs no warning.
    final pauses = change is SetTaskEnabledChange && !change.enabled;
    final approvesEverything = !pauses && change.before.approvalMode == TaskApprovalMode.approveAll;
    return [
      if (approvesEverything) "**Approve everything: this task's runs act without asking you.**",
      "Project: ${_inline(text: projectName)}",
      ..._body(change: change),
      switch (requester) {
        RequestedByOwnRun() => "Asked by a scheduled run of this task.",
        RequestedByTaskRun(:final taskName) => "Asked by a scheduled run of task ${_quoted(text: taskName)}.",
        RequestedFromSession(:final title?) => "Asked from session ${_quoted(text: title)}.",
        RequestedFromSession(title: null) => "Asked from an untitled session.",
      },
    ].join("\n\n");
  }

  /// The schedule in plain words, with its time zone.
  String schedule({required ScheduledTaskDefinition definition}) {
    final schedule = switch (definition.schedule) {
      TaskScheduleOnce(:final at) => "once at ${_localDateTime(at: at)}",
      TaskScheduleDaily(:final time) => "daily at ${_time(time: time)}",
      TaskScheduleWeekdays(:final time) => "Monday to Friday at ${_time(time: time)}",
      TaskScheduleWeekly(:final days, :final time) =>
        "weekly on ${(days.toList()..sort((a, b) => a.isoWeekday.compareTo(b.isoWeekday))).map((day) => day.name).join(", ")} at ${_time(time: time)}",
      TaskScheduleEveryHours(:final hours, :final start) => "every $hours hours from ${_localDateTime(at: start)}",
      TaskScheduleUnknown() => "a schedule this bridge does not know",
    };
    return "$schedule (${definition.timeZone})";
  }

  List<String> _body({required ScheduledTaskAgentChange change}) {
    switch (change) {
      case SetTaskEnabledChange(:final before, enabled: true):
        return ["**Resume ${_quoted(text: before.name)}**", "Schedule: ${_inline(text: schedule(definition: before))}"];
      case SetTaskEnabledChange(:final before, enabled: false):
        return ["**Pause ${_quoted(text: before.name)}**"];
      case RunTaskNowChange(:final before):
        return ["**Run ${_quoted(text: before.name)} now**"];
    }
  }

  String _quoted({required String text}) => "“${_inline(text: text)}”";

  /// [text] on one line with Markdown syntax escaped.
  String _inline({required String text}) {
    return text
        .replaceAll(RegExp(r"\s+"), " ")
        .trim()
        .replaceAllMapped(RegExp(r"[\\`*_\[\]<>~|#!]"), (match) => "\\${match[0]}");
  }

  String _localDateTime({required TaskLocalDateTime at}) =>
      "${at.year.toString().padLeft(4, "0")}-${_two(value: at.month)}-${_two(value: at.day)} "
      "${_two(value: at.hour)}:${_two(value: at.minute)}";

  String _time({required TaskTimeOfDay time}) => "${_two(value: time.hour)}:${_two(value: time.minute)}";

  String _two({required int value}) => value.toString().padLeft(2, "0");
}

/// Who proposed a change, as the request's last line names them.
sealed class const AgentRequester();

/// A scheduled run of the task the change is about.
final class const RequestedByOwnRun() extends AgentRequester;

/// A scheduled run of another task.
final class const RequestedByTaskRun({required final String taskName}) extends AgentRequester;

/// An ordinary session; [title] is null while it has none.
final class const RequestedFromSession({required final String? title}) extends AgentRequester;
