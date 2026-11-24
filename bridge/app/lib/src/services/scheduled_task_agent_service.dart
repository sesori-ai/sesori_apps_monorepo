import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";
import "package:sesori_tool_interface/sesori_tool_interface.dart" show SesoriToolCaller;

import "../repositories/agent_approval_repository.dart";
import "../repositories/models/agent_approval_change.dart";
import "../repositories/models/agent_approval_outcome.dart";
import "../repositories/models/history_window.dart";
import "../repositories/models/scheduled_task_record.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/models/task_command_edit.dart";
import "../repositories/project_repository.dart";
import "../repositories/scheduled_task_repository.dart";
import "../repositories/session_repository.dart";
import "chat_history_service.dart";
import "scheduled_task_change_description_builder.dart";
import "scheduled_task_request_exception.dart";
import "scheduled_task_run_service.dart";
import "scheduled_task_service.dart";
import "session_notice_service.dart";
import "session_wake_up_service.dart";
import "tool_group_approval_service.dart";

/// What agents may do with scheduled tasks, through the same services the
/// app's task routes call. Reads cover every task on this computer.
///
/// Every write is a proposal: it waits as a permission request until the user
/// allows it, and only then goes through the same service calls as the app's
/// routes. Auto-approval never sees these requests, because they are neither
/// plugin events nor in the plugin permission lists.
class ScheduledTaskAgentService({
  required final ScheduledTaskService _tasks,
  required final ScheduledTaskRunService _runner,
  required final ScheduledTaskRepository _taskRepository,
  required final SessionRepository _sessions,
  required final ProjectRepository _projects,
  required final ChatHistoryService _history,
  required final AgentApprovalRepository _approvals,
  required final ScheduledTaskChangeDescriptionBuilder _descriptions,
  required final SessionNoticeService _notices,
  required final SessionWakeUpService _wakeUps,
  required final ToolGroupApprovalService _toolGroupApprovals,
}) {
  /// Messages read to find a run's final reply. The reply closes the turn,
  /// so it is among the newest few, even after a short notice turn.
  static const int _finalReplyWindow = 10;

  /// Every task not yet done, or those of [projectId]. A task can outlive
  /// its project, so [projectId] is unknown only when no task has it either.
  Future<AgentTaskListLookup> listTasks({required SesoriToolCaller caller, required String? projectId}) async {
    final tasks = [
      for (final task in (await _tasks.list()).items)
        if (projectId == null || task.definition.projectId == projectId) task,
    ];
    if (projectId != null && tasks.isEmpty && await _projects.projectPath(projectId: projectId) == null) {
      return AgentTaskListUnknownProject(projectId: projectId);
    }
    return AgentTaskList(
      tasks: tasks,
      callerProjectId: (await _sessions.getStoredSession(sessionId: caller.sessionId))?.projectId,
    );
  }

  /// [taskId], or the caller's own task when the caller is a scheduled run.
  Future<AgentTaskLookup> getTask({required SesoriToolCaller caller, required String? taskId}) async {
    final ownTaskId = await _ownTaskId(caller: caller);
    final targetId = taskId ?? ownTaskId;
    if (targetId == null) return const AgentTaskNotScheduledRun();
    final task = (await _tasks.list()).items.where((task) => task.id == targetId).firstOrNull;
    if (task == null) return AgentTaskNotFound(taskId: targetId);
    return AgentTaskFound(task: task, isCallersOwn: task.id == ownTaskId);
  }

  /// The task's runs, newest first, each started run with its final reply.
  ///
  /// Same-session runs share one session, so only the newest run of a session
  /// carries its reply.
  Future<AgentTaskRunsLookup> listTaskRuns({required String taskId}) async {
    final runs = await _runs(taskId: taskId);
    if (runs == null) return AgentTaskRunsTaskNotFound(taskId: taskId);
    final repliedSessions = <String>{};
    final entries = <AgentTaskRun>[];
    for (final run in runs) {
      String? finalReply;
      if (run.outcome case ScheduledTaskRunStarted(session: ScheduledTaskRunSession(:final id))) {
        final isNewestRunOfSession = repliedSessions.add(id);
        if (isNewestRunOfSession) finalReply = await _finalReply(sessionId: id);
      }
      entries.add(AgentTaskRun(run: run, finalReply: finalReply));
    }
    return AgentTaskRuns(runs: entries);
  }

  /// Up to [limit] messages of [runId]'s session, the newest ones older than
  /// [before] (or the newest of all when null), oldest first.
  Future<AgentRunTranscriptLookup> runTranscript({
    required String taskId,
    required String runId,
    required int? before,
    required int limit,
  }) async {
    final runs = await _runs(taskId: taskId);
    if (runs == null) return AgentRunTranscriptTaskNotFound(taskId: taskId);
    final run = runs.where((run) => run.id == runId).firstOrNull;
    if (run == null) return AgentRunTranscriptRunNotFound(runId: runId);
    if (run.outcome case ScheduledTaskRunStarted(session: ScheduledTaskRunSession(:final id))) {
      final page = await _storedPage(
        sessionId: id,
        window: HistoryWindowNewest(limit: limit, before: before),
      );
      return AgentRunTranscript(sessionId: id, messages: page.messages, nextCursor: page.nextCursor);
    }
    return AgentRunTranscriptNoSession(run: run);
  }

  /// Asks to create [task] in the caller's project, or in [projectId], with
  /// the caller's harness.
  Future<AgentProposal> proposeCreate({
    required SesoriToolCaller caller,
    required String? projectId,
    required AgentNewTask task,
  }) async {
    final session = await _sessions.getStoredSession(sessionId: caller.sessionId);
    if (session == null) return const AgentProposalRefused(reason: AgentProposalRefusal.callerGone);
    final definition = ScheduledTaskDefinition(
      name: task.name,
      prompt: ScheduledTaskPrompt.text(text: task.promptText),
      projectId: projectId ?? session.projectId,
      pluginId: session.pluginId,
      agent: null,
      model: task.model,
      variant: task.variant,
      fastMode: false,
      dedicatedWorktree: false,
      schedule: task.schedule,
      timeZone: task.timeZone,
      missedRunPolicy: task.missedRunPolicy,
      runMode: task.runMode,
      approvalMode: task.approvalMode,
    );
    final invalid = await _invalid(definition: definition, previousModel: null);
    if (invalid != null) return invalid;
    return await _propose(
      caller: caller,
      change: CreateTaskChange(definition: definition, command: task.command),
    );
  }

  /// Asks to apply [edits] to [taskId]; fields [edits] leaves null keep their
  /// value.
  Future<AgentProposal> proposeUpdate({
    required SesoriToolCaller caller,
    required String taskId,
    required AgentTaskEdits edits,
  }) async {
    final record = await _uncompletedTask(taskId: taskId);
    if (record == null) return AgentProposalTaskNotFound(taskId: taskId);
    final before = record.definition;
    final ScheduledTaskPrompt prompt;
    switch (before.prompt) {
      case ScheduledTaskPromptText():
        if (edits.commandArguments != null) {
          return const AgentProposalRefused(reason: AgentProposalRefusal.promptIsText);
        }
        prompt = switch (edits.promptText) {
          final text? => ScheduledTaskPrompt.text(text: text),
          null => before.prompt,
        };
      case ScheduledTaskPromptCommand(:final name, :final source):
        if (edits.promptText != null) {
          return const AgentProposalRefused(reason: AgentProposalRefusal.promptIsCommand);
        }
        prompt = switch (edits.commandArguments) {
          final arguments? => ScheduledTaskPrompt.command(name: name, source: source, arguments: arguments),
          null => before.prompt,
        };
      case ScheduledTaskPromptUnknown():
        // Validation refuses a prompt kind this bridge does not know.
        prompt = before.prompt;
    }
    final command = switch (edits.command) {
      TaskCommandSet(:final command) when command == record.command => const TaskCommandUnchanged(),
      TaskCommandRemoved() when record.command == null => const TaskCommandUnchanged(),
      final edit => edit,
    };
    // A slash command's arguments are the command's input, so no note with a
    // shell command's result can lead them.
    if (command is TaskCommandSet && before.prompt is ScheduledTaskPromptCommand) {
      return const AgentProposalRefused(reason: AgentProposalRefusal.shellCommandOnSlashCommand);
    }
    final after = before.copyWith(
      name: edits.name ?? before.name,
      prompt: prompt,
      schedule: edits.schedule ?? before.schedule,
      timeZone: edits.timeZone ?? before.timeZone,
      missedRunPolicy: edits.missedRunPolicy ?? before.missedRunPolicy,
      runMode: edits.runMode ?? before.runMode,
      model: edits.model ?? before.model,
      variant: edits.variant ?? before.variant,
      approvalMode: edits.approvalMode ?? before.approvalMode,
    );
    if (after == before && command is TaskCommandUnchanged) {
      return const AgentProposalRefused(reason: AgentProposalRefusal.nothingChanged);
    }
    final invalid = await _invalid(definition: after, previousModel: before.model);
    if (invalid != null) return invalid;
    return await _propose(
      caller: caller,
      change: UpdateTaskChange(
        taskId: taskId,
        before: before,
        beforeCommand: record.command,
        after: after,
        command: command,
      ),
    );
  }

  /// Asks to pause or resume [taskId].
  Future<AgentProposal> proposeSetEnabled({
    required SesoriToolCaller caller,
    required String taskId,
    required bool enabled,
  }) async {
    final record = await _uncompletedTask(taskId: taskId);
    if (record == null) return AgentProposalTaskNotFound(taskId: taskId);
    if (record.enabled == enabled) return const AgentProposalRefused(reason: AgentProposalRefusal.alreadyInState);
    return await _propose(
      caller: caller,
      change: SetTaskEnabledChange(
        taskId: taskId,
        before: record.definition,
        beforeCommand: record.command,
        enabled: enabled,
      ),
    );
  }

  /// Asks to run [taskId] once now.
  Future<AgentProposal> proposeRunNow({required SesoriToolCaller caller, required String taskId}) async {
    final record = await _uncompletedTask(taskId: taskId);
    if (record == null) return AgentProposalTaskNotFound(taskId: taskId);
    return await _propose(
      caller: caller,
      change: RunTaskNowChange(taskId: taskId, before: record.definition, beforeCommand: record.command),
    );
  }

  /// Answers [requestId] when it is an agent approval. A wake-up command
  /// goes to the wake-up service, and a tool group's change to the group
  /// waiting on it. Allow applies a task change through the
  /// app's own service calls, unless what it was described
  /// against has changed since (see [StoredTaskChange]): an earlier edit, the
  /// user's own or another allowed request, wins.
  ///
  /// The session where the request showed is then told the outcome; the
  /// reply does not wait for that.
  Future<AgentApprovalSettlement> settle({required String requestId, required PermissionReply reply}) async {
    final approval = _approvals.take(requestId: requestId, reply: reply);
    if (approval == null) return const NotAgentApproval();
    final ScheduledTaskAgentChange change;
    switch (approval.change) {
      case final WakeUpCommandChange wakeUpChange:
        await _wakeUps.applyCommandApproval(change: wakeUpChange, reply: reply);
        return const WakeUpCommandAnswered();
      case ToolGroupAgentChange():
        _toolGroupApprovals.settle(requestId: requestId, reply: reply);
        return const ToolGroupChangeAnswered();
      case final ScheduledTaskAgentChange taskChange:
        change = taskChange;
    }
    final outcome = await _outcome(change: change, reply: reply);
    unawaited(
      _notices.deliver(
        sessionId: approval.displaySessionId ?? approval.sessionId,
        notice: _descriptions.outcome(
          change: change,
          outcome: outcome,
          bySubagent: approval.displaySessionId != null,
        ),
        timing: SessionNoticeTiming.derived,
        claim: null,
      ),
    );
    return AgentApprovalAnswered(outcome: outcome);
  }

  /// The agent approvals to show on [sessionId]'s screen.
  List<PendingPermission> pendingPermissions({required String sessionId}) =>
      _approvals.pendingPermissions(sessionId: sessionId);

  Future<AgentApprovalOutcome> _outcome({
    required ScheduledTaskAgentChange change,
    required PermissionReply reply,
  }) async {
    if (reply == PermissionReply.reject) return const AgentApprovalRejected();
    switch (change) {
      case CreateTaskChange(:final definition, :final command):
        return AgentApprovalCreated(
          taskId: (await _tasks.create(definition: definition, command: command)).id,
        );
      case final StoredTaskChange change:
        return await _applyStored(change: change);
    }
  }

  Future<AgentApprovalOutcome> _applyStored({required StoredTaskChange change}) async {
    final taskId = change.taskId;
    final record = await _uncompletedTask(taskId: taskId);
    if (record == null) return const AgentApprovalStale();
    final current = record.definition;
    final before = change.before;
    // The request was described for this project and harness, and its Approve
    // everything warning was worked out from this mode, so only a pause, which
    // is always safe, outlives a change to any of them.
    final sameContext =
        current.projectId == before.projectId &&
        current.pluginId == before.pluginId &&
        current.approvalMode == before.approvalMode;
    // A resume or a run shows the command its runs run first.
    final sameCommand = record.command == change.beforeCommand;
    switch (change) {
      case UpdateTaskChange():
        final rebased = sameContext ? _rebased(change: change, current: current) : null;
        final command = _rebasedCommand(change: change, current: record.command);
        if (rebased == null || command == null) return const AgentApprovalStale();
        try {
          await _tasks.update(taskId: taskId, definition: rebased, command: command);
        } on ScheduledTaskRequestException catch (error, stackTrace) {
          Log.w("An allowed change to task $taskId no longer validates on the current task", error, stackTrace);
          return const AgentApprovalStale();
        }
      case SetTaskEnabledChange(enabled: false):
        if (!record.enabled) return const AgentApprovalStale();
        await _tasks.setEnabled(taskId: taskId, enabled: false);
      case SetTaskEnabledChange(enabled: true):
        // A resume request shows the schedule it restarts.
        final sameSchedule = current.schedule == before.schedule && current.timeZone == before.timeZone;
        if (record.enabled || !sameContext || !sameCommand || !sameSchedule) return const AgentApprovalStale();
        await _tasks.setEnabled(taskId: taskId, enabled: true);
      case RunTaskNowChange():
        if (!sameContext || !sameCommand) return const AgentApprovalStale();
        final run = await _runner.runNow(taskId: taskId);
        if (run.outcome is! ScheduledTaskRunStarted) return AgentApprovalRunNotStarted(outcome: run.outcome);
    }
    return const AgentApprovalApplied();
  }

  /// [current] with the fields [change] edits set to its values, or null when
  /// one of them no longer holds the value the request was described with.
  /// Covers every field [proposeUpdate] can edit.
  static ScheduledTaskDefinition? _rebased({
    required UpdateTaskChange change,
    required ScheduledTaskDefinition current,
  }) {
    final UpdateTaskChange(:before, :after) = change;
    var conflicts = false;
    T edited<T>(T Function(ScheduledTaskDefinition definition) field) {
      final proposed = field(after);
      if (proposed == field(before)) return field(current);
      if (field(current) != field(before)) conflicts = true;
      return proposed;
    }

    // A schedule reads in its time zone, and a variant belongs to its model, so
    // each pair is approved, and checked, as one value.
    final (schedule, timeZone) = edited((definition) => (definition.schedule, definition.timeZone));
    final (model, variant) = edited((definition) => (definition.model, definition.variant));
    final rebased = current.copyWith(
      name: edited((definition) => definition.name),
      prompt: edited((definition) => definition.prompt),
      schedule: schedule,
      timeZone: timeZone,
      missedRunPolicy: edited((definition) => definition.missedRunPolicy),
      runMode: edited((definition) => definition.runMode),
      model: model,
      variant: variant,
      approvalMode: edited((definition) => definition.approvalMode),
    );
    return conflicts ? null : rebased;
  }

  /// [change]'s command edit, or null when the task's [current] command is
  /// no longer the one the request was described with.
  static TaskCommandEdit? _rebasedCommand({required UpdateTaskChange change, required String? current}) =>
      switch (change.command) {
        TaskCommandUnchanged() => const TaskCommandUnchanged(),
        final edit => current == change.beforeCommand ? edit : null,
      };

  Future<AgentProposal> _propose({
    required SesoriToolCaller caller,
    required ScheduledTaskAgentChange change,
  }) async {
    final SessionFamilyScope family;
    try {
      family = await _sessions.resolveSessionFamily(
        sessionId: caller.sessionId,
        operation: SessionOperation.proposeTaskChange,
      );
    } on PluginOperationException {
      return const AgentProposalRefused(reason: AgentProposalRefusal.callerGone);
    }
    final rootSessionId = family.rootSessionId;
    final projectId = switch (change) {
      CreateTaskChange(:final definition) => definition.projectId,
      StoredTaskChange(:final before) => before.projectId,
    };
    _approvals.add(
      sessionId: caller.sessionId,
      // Subagent requests show on the root session, like plugin permissions.
      displaySessionId: rootSessionId == caller.sessionId ? null : rootSessionId,
      change: change,
      description: _descriptions.build(
        change: change,
        projectName: await _projects.getProjectName(projectId: projectId) ?? projectId,
        requester: await _requester(caller: caller, change: change),
      ),
    );
    return const AgentProposalSent();
  }

  /// Why [definition] could not be saved, as the app's editor would be told,
  /// or why its runs could not start: the editor offers only the harness's
  /// models, so a model other than [previousModel] must be one of them.
  /// Pause, resume and run now skip this: pausing a broken task must still
  /// be possible.
  Future<AgentProposal?> _invalid({
    required ScheduledTaskDefinition definition,
    required PromptModel? previousModel,
  }) async {
    try {
      await _tasks.validate(definition: definition);
    } on ScheduledTaskRequestException catch (error) {
      return AgentProposalInvalid(code: error.code);
    }
    final model = definition.model;
    if (model == null || model == previousModel) return null;
    final offered = await _runner.offersModel(
      definition: definition,
      model: model,
      context: "A proposed task for ${definition.pluginId} in project ${definition.projectId}",
    );
    return offered ? null : const AgentProposalRefused(reason: AgentProposalRefusal.modelNotOffered);
  }

  Future<AgentRequester> _requester({
    required SesoriToolCaller caller,
    required ScheduledTaskAgentChange change,
  }) async {
    final ownTaskId = await _ownTaskId(caller: caller);
    if (ownTaskId != null) {
      if (change is StoredTaskChange && change.taskId == ownTaskId) return const RequestedByOwnRun();
      if (await _taskRepository.get(taskId: ownTaskId) case final ownTask?) {
        return RequestedByTaskRun(taskName: ownTask.definition.name);
      }
    }
    return RequestedFromSession(title: await _sessions.getSessionTitle(sessionId: caller.sessionId));
  }

  /// A done one-off task has left the list, so agents cannot change it.
  Future<ScheduledTaskRecord?> _uncompletedTask({required String taskId}) async {
    final record = await _taskRepository.get(taskId: taskId);
    return record == null || record.completedAt != null ? null : record;
  }

  Future<String?> _ownTaskId({required SesoriToolCaller caller}) async {
    final marks = await _taskRepository.marksOfSessions(sessionIds: {caller.sessionId});
    return marks[caller.sessionId]?.taskId;
  }

  /// Null when the task does not exist.
  Future<List<ScheduledTaskRun>?> _runs({required String taskId}) async {
    try {
      return (await _tasks.listRuns(taskId: taskId)).items;
    } on ScheduledTaskRequestException catch (error) {
      if (error.code != ScheduledTaskErrorCode.taskNotFound) rethrow;
      return null;
    }
  }

  /// The agent's last reply in a turn the run's prompt started. A turn a
  /// Sesori notice started (the agent's answer to an outcome) is skipped, so
  /// the run's own reply stays its final reply; a notice never steers into a
  /// run's turn (see [settle]), so every Sesori row here starts one.
  Future<String?> _finalReply({required String sessionId}) async {
    final page = await _storedPage(
      sessionId: sessionId,
      window: const HistoryWindowNewest(limit: _finalReplyWindow, before: null),
    );
    String? reply;
    for (final message in page.messages.reversed) {
      switch (message.info) {
        case MessageAssistant(sender: MessageSender.sesori):
          reply = null;
        case MessageAssistant(sender: MessageSender.agent) when reply == null:
          final text = [
            for (final part in message.parts)
              if (part case MessagePartText(:final text) when text.trim().isNotEmpty) text.trim(),
          ].join("\n\n");
          if (text.isNotEmpty) reply = text;
        case MessageUser() when reply != null:
          return reply;
        case MessageAssistant() || MessageUser() || MessageError():
          break;
      }
    }
    return reply;
  }

  /// Reads only what the bridge stored, archived sessions included, so a read
  /// never starts a harness.
  Future<SessionMessagesPage> _storedPage({required String sessionId, required HistoryWindow window}) {
    return _history.getSessionMessages(
      sessionId: sessionId,
      window: window,
      attachmentDelivery: MessageAttachmentDelivery.storedReference,
      toolOutputDelivery: ToolOutputDelivery.inline,
      storedOnly: true,
      backgroundRefresh: false,
    );
  }
}

