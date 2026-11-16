import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show ParallelLock;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginWorkingDirectoryMissingException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/project_not_found_exception.dart";
import "../repositories/models/scheduled_task_record.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/models/session_quietness.dart";
import "../repositories/project_repository.dart";
import "../repositories/scheduled_task_repository.dart";
import "../repositories/session_repository.dart";
import "scheduled_task_compaction_service.dart";
import "scheduled_task_occurrence_calculator.dart";
import "scheduled_task_request_exception.dart";
import "scheduled_task_run_failure.dart";
import "session_creation_service.dart";
import "session_lifecycle_service.dart";
import "session_operation_dispatcher.dart";
import "session_options_service.dart";
import "session_prompt_service.dart";
import "stale_session_prompt_options_exception.dart";
import "yolo_settings_service.dart";

/// Fires tasks: every due task on each timer pass, and one task on Run now.
///
/// A fire writes its history row, with the task's advanced next due time, in
/// one transaction before the prompt is sent, so a crash can lose a run but
/// never start one twice. A new-session run creates a session; a same-session
/// run continues in the task's target session, creating and targeting one
/// when there is none. Every history row written is announced on [changes],
/// and every scheduled run that could not start on [failures]. A Run now that
/// cannot start answers its caller instead.
///
/// A same-session task with auto-compact on has [ScheduledTaskCompactionService]
/// compact its session after each run, on the same passes; a run due before
/// that compacts first.
///
/// After a new-session run starts, the task's finished run sessions beyond
/// the newest [keptFinishedRuns] are archived, apart from the fire and one
/// task at a time.
class ScheduledTaskRunService({
  required final ScheduledTaskRepository _repository,
  required final ScheduledTaskCompactionService _compaction,
  required final SessionCreationService _sessionCreation,
  required final SessionPromptService _prompts,
  required final SessionOperationDispatcher _operations,
  required final YoloSettingsService _yoloSettings,
  required final SessionRepository _sessions,
  required final ProjectRepository _projects,
  required final SessionLifecycleService _lifecycle,
  required final SessionOptionsService _sessionOptions,
  required final ScheduledTaskOccurrenceCalculator _calculator,
  required final Clock _clock,
}) {
  /// How long after its prompt goes out a run counts as going before its
  /// session's quietness decides.
  static const Duration startupGrace = Duration(seconds: 30);

  /// Serializes every pass and Run now, so no two fire the same task.
  final ParallelLock _lock = ParallelLock(maxParallelOperations: 1);

  /// Archive passes run one after another, outside [_lock], so archiving
  /// never holds up a fire.
  Future<void> _archiving = Future<void>.value();

  /// When each task's latest run's prompt went out.
  final Map<String, DateTime> _promptSentAt = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final StreamController<ScheduledTaskRunFailure> _failures = StreamController<ScheduledTaskRunFailure>.broadcast();

  Stream<void> get changes => _changes.stream;

  Stream<ScheduledTaskRunFailure> get failures => _failures.stream;

  /// Fires every due task once.
  Future<void> runDue() => _lock.use(operation: _runDueLocked);

  /// Fires [taskId] now by the same rules, leaving its next due time alone.
  /// Refused while the previous run is still going.
  Future<ScheduledTaskRun> runNow({required String taskId}) =>
      _lock.use(operation: () => _runNowLocked(taskId: taskId));

  /// Finished run sessions of a new-session task left unarchived.
  static const int keptFinishedRuns = 5;

  Future<void> dispose() async {
    await _lock.idle;
    await _archiving;
    await Future.wait([_changes.close(), _failures.close()]);
  }

  Future<void> _runDueLocked() async {
    for (final (:task, :dueAt) in await _repository.listDue(now: _clock.now())) {
      try {
        await _fireDue(task: task, dueAt: dueAt);
      } on Object catch (error, stackTrace) {
        Log.w("Scheduled task ${task.id} in project ${task.definition.projectId} could not fire", error, stackTrace);
      }
    }
    await _compaction.compactQuietRuns();
  }

  Future<void> _fireDue({required ScheduledTaskRecord task, required DateTime dueAt}) async {
    final definition = task.definition;
    final gate = await _compaction.gateDueRun(task: task);
    if (gate == DueRunGate.hold) return;
    final now = _clock.now();
    final action = switch (_calculator.dueAction(
      schedule: definition.schedule,
      missedRunPolicy: definition.missedRunPolicy,
      dueAt: dueAt,
      now: now,
    )) {
      ScheduledTaskDueAction.recordMissed when gate == DueRunGate.fireAfterCompaction =>
        ScheduledTaskDueAction.fireLate,
      final action => action,
    };
    final outcome = action == ScheduledTaskDueAction.recordMissed
        ? const ScheduledTaskRunOutcome.missed()
        : await _outcomeToFire(task: task, late: action == ScheduledTaskDueAction.fireLate);
    final run = await _repository.reserveRun(
      task: task,
      // However many times were missed, the task next falls due after now.
      nextDueAt: _calculator.nextDueAfterRun(schedule: definition.schedule, timeZone: definition.timeZone, now: now),
      completedAt: definition.schedule is TaskScheduleOnce ? now : null,
      scheduledFor: _instant(at: dueAt, timeZone: definition.timeZone),
      outcome: outcome,
      firedAt: now,
    );
    if (run == null) {
      Log.i("Scheduled task ${task.id} changed while it was firing; the next pass reads it again");
      return;
    }
    await _afterReserved(task: task, run: run, scheduled: true);
  }

  Future<ScheduledTaskRun> _runNowLocked({required String taskId}) async {
    final task = await _repository.get(taskId: taskId);
    if (task == null || task.completedAt != null) _refuse(code: ScheduledTaskErrorCode.taskNotFound);
    if (await _isPreviousRunActive(taskId: task.id)) _refuse(code: ScheduledTaskErrorCode.previousRunActive);
    final now = _clock.now();
    final blocker = await _startBlocker(task: task);
    final run = await _repository.recordRun(
      taskId: task.id,
      scheduledFor: _instant(at: now, timeZone: task.definition.timeZone),
      outcome: blocker == null
          ? const ScheduledTaskRunOutcome.started(sessionId: null, late: false)
          : ScheduledTaskRunOutcome.failed(reason: blocker),
      firedAt: now,
    );
    return await _afterReserved(task: task, run: run, scheduled: false);
  }

  Future<ScheduledTaskRunOutcome> _outcomeToFire({required ScheduledTaskRecord task, required bool late}) async {
    if (await _isPreviousRunActive(taskId: task.id)) return const ScheduledTaskRunOutcome.skipped();
    final blocker = await _startBlocker(task: task);
    return blocker == null
        ? ScheduledTaskRunOutcome.started(sessionId: null, late: late)
        : ScheduledTaskRunOutcome.failed(reason: blocker);
  }

  /// Whether the session of the task's latest started run is still going.
  Future<bool> _isPreviousRunActive({required String taskId}) async {
    final sessionId = await _repository.latestStartedSessionId(taskId: taskId);
    if (sessionId == null) return false;
    // A harness reports a new turn's busy status a moment after the prompt
    // goes out, so until then the session reads quiet. A run whose prompt went
    // out this recently counts as going whatever its session reads.
    // ponytail: a run that really ends inside the grace still refuses Run now
    // until the grace passes, and a bridge restart forgets the grace; track
    // the first busy status if either bites.
    final sentAt = _promptSentAt[taskId];
    if (sentAt != null && _clock.now().difference(sentAt) < startupGrace) return true;
    return switch (await _sessions.getSessionQuietness(sessionId: sessionId)) {
      SessionQuietness.working || SessionQuietness.awaitingUser => true,
      // Unknown is no sign of a run still going, and a session its harness
      // can no longer read must not block the task for good.
      SessionQuietness.quiet || SessionQuietness.unknown => false,
    };
  }

  /// Why the task cannot start a session now, or null when it can.
  Future<TaskRunFailureReason?> _startBlocker({required ScheduledTaskRecord task}) async {
    final definition = task.definition;
    final context = "Scheduled task ${task.id} in project ${definition.projectId} with ${definition.pluginId}";
    if (await _projects.isProjectGone(projectId: definition.projectId)) {
      Log.w("$context cannot run: the project is gone");
      return TaskRunFailureReason.projectMissing;
    }
    try {
      await _sessions.ensurePluginRoutable(pluginId: definition.pluginId, operation: SessionOperation.createSession);
    } on Object catch (error, stackTrace) {
      Log.w("$context cannot run: the harness is unavailable", error, stackTrace);
      return TaskRunFailureReason.harnessUnavailable;
    }
    final model = definition.model;
    if (model != null && !await _offersModel(definition: definition, model: model, context: context)) {
      Log.w("$context cannot run: model ${model.providerID}/${model.modelID} is no longer offered");
      return TaskRunFailureReason.modelUnavailable;
    }
    return null;
  }

  /// Whether the harness's current option list still offers [model]. A list
  /// that cannot be read lets the run go ahead; the harness then reports any
  /// problem in the session.
  Future<bool> _offersModel({
    required ScheduledTaskDefinition definition,
    required PromptModel model,
    required String context,
  }) async {
    try {
      var outcome = await _sessionOptions.loadDynamic(pluginId: definition.pluginId, projectId: definition.projectId);
      if (outcome case SessionOptionsAvailable(:final response)
          when response.stale && !_offers(response: response, model: model)) {
        // An old snapshot can predate the model, so ask the harness once.
        outcome = await _sessionOptions.refreshExplicit(pluginId: definition.pluginId, projectId: definition.projectId);
      }
      return switch (outcome) {
        SessionOptionsAvailable(:final response) => _offers(response: response, model: model),
        _ => true,
      };
    } on Object catch (error, stackTrace) {
      Log.w("$context could not read the harness's models; starting the run anyway", error, stackTrace);
      return true;
    }
  }

  static bool _offers({required SessionOptionsResponse response, required PromptModel model}) =>
      response.providers.items.any(
        (provider) =>
            provider.id == model.providerID &&
            provider.models.values.any((offered) => offered.id == model.modelID && offered.isAvailable),
      );

  Future<ScheduledTaskRun> _afterReserved({
    required ScheduledTaskRecord task,
    required ScheduledTaskRun run,
    required bool scheduled,
  }) async {
    _changes.add(null);
    switch (run.outcome) {
      case ScheduledTaskRunStarted(:final late):
        return await _start(task: task, run: run, late: late, scheduled: scheduled);
      case ScheduledTaskRunFailed(:final reason):
        if (scheduled) {
          _failures.add(ScheduledTaskRunFailure(taskId: task.id, taskName: task.definition.name, reason: reason));
        }
        return run;
      case ScheduledTaskRunSkipped() || ScheduledTaskRunMissed() || ScheduledTaskRunOutcomeUnknown():
        return run;
    }
  }

  Future<ScheduledTaskRun> _start({
    required ScheduledTaskRecord task,
    required ScheduledTaskRun run,
    required bool late,
    required bool scheduled,
  }) async {
    final definition = task.definition;
    final String sessionId;
    try {
      sessionId = await _sendRunPrompt(task: task);
    } on Object catch (error, stackTrace) {
      final reason = switch (error) {
        ProjectNotFoundException() || PluginWorkingDirectoryMissingException() => TaskRunFailureReason.projectMissing,
        StaleSessionPromptOptionsException() => TaskRunFailureReason.modelUnavailable,
        _ => TaskRunFailureReason.startFailed,
      };
      Log.w(
        "Scheduled task ${task.id} could not start its run in project ${definition.projectId} "
        "with ${definition.pluginId} (${reason.name})",
        error,
        stackTrace,
      );
      final failed = run.copyWith(outcome: ScheduledTaskRunOutcome.failed(reason: reason));
      if (!await _repository.markRunFailed(runId: run.id, reason: reason)) return failed;
      _changes.add(null);
      if (scheduled) {
        _failures.add(ScheduledTaskRunFailure(taskId: task.id, taskName: definition.name, reason: reason));
      }
      return failed;
    }
    _promptSentAt[task.id] = _clock.now();
    if (await _repository.setRunSession(runId: run.id, sessionId: sessionId)) {
      _changes.add(null);
    } else {
      Log.i("Scheduled task ${task.id} was deleted while its run went to session $sessionId");
    }
    // A same-session task has one session, which it keeps.
    if (definition.runMode is TaskRunModeNewSession) {
      _archiving = _archiving.then((_) => _archiveOldRuns(taskId: task.id));
    }
    return run.copyWith(
      outcome: ScheduledTaskRunOutcome.started(sessionId: sessionId, late: late),
    );
  }

  /// Sends the run's prompt and returns the session it went to: the target of
  /// a same-session task while it can still be prompted, otherwise a new
  /// session, which a same-session task then continues in.
  Future<String> _sendRunPrompt({required ScheduledTaskRecord task}) async {
    switch (task.definition.runMode) {
      case TaskRunModeSameSession():
        if (await _promptableTarget(task: task) case final targetId?) {
          await _continueIn(sessionId: targetId, definition: task.definition);
          return targetId;
        }
        final session = await _createSession(task: task);
        if (!await _repository.setTargetSession(task: task, sessionId: session.id)) {
          Log.i(
            "Scheduled task ${task.id} changed while its run started session ${session.id}; the change keeps its target",
          );
        }
        return session.id;
      case TaskRunModeNewSession() || TaskRunModeUnknown():
        return (await _createSession(task: task)).id;
    }
  }

  /// The task's target session, or null when it has none or it is gone: a
  /// deleted target is cleared with its row, and an archived one can never be
  /// prompted again, so the run starts a fresh session (D9).
  Future<String?> _promptableTarget({required ScheduledTaskRecord task}) async {
    final targetId = task.targetSessionId;
    if (targetId == null) return null;
    final target = await _sessions.getStoredSession(sessionId: targetId);
    if (target == null || target.archivedAt != null) {
      Log.i("Scheduled task ${task.id} starts a fresh session: its session $targetId is archived or deleted");
      return null;
    }
    return targetId;
  }

  Future<Session> _createSession({required ScheduledTaskRecord task}) {
    final definition = task.definition;
    final (:command, :commandSource, :parts) = _promptOf(definition: definition);
    return _prompts.sendWithSettingsIn(
      pluginId: definition.pluginId,
      projectId: definition.projectId,
      settings: _settingsOf(definition: definition),
      send: (settings) => _sessionCreation.createScheduledRunSession(
        request: CreateSessionRequest(
          projectId: definition.projectId,
          pluginId: definition.pluginId,
          parts: parts,
          agent: settings.agent,
          model: settings.model,
          command: command,
          commandSource: commandSource,
          variant: settings.variant,
          fastMode: settings.fastMode,
          dedicatedWorktree: definition.dedicatedWorktree,
        ),
        scheduledRun: (taskId: task.id, approvalOverride: _approvalOverride(mode: definition.approvalMode)),
      ),
    );
  }

  /// Sends the prompt on [sessionId]'s lane with the task's current options,
  /// after putting the session in the task's approval mode.
  Future<void> _continueIn({required String sessionId, required ScheduledTaskDefinition definition}) async {
    await _yoloSettings.setSessionOverride(
      sessionId: sessionId,
      approvalOverride: _approvalOverride(mode: definition.approvalMode),
    );
    final (:command, :commandSource, :parts) = _promptOf(definition: definition);
    await _operations.dispatch(
      sessionId: sessionId,
      operation: command == null ? SessionOperation.sendPrompt : SessionOperation.sendCommand,
      body: () => _prompts.sendWithSettingsIn(
        pluginId: definition.pluginId,
        projectId: definition.projectId,
        settings: _settingsOf(definition: definition),
        send: (settings) => _prompts.sendPromptAlreadyReserved(
          sessionId: sessionId,
          promptId: SessionPromptService.generatePromptId(),
          parts: parts,
          variant: settings.variant,
          fastMode: settings.fastMode,
          agent: settings.agent,
          model: settings.model,
          command: command,
          commandSource: commandSource,
          handoff: null,
        ),
      ),
    );
  }

  static PromptSettings _settingsOf({required ScheduledTaskDefinition definition}) => (
    variant: definition.variant,
    fastMode: definition.fastMode,
    agent: definition.agent,
    model: definition.model,
  );

  /// Archives [taskId]'s finished run sessions beyond the newest
  /// [keptFinishedRuns] (D10). Pinned sessions are never candidates, and a
  /// session still working or waiting on the user stays. A worktree with work
  /// the usual cleanup checks refuse to remove keeps its session too.
  Future<void> _archiveOldRuns({required String taskId}) async {
    try {
      var finished = 0;
      for (final sessionId in await _sessions.listArchivableScheduledRunSessionIds(taskId: taskId)) {
        if (await _sessions.getSessionQuietness(sessionId: sessionId) != SessionQuietness.quiet) continue;
        finished += 1;
        if (finished <= keptFinishedRuns) continue;
        await _archiveOldRun(taskId: taskId, sessionId: sessionId);
      }
    } on Object catch (error, stackTrace) {
      Log.w("Scheduled task $taskId could not archive its old runs", error, stackTrace);
    }
  }

  Future<void> _archiveOldRun({required String taskId, required String sessionId}) async {
    try {
      await _lifecycle.updateArchiveStatus(sessionId: sessionId, archived: true, deleteWorktree: true, force: false);
      Log.i("Scheduled task $taskId archived its old run session $sessionId");
    } on SessionArchiveConflictException catch (error) {
      Log.i(
        "Scheduled task $taskId keeps its old run session $sessionId: "
        "its worktree cleanup was refused (${error.rejection.issues})",
      );
    } on Object catch (error, stackTrace) {
      Log.w("Scheduled task $taskId could not archive its old run session $sessionId", error, stackTrace);
    }
  }

  ScheduledTaskInstant _instant({required DateTime at, required String timeZone}) => ScheduledTaskInstant(
    at: at.millisecondsSinceEpoch,
    offsetMinutes: _calculator.offsetMinutesAt(instant: at, timeZone: timeZone),
  );

  static ({String? command, CommandSource? commandSource, List<PromptPart> parts}) _promptOf({
    required ScheduledTaskDefinition definition,
  }) {
    final (command, commandSource, text) = switch (definition.prompt) {
      ScheduledTaskPromptText(:final text) => (null, null, text),
      ScheduledTaskPromptCommand(:final name, :final source, :final arguments) => (name, source, arguments),
      ScheduledTaskPromptUnknown() => throw StateError("a saved task has an unknown prompt kind"),
    };
    return (command: command, commandSource: commandSource, parts: [if (text != null) PromptPart.text(text: text)]);
  }

  static SessionApprovalMode _approvalOverride({required TaskApprovalMode mode}) => switch (mode) {
    TaskApprovalMode.approveAll => SessionApprovalMode.yolo,
    // Saving refuses an unknown mode; asking is the safe reading.
    TaskApprovalMode.ask || TaskApprovalMode.unknown => SessionApprovalMode.ask,
  };

  static Never _refuse({required ScheduledTaskErrorCode code}) => throw ScheduledTaskRequestException(code: code);
}
