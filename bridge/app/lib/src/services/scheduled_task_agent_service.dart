import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/agent_approval_repository.dart";
import "../repositories/models/history_window.dart";
import "../repositories/models/scheduled_task_agent_change.dart";
import "../repositories/models/scheduled_task_record.dart";
import "../repositories/models/sesori_mcp_caller.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/project_repository.dart";
import "../repositories/scheduled_task_repository.dart";
import "../repositories/session_repository.dart";
import "chat_history_service.dart";
import "scheduled_task_change_description_builder.dart";
import "scheduled_task_request_exception.dart";
import "scheduled_task_run_service.dart";
import "scheduled_task_service.dart";

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
}) {
  /// Messages read to find a run's final reply. The reply closes the turn,
  /// so it is among the newest few.
  static const int _finalReplyWindow = 6;

  /// Every task not yet done, or those of [projectId]. A task can outlive
  /// its project, so [projectId] is unknown only when no task has it either.
  Future<AgentTaskListLookup> listTasks({required SesoriMcpCaller caller, required String? projectId}) async {
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
  Future<AgentTaskLookup> getTask({required SesoriMcpCaller caller, required String? taskId}) async {
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
    required SesoriMcpCaller caller,
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
      change: CreateTaskChange(definition: definition),
    );
  }

  /// Asks to apply [edits] to [taskId]; fields [edits] leaves null keep their
  /// value.
  Future<AgentProposal> proposeUpdate({
    required SesoriMcpCaller caller,
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
    if (after == before) return const AgentProposalRefused(reason: AgentProposalRefusal.nothingChanged);
    final invalid = await _invalid(definition: after, previousModel: before.model);
    if (invalid != null) return invalid;
    return await _propose(
      caller: caller,
      change: UpdateTaskChange(taskId: taskId, before: before, after: after),
    );
  }

  /// Asks to pause or resume [taskId].
  Future<AgentProposal> proposeSetEnabled({
    required SesoriMcpCaller caller,
    required String taskId,
    required bool enabled,
  }) async {
    final record = await _uncompletedTask(taskId: taskId);
    if (record == null) return AgentProposalTaskNotFound(taskId: taskId);
    if (record.enabled == enabled) return const AgentProposalRefused(reason: AgentProposalRefusal.alreadyInState);
    return await _propose(
      caller: caller,
      change: SetTaskEnabledChange(taskId: taskId, before: record.definition, enabled: enabled),
    );
  }

  /// Asks to run [taskId] once now.
  Future<AgentProposal> proposeRunNow({required SesoriMcpCaller caller, required String taskId}) async {
    final record = await _uncompletedTask(taskId: taskId);
    if (record == null) return AgentProposalTaskNotFound(taskId: taskId);
    return await _propose(
      caller: caller,
      change: RunTaskNowChange(taskId: taskId, before: record.definition),
    );
  }

  /// Answers [requestId] when it is an agent approval. Allow applies the
  /// change through the app's own service calls, unless what it was described
  /// against has changed since (see [StoredTaskChange]): an earlier edit, the
  /// user's own or another allowed request, wins.
  Future<AgentApprovalSettlement> settle({required String requestId, required PermissionReply reply}) async {
    final approval = _approvals.take(requestId: requestId, reply: reply);
    if (approval == null) return const NotAgentApproval();
    if (reply == PermissionReply.reject) return const AgentApprovalRejected();
    switch (approval.change) {
      case CreateTaskChange(:final definition):
        await _tasks.create(definition: definition);
        return const AgentApprovalApplied();
      case final StoredTaskChange change:
        return await _applyStored(change: change);
    }
  }

  /// The agent approvals to show on [sessionId]'s screen.
  List<PendingPermission> pendingPermissions({required String sessionId}) =>
      _approvals.pendingPermissions(sessionId: sessionId);

  /// [projects] with every session that waits on an agent approval marked
  /// awaiting input, even when its harness has gone idle, so the app keeps it
  /// on its attention list.
  Future<List<ProjectActivitySummary>> markAwaitingApproval({required List<ProjectActivitySummary> projects}) {
    return _sessions.markAwaitingInput(projects: projects, rootSessionIds: _approvals.awaitingRootSessionIds);
  }

  Future<AgentApprovalSettlement> _applyStored({required StoredTaskChange change}) async {
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
    switch (change) {
      case UpdateTaskChange():
        final rebased = sameContext ? _rebased(change: change, current: current) : null;
        if (rebased == null) return const AgentApprovalStale();
        try {
          await _tasks.update(taskId: taskId, definition: rebased);
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
        if (record.enabled || !sameContext || !sameSchedule) return const AgentApprovalStale();
        await _tasks.setEnabled(taskId: taskId, enabled: true);
      case RunTaskNowChange():
        if (!sameContext) return const AgentApprovalStale();
        final run = await _runner.runNow(taskId: taskId);
        if (run.outcome is! ScheduledTaskRunStarted) return const AgentApprovalRunNotStarted();
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

  Future<AgentProposal> _propose({
    required SesoriMcpCaller caller,
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

  Future<AgentRequester> _requester({required SesoriMcpCaller caller, required ScheduledTaskAgentChange change}) async {
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

  Future<String?> _ownTaskId({required SesoriMcpCaller caller}) async {
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

  Future<String?> _finalReply({required String sessionId}) async {
    final page = await _storedPage(
      sessionId: sessionId,
      window: const HistoryWindowNewest(limit: _finalReplyWindow, before: null),
    );
    for (final message in page.messages.reversed) {
      if (message.info is! MessageAssistant) continue;
      final text = [
        for (final part in message.parts)
          if (part case MessagePartText(:final text) when text.trim().isNotEmpty) text.trim(),
      ].join("\n\n");
      if (text.isNotEmpty) return text;
    }
    return null;
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
}

sealed class const AgentApprovalSettlement();

/// The request was not an agent approval; a plugin owns it.
final class const NotAgentApproval() extends AgentApprovalSettlement;

final class const AgentApprovalApplied() extends AgentApprovalSettlement;

final class const AgentApprovalRejected() extends AgentApprovalSettlement;

/// Allowed, but the task was deleted, or what the request was described
/// against changed since, so nothing was applied.
final class const AgentApprovalStale() extends AgentApprovalSettlement;

/// Allowed, but the run did not start; its run record holds the reason.
final class const AgentApprovalRunNotStarted() extends AgentApprovalSettlement;
