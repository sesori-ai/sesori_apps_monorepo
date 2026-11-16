import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show ParallelLock;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/project_not_found_exception.dart";
import "../repositories/models/scheduled_task_record.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/models/session_quietness.dart";
import "../repositories/scheduled_task_repository.dart";
import "../repositories/session_repository.dart";
import "scheduled_task_occurrence_calculator.dart";
import "scheduled_task_request_exception.dart";
import "scheduled_task_run_failure.dart";
import "session_creation_service.dart";
import "session_options_service.dart";
import "stale_session_prompt_options_exception.dart";

/// Fires tasks: every due task on each timer pass, and one task on Run now.
///
/// A fire writes its history row, with the task's advanced next due time, in
/// one transaction before the session is created, so a crash can lose a run
/// but never start one twice. Every history row written is announced on
/// [changes], and every run that could not start on [failures].
class ScheduledTaskRunService({
  required final ScheduledTaskRepository _repository,
  required final SessionCreationService _sessionCreation,
  required final SessionRepository _sessions,
  required final SessionOptionsService _sessionOptions,
  required final ScheduledTaskOccurrenceCalculator _calculator,
  required final Clock _clock,
}) {
  /// Serializes every pass and Run now, so no two fire the same task.
  final ParallelLock _lock = ParallelLock(maxParallelOperations: 1);
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

  Future<void> dispose() async {
    await _lock.idle;
    await Future.wait([_changes.close(), _failures.close()]);
  }

  Future<void> _runDueLocked() async {
    for (final (:task, :dueAt) in await _repository.listDue(now: _clock.now())) {
      // Same-session tasks need their target session flow and are not fired
      // yet; they stay due until it lands.
      if (task.definition.runMode is! TaskRunModeNewSession) continue;
      try {
        await _fireDue(task: task, dueAt: dueAt);
      } on Object catch (error, stackTrace) {
        Log.w("Scheduled task ${task.id} in project ${task.definition.projectId} could not fire", error, stackTrace);
      }
    }
  }

  Future<void> _fireDue({required ScheduledTaskRecord task, required DateTime dueAt}) async {
    final definition = task.definition;
    final now = _clock.now();
    final action = _calculator.dueAction(
      schedule: definition.schedule,
      missedRunPolicy: definition.missedRunPolicy,
      dueAt: dueAt,
      now: now,
    );
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
    await _afterReserved(task: task, run: run);
  }

  Future<ScheduledTaskRun> _runNowLocked({required String taskId}) async {
    final task = await _repository.get(taskId: taskId);
    if (task == null || task.completedAt != null) _refuse(code: ScheduledTaskErrorCode.taskNotFound);
    if (task.definition.runMode is! TaskRunModeNewSession) _refuse(code: ScheduledTaskErrorCode.unsupportedByBridge);
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
    return await _afterReserved(task: task, run: run);
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
    if (await _sessions.getProjectPath(projectId: definition.projectId) == null) {
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

  Future<ScheduledTaskRun> _afterReserved({required ScheduledTaskRecord task, required ScheduledTaskRun run}) async {
    _changes.add(null);
    switch (run.outcome) {
      case ScheduledTaskRunStarted(:final late):
        return await _start(task: task, run: run, late: late);
      case ScheduledTaskRunFailed(:final reason):
        _failures.add(ScheduledTaskRunFailure(taskId: task.id, taskName: task.definition.name, reason: reason));
        return run;
      case ScheduledTaskRunSkipped() || ScheduledTaskRunMissed() || ScheduledTaskRunOutcomeUnknown():
        return run;
    }
  }

  Future<ScheduledTaskRun> _start({
    required ScheduledTaskRecord task,
    required ScheduledTaskRun run,
    required bool late,
  }) async {
    final definition = task.definition;
    final Session session;
    try {
      session = await _sessionCreation.createScheduledRunSession(
        request: _createRequest(definition: definition),
        scheduledRun: (taskId: task.id, approvalOverride: _approvalOverride(mode: definition.approvalMode)),
      );
    } on Object catch (error, stackTrace) {
      final reason = switch (error) {
        ProjectNotFoundException() => TaskRunFailureReason.projectMissing,
        StaleSessionPromptOptionsException() => TaskRunFailureReason.modelUnavailable,
        _ => TaskRunFailureReason.startFailed,
      };
      Log.w(
        "Scheduled task ${task.id} could not start a session in project ${definition.projectId} "
        "with ${definition.pluginId} (${reason.name})",
        error,
        stackTrace,
      );
      final failed = run.copyWith(outcome: ScheduledTaskRunOutcome.failed(reason: reason));
      if (!await _repository.markRunFailed(runId: run.id, reason: reason)) return failed;
      _changes.add(null);
      _failures.add(ScheduledTaskRunFailure(taskId: task.id, taskName: definition.name, reason: reason));
      return failed;
    }
    if (await _repository.setRunSession(runId: run.id, sessionId: session.id)) {
      _changes.add(null);
    } else {
      Log.i("Scheduled task ${task.id} was deleted while its run started session ${session.id}");
    }
    return run.copyWith(
      outcome: ScheduledTaskRunOutcome.started(sessionId: session.id, late: late),
    );
  }

  ScheduledTaskInstant _instant({required DateTime at, required String timeZone}) => ScheduledTaskInstant(
    at: at.millisecondsSinceEpoch,
    offsetMinutes: _calculator.offsetMinutesAt(instant: at, timeZone: timeZone),
  );

  static CreateSessionRequest _createRequest({required ScheduledTaskDefinition definition}) {
    final (command, commandSource, text) = switch (definition.prompt) {
      ScheduledTaskPromptText(:final text) => (null, null, text),
      ScheduledTaskPromptCommand(:final name, :final source, :final arguments) => (name, source, arguments),
      ScheduledTaskPromptUnknown() => throw StateError("a saved task has an unknown prompt kind"),
    };
    return CreateSessionRequest(
      projectId: definition.projectId,
      pluginId: definition.pluginId,
      parts: [if (text != null) PromptPart.text(text: text)],
      agent: definition.agent,
      model: definition.model,
      command: command,
      commandSource: commandSource,
      variant: definition.variant,
      fastMode: definition.fastMode,
      dedicatedWorktree: definition.dedicatedWorktree,
    );
  }

  static SessionApprovalMode _approvalOverride({required TaskApprovalMode mode}) => switch (mode) {
    TaskApprovalMode.approveAll => SessionApprovalMode.yolo,
    // Saving refuses an unknown mode; asking is the safe reading.
    TaskApprovalMode.ask || TaskApprovalMode.unknown => SessionApprovalMode.ask,
  };

  static Never _refuse({required ScheduledTaskErrorCode code}) => throw ScheduledTaskRequestException(code: code);
}
