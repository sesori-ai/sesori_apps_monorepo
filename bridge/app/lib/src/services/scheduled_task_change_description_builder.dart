import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/agent_approval_outcome.dart";
import "../repositories/models/scheduled_task_agent_change.dart";
import "../repositories/models/session_notice.dart";

/// Writes the Markdown a user reads before allowing an agent's task change,
/// and the notice its session gets once they answered.
///
/// The security model relies on this text: it opens with the Approve
/// everything warning whenever the resulting task acts without asking, names
/// the project before the action, and shows every field the change sets.
/// Agent-written names and prompts are escaped, so they cannot fake a line.
class const ScheduledTaskChangeDescriptionBuilder() {
  String build({
    required ScheduledTaskAgentChange change,
    required String projectName,
    required AgentRequester requester,
  }) {
    final (:approvesEverything, :turnsOnApproveEverything) = switch (change) {
      CreateTaskChange(:final definition) => (
        approvesEverything: definition.approvalMode == TaskApprovalMode.approveAll,
        turnsOnApproveEverything: false,
      ),
      UpdateTaskChange(:final before, :final after) => (
        approvesEverything: after.approvalMode == TaskApprovalMode.approveAll,
        turnsOnApproveEverything:
            after.approvalMode == TaskApprovalMode.approveAll && before.approvalMode != TaskApprovalMode.approveAll,
      ),
      SetTaskEnabledChange(:final before, :final enabled) => (
        approvesEverything: enabled && before.approvalMode == TaskApprovalMode.approveAll,
        turnsOnApproveEverything: false,
      ),
      RunTaskNowChange(:final before) => (
        approvesEverything: before.approvalMode == TaskApprovalMode.approveAll,
        turnsOnApproveEverything: false,
      ),
    };
    return [
      if (turnsOnApproveEverything)
        "**Turns on Approve everything: this task's runs will act without asking you.**"
      else if (approvesEverything)
        "**Approve everything: this task's runs act without asking you.**",
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

  /// What the session that asked for [change] is told once the user answered:
  /// a short line for the user and the agent's guidance. [bySubagent] means a
  /// sub-agent asked, so the notice lands on its root session.
  SessionNotice outcome({
    required ScheduledTaskAgentChange change,
    required AgentApprovalOutcome outcome,
    required bool bySubagent,
  }) {
    final (action, name) = switch (change) {
      CreateTaskChange(:final definition) => ("creating", definition.name),
      UpdateTaskChange(:final before, :final after) when before.copyWith(name: after.name) == after => (
        "renaming",
        before.name,
      ),
      UpdateTaskChange(:final before) => ("changing", before.name),
      SetTaskEnabledChange(:final before, enabled: true) => ("resuming", before.name),
      SetTaskEnabledChange(:final before, enabled: false) => ("pausing", before.name),
      RunTaskNowChange(:final before) => ("running", before.name),
    };
    final request = "$action ${_quoted(text: name)}${change is RunTaskNowChange ? " now" : ""}";
    final (summary, guidance) = switch (outcome) {
      AgentApprovalCreated(:final taskId) => (
        "You allowed $request.",
        "The change is saved and applies from the next run. The new task's id is $taskId.",
      ),
      AgentApprovalApplied() => (
        "You allowed $request.",
        switch (change) {
          RunTaskNowChange() => "The run started.",
          SetTaskEnabledChange(enabled: false) => "The change is saved.",
          CreateTaskChange() ||
          UpdateTaskChange() ||
          SetTaskEnabledChange() => "The change is saved and applies from the next run.",
        },
      ),
      AgentApprovalStale() => (
        "You allowed $request, but it had changed since, so nothing was applied.",
        "Read it with get_task before proposing anything else.",
      ),
      AgentApprovalRunNotStarted(outcome: final run) => (
        "You allowed $request, but it didn’t start.",
        "${_notStartedReason(outcome: run)}.",
      ),
      AgentApprovalRejected() => (
        "You didn’t allow $request.",
        "Nothing changed. Don't propose it again unless they ask.",
      ),
    };
    return SessionNotice(
      summary: summary,
      guidance: [
        if (bySubagent) "A sub-agent of this session made this request.",
        guidance,
        "Reply in one short line.",
      ].join(" "),
      pageRequestId: null,
    );
  }

  String _notStartedReason({required ScheduledTaskRunOutcome outcome}) => switch (outcome) {
    ScheduledTaskRunSkipped() => "The previous run was still going",
    ScheduledTaskRunMissed() => "The bridge was off or asleep",
    ScheduledTaskRunFailed(reason: TaskRunFailureReason.projectMissing) => "The project folder is missing",
    ScheduledTaskRunFailed(reason: TaskRunFailureReason.harnessUnavailable) => "The harness is unavailable",
    ScheduledTaskRunFailed(reason: TaskRunFailureReason.modelUnavailable) => "The task's model is no longer offered",
    ScheduledTaskRunFailed(reason: TaskRunFailureReason.startFailed) => "The session failed to start",
    ScheduledTaskRunFailed(reason: TaskRunFailureReason.unknown) ||
    ScheduledTaskRunStarted() ||
    ScheduledTaskRunOutcomeUnknown() => "Its run history shows why",
  };

  /// The schedule in plain words, with its time zone.
  String schedule({required ScheduledTaskDefinition definition}) =>
      scheduleIn(schedule: definition.schedule, timeZone: definition.timeZone);

  /// [schedule] in plain words, with [timeZone].
  String scheduleIn({required TaskSchedule schedule, required String timeZone}) {
    final words = switch (schedule) {
      TaskScheduleOnce(:final at) => "once at ${_localDateTime(at: at)}",
      TaskScheduleDaily(:final time) => "daily at ${_time(time: time)}",
      TaskScheduleWeekdays(:final time) => "Monday to Friday at ${_time(time: time)}",
      TaskScheduleWeekly(:final days, :final time) =>
        "weekly on ${(days.toList()..sort((a, b) => a.isoWeekday.compareTo(b.isoWeekday))).map((day) => day.name).join(", ")} at ${_time(time: time)}",
      TaskScheduleEveryHours(:final hours, :final start) => "every $hours hours from ${_localDateTime(at: start)}",
      TaskScheduleUnknown() => "a schedule this bridge does not know",
    };
    return "$words ($timeZone)";
  }

  List<String> _body({required ScheduledTaskAgentChange change}) {
    switch (change) {
      case CreateTaskChange(:final definition):
        return [
          "**Create ${_quoted(text: definition.name)}**",
          for (final field in _Field.values)
            if (field != _Field.name)
              "${field.label}: ${_inline(
                text: _value(field: field, definition: definition),
              )}",
          ..._prompt(label: "Prompt", prompt: definition.prompt),
        ];
      case UpdateTaskChange(:final before, :final after):
        return [
          "**Update ${_quoted(text: before.name)}**",
          for (final field in _Field.values)
            if (_value(field: field, definition: before) case final old
                when old != _value(field: field, definition: after))
              "${field.label}: ${_inline(text: old)} → ${_inline(
                text: _value(field: field, definition: after),
              )}",
          if (before.prompt != after.prompt) ..._prompt(label: "New prompt", prompt: after.prompt),
        ];
      case SetTaskEnabledChange(:final before, enabled: true):
        return ["**Resume ${_quoted(text: before.name)}**", "Schedule: ${_inline(text: schedule(definition: before))}"];
      case SetTaskEnabledChange(:final before, enabled: false):
        return ["**Pause ${_quoted(text: before.name)}**"];
      case RunTaskNowChange(:final before):
        return ["**Run ${_quoted(text: before.name)} now**"];
    }
  }

  String _value({required _Field field, required ScheduledTaskDefinition definition}) {
    return switch (field) {
      _Field.approvalMode => switch (definition.approvalMode) {
        TaskApprovalMode.ask => "Ask",
        TaskApprovalMode.approveAll => "Approve everything",
        TaskApprovalMode.unknown => "Unknown",
      },
      _Field.schedule => schedule(definition: definition),
      _Field.model => switch (definition.model) {
        PromptModel(:final providerID, :final modelID) => "$providerID/$modelID",
        null => "Harness default",
      },
      _Field.effort => definition.variant?.id ?? "Harness default",
      _Field.name => definition.name,
      _Field.missedRunPolicy => switch (definition.missedRunPolicy) {
        TaskMissedRunPolicy.runWhenBack => "Run once when the bridge is back",
        TaskMissedRunPolicy.waitForNext => "Wait for the next time",
        TaskMissedRunPolicy.unknown => "Unknown",
      },
      _Field.runMode => switch (definition.runMode) {
        TaskRunModeNewSession() => "A new session each run",
        TaskRunModeSameSession(autoCompact: false) => "One session for every run",
        TaskRunModeSameSession(autoCompact: true) => "One session for every run, compacted before each run",
        TaskRunModeUnknown() => "Unknown",
      },
      _Field.harness => definition.pluginId,
      _Field.agent => definition.agent ?? "Harness default",
      _Field.fastMode => definition.fastMode ? "On" : "Off",
      _Field.worktree => definition.dedicatedWorktree ? "A new worktree each run" : "The project folder",
      _Field.projectId => definition.projectId,
    };
  }

  List<String> _prompt({required String label, required ScheduledTaskPrompt prompt}) {
    final text = switch (prompt) {
      ScheduledTaskPromptText(:final text) => text,
      ScheduledTaskPromptCommand(:final name, :final arguments) => "/$name${arguments == null ? "" : " $arguments"}",
      ScheduledTaskPromptUnknown() => "(a prompt kind this bridge does not know)",
    };
    // A fence longer than any backtick run inside keeps the prompt verbatim.
    final longestRun = RegExp("`+").allMatches(text).fold(0, (longest, match) {
      final length = match.end - match.start;
      return length > longest ? length : longest;
    });
    final fence = "`" * (longestRun < 3 ? 3 : longestRun + 1);
    return ["$label:", "$fence\n$text\n$fence"];
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

/// The definition fields a request lists, in the order it lists them: the
/// ones that decide what a run may do first.
enum _Field({required final String label}) {
  approvalMode(label: "Permissions"),
  schedule(label: "Schedule"),
  model(label: "Model"),
  effort(label: "Effort"),
  name(label: "Name"),
  missedRunPolicy(label: "When a run is missed"),
  runMode(label: "Runs in"),
  harness(label: "Harness"),
  agent(label: "Agent"),
  fastMode(label: "Fast mode"),
  worktree(label: "Works in"),
  projectId(label: "Project folder"),
}

/// Who proposed a change, as the request's last line names them.
sealed class const AgentRequester();

/// A scheduled run of the task the change is about.
final class const RequestedByOwnRun() extends AgentRequester;

/// A scheduled run of another task.
final class const RequestedByTaskRun({required final String taskName}) extends AgentRequester;

/// An ordinary session; [title] is null while it has none.
final class const RequestedFromSession({required final String? title}) extends AgentRequester;