sealed class const AgentTaskListLookup();

final class const AgentTaskList({
  required final List<ScheduledTask> tasks,

  /// Null when the caller's session row is gone.
  required final String? callerProjectId,
}) extends AgentTaskListLookup;

final class const AgentTaskListUnknownProject({required final String projectId}) extends AgentTaskListLookup;

sealed class const AgentTaskLookup();

final class const AgentTaskFound({required final ScheduledTask task, required final bool isCallersOwn})
    extends AgentTaskLookup;

/// No task id was given and the caller is not a scheduled run.
final class const AgentTaskNotScheduledRun() extends AgentTaskLookup;

final class const AgentTaskNotFound({required final String taskId}) extends AgentTaskLookup;

final class const AgentTaskRun({
  required final ScheduledTaskRun run,

  /// The run session's final assistant reply, when it has one.
  required final String? finalReply,
});

sealed class const AgentTaskRunsLookup();

final class const AgentTaskRuns({required final List<AgentTaskRun> runs}) extends AgentTaskRunsLookup;

final class const AgentTaskRunsTaskNotFound({required final String taskId}) extends AgentTaskRunsLookup;

sealed class const AgentRunTranscriptLookup();

final class const AgentRunTranscript({
  required final String sessionId,
  required final List<MessageWithParts> messages,

  /// Pass back as `before` for the next older page; null when none is left.
  required final int? nextCursor,
}) extends AgentRunTranscriptLookup;

