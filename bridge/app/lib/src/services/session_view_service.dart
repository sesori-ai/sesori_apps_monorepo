import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";
import "package:sesori_tool_pr_monitor/sesori_tool_pr_monitor.dart" show PullRequestWatchRepository;

import "../repositories/bridge_settings_repository.dart";
import "../repositories/models/sesori_tool_group_ids.dart";
import "../repositories/models/session_continuation_record.dart";
import "../repositories/models/session_wake_up.dart";
import "../repositories/scheduled_task_repository.dart";
import "../repositories/session_continuation_repository.dart";
import "../repositories/session_interruption_repository.dart";
import "../repositories/session_repository.dart";
import "../repositories/session_wake_up_repository.dart";

/// Projects bridge-owned continuation, interruption and wake-up state,
/// scheduled-run marks, arming and watched PRs onto existing session
/// responses. Watched PRs are left out while the user has the PR monitor
/// off, since their statuses stop following GitHub then.
class const SessionViewService({
  required final SessionRepository _sessions,
  required final SessionContinuationRepository _continuations,
  required final ScheduledTaskRepository _scheduledTasks,
  required final SessionInterruptionRepository _interruptions,
  required final SessionWakeUpRepository _wakeUps,
  required final PullRequestWatchRepository _pullRequestWatches,
  required final BridgeSettingsRepository _settings,
  required final Duration _resetBuffer,
}) {
  Future<Session> get({required String sessionId}) async {
    final session = await _sessions.getCatalogSession(sessionId: sessionId);
    if (session == null) {
      throw PluginOperationException.notFound(operation: "getSession", message: "session $sessionId was not found");
    }
    return await enrich(session: session);
  }

  Future<Session> enrich({required Session session}) async => (await enrichMany(sessions: [session])).single;

  Future<List<Session>> enrichMany({required List<Session> sessions}) async {
    final sessionIds = sessions.map((session) => session.id).toSet();
    final records = await _continuations.readMany(sessionIds: sessionIds);
    final marks = await _scheduledTasks.marksOfSessions(sessionIds: sessionIds);
    final interruptions = await _interruptions.readMany(sessionIds: sessionIds);
    final wakeUps = await _wakeUps.forSessions(sessionIds: sessionIds);
    final upcomingRuns = await _scheduledTasks.upcomingRunsInSessions(sessionIds: sessionIds);
    final pullRequestWatches = await _shownPullRequestWatches();
    return [
      for (final session in sessions)
        session.copyWith(
          wakeUps: [
            for (final wakeUp in wakeUps[session.id] ?? const <StoredSessionWakeUp>[])
              SessionWakeUp(
                id: wakeUp.id,
                nextDueAt: wakeUp.nextDueAt.millisecondsSinceEpoch,
                label: wakeUp.label,
                repeats: wakeUp.schedule is! WakeUpOnce,
                runsCommand: wakeUp.command != null,
              ),
          ],
          arming: _arming(
            session: session,
            soonestWakeUp: wakeUps[session.id]?.first,
            upcomingRun: upcomingRuns[session.id],
          ),
          pullRequestWatches: pullRequestWatches[session.id] ?? const [],
          autoContinuation: _view(session: session, record: records[session.id]),
          scheduledTask: marks[session.id],
          interruption: switch (interruptions[session.id]) {
            null => null,
            final interruption => SessionInterruption(
              afterMessageId: interruption.afterMessageId,
              unacknowledged: !interruption.acknowledged,
            ),
          },
        ),
    ];
  }

  /// Every PR this bridge watches, with its session. A watch whose session
  /// is gone is left out.
  Future<PullRequestWatchListResponse> pullRequestWatches() async => PullRequestWatchListResponse(
    watches: [
      for (final MapEntry(key: sessionId, value: watches) in (await _shownPullRequestWatches()).entries)
        if (await _sessions.getCatalogSession(sessionId: sessionId) case final session?)
          for (final watch in watches)
            PullRequestWatchListItem(
              sessionId: sessionId,
              sessionTitle: session.title,
              projectId: session.projectID,
              watch: watch,
            ),
    ],
  );

  /// The stored watches by session, or none while the PR monitor is off.
  /// The monitor republishes their sessions when it is turned on or off.
  Future<Map<String, List<SessionPullRequestWatch>>> _shownPullRequestWatches() async {
    if (!_settings.currentSettings.toolGroupEnabled(id: SesoriToolGroupIds.prMonitor)) return const {};
    return await _pullRequestWatches.watchesBySession();
  }

  /// The soonest of the session's wake-ups and the next run of a task that
  /// continues in it. An archived session is not armed: a task starts a fresh
  /// session instead, and a wake-up that falls due is removed unsent.
  SessionArming _arming({
    required Session session,
    required StoredSessionWakeUp? soonestWakeUp,
    required UpcomingTaskRun? upcomingRun,
  }) {
    if (session.time?.archived != null) return const SessionArming.notArmed();
    return switch ((soonestWakeUp, upcomingRun)) {
      (null, null) => const SessionArming.notArmed(),
      (final wakeUp?, final run?) when run.dueAt.isBefore(wakeUp.nextDueAt) => _armedByTask(run: run),
      (final wakeUp?, _) => SessionArming.armed(name: wakeUp.label, nextAt: wakeUp.nextDueAt.millisecondsSinceEpoch),
      (null, final run?) => _armedByTask(run: run),
    };
  }

  static SessionArming _armedByTask({required UpcomingTaskRun run}) =>
      SessionArming.armed(name: run.taskName, nextAt: run.dueAt.millisecondsSinceEpoch);

  SessionAutoContinuationView _view({required Session session, required SessionContinuationRecord? record}) =>
      SessionAutoContinuationView(
        enabled: record?.enabled ?? false,
        availability: _sessions.quotaReportingAvailability(pluginId: session.pluginId),
        status: switch (record?.outcome) {
          null ||
          SessionContinuationNone() ||
          SessionContinuationCancelled() => const SessionAutoContinuationStatus.idle(),
          SessionContinuationResetKnown(:final resetAt) => SessionAutoContinuationStatus.resetKnown(
            resetAt: resetAt.millisecondsSinceEpoch,
            continueAt: resetAt.add(_resetBuffer).millisecondsSinceEpoch,
          ),
          SessionContinuationResetUnknown() => const SessionAutoContinuationStatus.resetUnknown(),
          SessionContinuationPaused(:final resetAt, :final reason) => SessionAutoContinuationStatus.paused(
            resetAt: resetAt.millisecondsSinceEpoch,
            continueAt: resetAt.add(_resetBuffer).millisecondsSinceEpoch,
            reason: reason,
          ),
          SessionContinuationConsumed() => const SessionAutoContinuationStatus.attemptUnconfirmed(),
          SessionContinuationSubmitted(:final acceptedAt) => SessionAutoContinuationStatus.submitted(
            acceptedAt: acceptedAt.millisecondsSinceEpoch,
          ),
          SessionContinuationSubmissionFailed(:final reason) => SessionAutoContinuationStatus.submissionFailed(
            reason: reason,
          ),
        },
      );
}
