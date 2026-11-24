import "package:sesori_shared/sesori_shared.dart";

import "../../repositories/models/session_wake_up.dart";
import "../../services/scheduled_task_agent_service.dart";
import "../../services/scheduled_task_change_description_builder.dart";
import "../../services/session_wake_up_description_builder.dart";

/// Renders tool results as the plain text agents read.
///
/// Results carry user prompts and transcripts, so nothing here is ever logged.
class const SesoriMcpResultFormatter() {
  /// Roughly how much transcript one page holds.
  static const int transcriptPageChars = 20000;
  static const int _replyExcerptChars = 500;
  static const int _toolResultChars = 300;

  /// Schedules read the same in results as in approval requests.
  static const ScheduledTaskChangeDescriptionBuilder _descriptions = ScheduledTaskChangeDescriptionBuilder();

  /// Wake-ups read the same in results as in the notice they send.
  static const SessionWakeUpDescriptionBuilder _wakeUpWords = SessionWakeUpDescriptionBuilder();

  String taskList({required AgentTaskList list}) {
    if (list.tasks.isEmpty) return "No scheduled tasks.";
    return [
      for (final task in list.tasks)
        [
          "- ${task.definition.name} (id: ${task.id})",
          "  project: ${task.definition.projectId}${task.definition.projectId == list.callerProjectId ? " (this session's project)" : ""}",
          "  schedule: ${_descriptions.schedule(definition: task.definition)}",
          "  enabled: ${task.enabled ? "yes" : "no"}",
          "  next run: ${_instantOrNone(instant: task.nextRunAt)}",
          "  last run: ${_runOrNone(run: task.lastRun)}",
        ].join("\n"),
    ].join("\n");
  }

  String task({required AgentTaskFound found}) {
    final AgentTaskFound(:task, :isCallersOwn) = found;
    final definition = task.definition;
    return [
      "${definition.name} (id: ${task.id})${isCallersOwn ? ", the task this session runs for" : ""}",
      "project: ${definition.projectId}",
      "harness: ${definition.pluginId}",
      "agent: ${definition.agent ?? "harness default"}",
      "model: ${switch (definition.model) {
        PromptModel(:final providerID, :final modelID) => "$providerID/$modelID",
        null => "harness default",
      }}",
      if (definition.variant case SessionVariant(:final id)) "variant: $id",
      "fast mode: ${definition.fastMode ? "on" : "off"}",
      "dedicated worktree per run: ${definition.dedicatedWorktree ? "yes" : "no"}",
      "schedule: ${_descriptions.schedule(definition: definition)}",
      "when a run is missed: ${switch (definition.missedRunPolicy) {
        TaskMissedRunPolicy.runWhenBack => "run once when the bridge is back",
        TaskMissedRunPolicy.waitForNext => "wait for the next time",
        TaskMissedRunPolicy.unknown => "unknown",
      }}",
      "runs in: ${switch (definition.runMode) {
        TaskRunModeNewSession() => "a new session each run",
        TaskRunModeSameSession(:final autoCompact) => "one session for every run${autoCompact ? ", compacted before each run" : ""}",
        TaskRunModeUnknown() => "unknown",
      }}",
      "permissions: ${switch (definition.approvalMode) {
        TaskApprovalMode.ask => "ask",
        TaskApprovalMode.approveAll => "approve all",
        TaskApprovalMode.unknown => "unknown",
      }}",
      "enabled: ${task.enabled ? "yes" : "no"}",
      "next run: ${_instantOrNone(instant: task.nextRunAt)}",
      "last run: ${_runOrNone(run: task.lastRun)}",
      switch (task.command) {
        final command? => "command, run before each run's prompt:\n${_fenced(text: command)}",
        null => "command: none",
      },
      "prompt:",
      switch (definition.prompt) {
        ScheduledTaskPromptText(:final text) => text,
        ScheduledTaskPromptCommand(:final name, :final arguments) => "/$name${arguments == null ? "" : " $arguments"}",
        ScheduledTaskPromptUnknown() => "(a prompt kind this bridge does not know)",
      },
    ].join("\n");
  }

  String wakeUpScheduled({required StoredSessionWakeUp wakeUp}) {
    final repeats = _wakeUpWords.repeats(schedule: wakeUp.schedule);
    return [
      "Wake-up ${wakeUp.id} is set for ${_wakeUpWords.instant(at: wakeUp.nextDueAt)}.",
      "Sesori sends this session its prompt then, once the session's turn has ended.",
      if (wakeUp.command != null) "Right before, it runs the command and adds its result to the prompt.",
      if (repeats != null) "It repeats $repeats until you call cancel_wakeup.",
      "End your turn now; don't wait or poll.",
    ].join(" ");
  }

  String wakeUpList({required List<StoredSessionWakeUp> wakeUps}) {
    if (wakeUps.isEmpty) return "This session has no wake-ups.";
    return [
      for (final wakeUp in wakeUps)
        [
          "- ${wakeUp.label} (id: ${wakeUp.id})",
          "  next: ${_wakeUpWords.instant(at: wakeUp.nextDueAt)}",
          "  repeats: ${_wakeUpWords.repeats(schedule: wakeUp.schedule) ?? "no"}",
          if (wakeUp.command != null) "  runs a command first",
        ].join("\n"),
    ].join("\n");
  }

  String runs({required String taskId, required AgentTaskRuns runs}) {
    if (runs.runs.isEmpty) return "Task $taskId has not run yet.";
    return [
      for (final AgentTaskRun(:run, :finalReply) in runs.runs)
        [
          "- run ${run.id}: ${_runLine(run: run)}",
          if (finalReply != null) "  final reply: ${_excerpt(text: finalReply, limit: _replyExcerptChars)}",
        ].join("\n"),
    ].join("\n");
  }

  /// Each message as one block, oldest first, none longer than a page.
  List<String> transcriptBlocks({required List<MessageWithParts> messages}) {
    return [
      for (final message in messages)
        _excerpt(
          text: _message(message: message),
          limit: transcriptPageChars,
        ),
    ];
  }

  /// How many of the newest [blocks] fit one page; at least one.
  int newestFittingPage({required List<String> blocks}) {
    var used = 0;
    var count = 0;
    for (final block in blocks.reversed) {
      used += block.length;
      if (count > 0 && used > transcriptPageChars) break;
      count++;
    }
    return count;
  }

  String transcript({required String sessionId, required List<String> blocks, required int? nextPage}) {
    return [
      "Transcript of session $sessionId, oldest message of this page first.",
      if (blocks.isEmpty) "(no messages)",
      ...blocks,
      if (nextPage == null)
        "This is the start of the session."
      else
        "Older messages remain: call again with page: $nextPage.",
    ].join("\n\n");
  }

  String runWithoutSession({required ScheduledTaskRun run}) {
    return switch (run.outcome) {
      ScheduledTaskRunStarted() => "Run ${run.id} started a session that has since been deleted.",
      _ => "Run ${run.id} has no transcript: ${_runLine(run: run)}.",
    };
  }

  String _message({required MessageWithParts message}) {
    final header = switch (message.info) {
      MessageUser() => "[user]",
      MessageAssistant() => "[assistant]",
      MessageError(:final errorName, :final errorMessage) => "[error] $errorName: $errorMessage",
    };
    return [header, for (final part in message.parts) ?_part(part: part)].join("\n");
  }

  /// Null for parts that carry nothing an agent reads, such as reasoning.
  String? _part({required MessagePart part}) {
    return switch (part) {
      MessagePartText(:final text) when text.trim().isNotEmpty => text.trim(),
      MessagePartTool(:final tool, :final state) => _tool(name: tool, state: state),
      MessagePartSubtask(:final description, :final agent) => "[subtask${agent.isEmpty ? "" : " $agent"}] $description",
      MessagePartFile(:final attachment) => "[file${_filename(attachment: attachment)}]",
      MessagePartRetry(:final retryError) => "[retry] $retryError",
      MessagePartCompaction() => "[context compacted]",
      _ => null,
    };
  }

  String _tool({required String name, required ToolState state}) {
    final title = state.title ?? state.shellCommand;
    final result = switch (state) {
      ToolStateFull(:final error?) => "error: ${_excerpt(text: error, limit: _toolResultChars)}",
      ToolStateFull(:final output?) => _excerpt(text: output, limit: _toolResultChars),
      _ => null,
    };
    return [
      "[tool $name${title == null ? "" : ": $title"}] ${state.status.name}",
      if (result != null) "  result: $result",
    ].join("\n");
  }

  String _filename({required MessageAttachment attachment}) {
    final filename = switch (attachment) {
      MessageAttachmentInlineImage(:final filename) => filename,
      MessageAttachmentRemoteUrl(:final filename) => filename,
      MessageAttachmentStoredImage(:final filename) => filename,
      MessageAttachmentMetadata(:final filename) => filename,
      MessageAttachmentUnknown() => null,
    };
    return filename == null ? "" : " $filename";
  }

  String _runOrNone({required ScheduledTaskRun? run}) => run == null ? "none" : _runLine(run: run);

  String _runLine({required ScheduledTaskRun run}) {
    final outcome = switch (run.outcome) {
      ScheduledTaskRunStarted(:final session, :final late) =>
        "started${late ? " late" : ""}${session == null ? ", session deleted" : ""}",
      ScheduledTaskRunSkipped() => "skipped, the previous run was still going",
      ScheduledTaskRunMissed() => "missed, the bridge was off or asleep",
      ScheduledTaskRunFailed(:final reason) =>
        "could not start: ${switch (reason) {
          TaskRunFailureReason.projectMissing => "the project folder is missing",
          TaskRunFailureReason.harnessUnavailable => "the harness is unavailable",
          TaskRunFailureReason.modelUnavailable => "the model is no longer offered",
          TaskRunFailureReason.startFailed => "the session failed to start",
          TaskRunFailureReason.unknown => "unknown reason",
        }}",
      ScheduledTaskRunOutcomeUnknown() => "unknown outcome",
    };
    return "${_instant(instant: run.scheduledFor)}, $outcome";
  }

  String _instantOrNone({required ScheduledTaskInstant? instant}) =>
      instant == null ? "none" : _instant(instant: instant);

  /// The instant in the task's wall-clock time, with its UTC offset.
  String _instant({required ScheduledTaskInstant instant}) {
    final local = DateTime.fromMillisecondsSinceEpoch(
      instant.at,
      isUtc: true,
    ).add(Duration(minutes: instant.offsetMinutes));
    final offset = instant.offsetMinutes.abs();
    final sign = instant.offsetMinutes < 0 ? "-" : "+";
    return "${_date(year: local.year, month: local.month, day: local.day)} "
        "${_two(value: local.hour)}:${_two(value: local.minute)} (UTC$sign${_two(value: offset ~/ 60)}:${_two(value: offset % 60)})";
  }

  String _date({required int year, required int month, required int day}) =>
      "${year.toString().padLeft(4, "0")}-${_two(value: month)}-${_two(value: day)}";

  String _fenced({required String text}) {
    final fence = ScheduledTaskChangeDescriptionBuilder.fence(text: text);
    return "$fence\n$text\n$fence";
  }

  String _two({required int value}) => value.toString().padLeft(2, "0");

  String _excerpt({required String text, required int limit}) {
    final trimmed = text.trim();
    if (trimmed.length <= limit) return trimmed;
    return "${trimmed.substring(0, limit)}... (${trimmed.length - limit} more characters)";
  }
}