final class const AgentRunTranscriptTaskNotFound({required final String taskId}) extends AgentRunTranscriptLookup;

final class const AgentRunTranscriptRunNotFound({required final String runId}) extends AgentRunTranscriptLookup;

/// The run never started a session, or its session was deleted.
final class const AgentRunTranscriptNoSession({required final ScheduledTaskRun run}) extends AgentRunTranscriptLookup;

/// A new task's fields an agent sets; the bridge fills in the rest.
final class const AgentNewTask({
  required final String name,
  required final String promptText,
  required final TaskSchedule schedule,
  required final String timeZone,
  required final TaskMissedRunPolicy missedRunPolicy,
  required final TaskRunMode runMode,

  /// Null leaves the model to the harness.
  required final PromptModel? model,

  /// Null leaves the effort to the harness.
  required final SessionVariant? variant,
  required final TaskApprovalMode approvalMode,

  /// The shell command each run runs first; null for none.
  required final String? command,
});

/// The fields an agent changes on a task; null keeps the current value.
final class const AgentTaskEdits({
  required final String? name,

  /// A text task's new prompt.
  required final String? promptText,

  /// A command task's new argument text; its command stays.
  required final String? commandArguments,
  required final TaskSchedule? schedule,
  required final String? timeZone,
  required final TaskMissedRunPolicy? missedRunPolicy,
  required final TaskRunMode? runMode,
  required final PromptModel? model,
  required final SessionVariant? variant,
  required final TaskApprovalMode? approvalMode,
  required final TaskCommandEdit command,
});

