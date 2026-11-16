import "package:clock/clock.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/scheduled_task_record.dart";
import "../repositories/models/session_compaction_result.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/models/session_quietness.dart";
import "../repositories/scheduled_task_repository.dart";
import "../repositories/session_repository.dart";
import "scheduled_task_activity_tracker.dart";
import "scheduled_task_occurrence_calculator.dart";
import "session_operation_dispatcher.dart";
import "session_prompt_service.dart";

/// What a same-session task's due run does about its session's compaction.
enum DueRunGate() {
  /// Wait: a compaction was just asked for or may still be running.
  hold,

  /// Fire as usual.
  fire,

  /// Fire. A compaction asked for while the run was still on time held it,
  /// so the run counts as late, never as missed.
  fireAfterCompaction,
}

/// Auto-compact for same-session tasks. After a run, it compacts the task's
/// session once the session has been quiet long enough that the harness's
/// prompt cache is about to go cold, so the next run reads a short summary
/// instead of the whole uncached history. A run that falls due before that
/// compacts first. Each run's session is asked at most once.
class ScheduledTaskCompactionService({
  required final ScheduledTaskRepository _repository,
  required final SessionRepository _sessions,
  required final SessionOperationDispatcher _operations,
  required final ScheduledTaskActivityTracker _activity,
  required final Clock _clock,
}) {
  /// How long before the cache goes cold the compaction is sent, so the
  /// compaction itself still reads the cache warm.
  static const Duration cacheMargin = Duration(minutes: 2);

  /// The longest quiet wait, and the wait when the harness cannot tell its
  /// cache life.
  static const Duration longestQuietWindow = Duration(minutes: 25);

  /// How long a due run waits for its session's compaction to finish.
  static const Duration compactionWait = Duration(minutes: 10);

  /// Compacts the session of each auto-compact task whose latest run has
  /// been quiet for its window, unless the user has prompted in it since.
  Future<void> compactQuietRuns() async {
    for (final task in await _repository.listUncompleted()) {
      if (!task.enabled || !_autoCompacts(task: task)) continue;
      try {
        final run = await _repository.latestStartedRun(taskId: task.id);
        if (run == null || run.compactRequestedAt != null || run.userPromptedAt != null) continue;
        final activity = _activity.lastActivity(sessionId: run.sessionId);
        final lastUse = activity.isAfter(run.firedAt) ? activity : run.firedAt;
        if (_clock.now().difference(lastUse) < await _quietWindow(sessionId: run.sessionId)) continue;
        if (!await _isUnarchived(sessionId: run.sessionId)) continue;
        await _compact(task: task, run: run, afterRun: true);
      } on Object catch (error, stackTrace) {
        Log.w("Scheduled task ${task.id} could not check its session for auto-compact", error, stackTrace);
      }
    }
  }

  /// What [task]'s run due at [dueAt] does. Nothing compacted the session
  /// since its last run: compact it first and hold the run. A compaction was
  /// asked for: hold the run while the session works, up to
  /// [compactionWait] after the ask.
  Future<DueRunGate> gateDueRun({required ScheduledTaskRecord task, required DateTime dueAt}) async {
    if (!_autoCompacts(task: task)) return DueRunGate.fire;
    final run = await _repository.latestStartedRun(taskId: task.id);
    if (run == null || !await _isUnarchived(sessionId: run.sessionId)) return DueRunGate.fire;
    final quietness = await _sessions.getSessionQuietness(sessionId: run.sessionId);
    final requestedAt = run.compactRequestedAt;
    if (requestedAt == null) {
      if (quietness != SessionQuietness.quiet) return DueRunGate.fire;
      final result = await _compact(task: task, run: run, afterRun: false);
      return result == SessionCompactionResult.accepted ? DueRunGate.hold : DueRunGate.fire;
    }
    final busy = quietness == SessionQuietness.working || quietness == SessionQuietness.awaitingUser;
    if (busy && _clock.now().isBefore(requestedAt.add(compactionWait))) return DueRunGate.hold;
    final heldRun =
        !requestedAt.isAfter(dueAt.add(ScheduledTaskOccurrenceCalculator.onTimeGrace)) &&
        requestedAt.add(compactionWait).isAfter(dueAt);
    return heldRun ? DueRunGate.fireAfterCompaction : DueRunGate.fire;
  }

  static bool _autoCompacts({required ScheduledTaskRecord task}) => switch (task.definition.runMode) {
    TaskRunModeSameSession(:final autoCompact) => autoCompact,
    TaskRunModeNewSession() || TaskRunModeUnknown() => false,
  };

  Future<bool> _isUnarchived({required String sessionId}) async {
    final session = await _sessions.getStoredSession(sessionId: sessionId);
    return session != null && session.archivedAt == null;
  }

  /// Leaves the margin before the cache goes cold, capped at
  /// [longestQuietWindow].
  Future<Duration> _quietWindow({required String sessionId}) async {
    final life = await _sessions.getPromptCacheLife(sessionId: sessionId);
    if (life == null) return longestQuietWindow;
    final window = life - cacheMargin;
    return window < longestQuietWindow ? window : longestQuietWindow;
  }

  /// Asks the harness to compact [run]'s session on the session's lane, after
  /// checking again there that nothing reached the session first. Records the
  /// ask on every answer but busy, and on a failed send, so no later pass
  /// asks again for this run. Null when it did not ask.
  Future<SessionCompactionResult?> _compact({
    required ScheduledTaskRecord task,
    required StartedRunState run,
    required bool afterRun,
  }) => _operations.dispatch(
    sessionId: run.sessionId,
    operation: SessionOperation.compactSession,
    body: () async {
      final current = await _repository.latestStartedRun(taskId: task.id);
      if (current == null || current.runId != run.runId || current.compactRequestedAt != null) return null;
      if (afterRun && current.userPromptedAt != null) return null;
      if (await _sessions.getSessionQuietness(sessionId: run.sessionId) != SessionQuietness.quiet) return null;
      final askedAt = _clock.now();
      final SessionCompactionResult result;
      try {
        result = await _sessions.compactSession(
          sessionId: run.sessionId,
          promptId: SessionPromptService.generatePromptId(),
        );
      } on Object catch (error, stackTrace) {
        Log.w("Scheduled task ${task.id} could not compact session ${run.sessionId}; not retrying", error, stackTrace);
        await _repository.recordCompactRequested(runId: run.runId, at: askedAt);
        return null;
      }
      Log.i("Scheduled task ${task.id} asked to compact session ${run.sessionId}: ${result.name}");
      if (result != SessionCompactionResult.sessionBusy) {
        await _repository.recordCompactRequested(runId: run.runId, at: askedAt);
      }
      return result;
    },
  );
}