sealed class const AgentProposal();

/// The request is on the user's phone, beside any the session already has
/// waiting.
final class const AgentProposalSent() extends AgentProposal;

final class const AgentProposalTaskNotFound({required final String taskId}) extends AgentProposal;

/// The resulting task could not be saved, as the app's editor would be told.
final class const AgentProposalInvalid({required final ScheduledTaskErrorCode code}) extends AgentProposal;

final class const AgentProposalRefused({required final AgentProposalRefusal reason}) extends AgentProposal;

enum AgentProposalRefusal() {
  /// The calling session's row is gone.
  callerGone,
  nothingChanged,

  /// A prompt text for a task that runs a command.
  promptIsCommand,

  /// Command arguments for a task that sends text.
  promptIsText,

  /// Pausing a paused task, or resuming a running one.
  alreadyInState,

  /// A model the task's harness does not offer, so its runs could not start.
  modelNotOffered,

  /// A shell command for a task whose prompt is a slash command.
  shellCommandOnSlashCommand,
}

sealed class const AgentApprovalSettlement();

/// The request was not an agent approval; a plugin owns it.
final class const NotAgentApproval() extends AgentApprovalSettlement;

final class const AgentApprovalAnswered({required final AgentApprovalOutcome outcome}) extends AgentApprovalSettlement;

/// A wake-up command request was answered; the wake-up service told the
/// session.
final class const WakeUpCommandAnswered() extends AgentApprovalSettlement;

/// A tool group's request was answered; the group applies the change and
/// tells the session.
final class const ToolGroupChangeAnswered() extends AgentApprovalSettlement;
