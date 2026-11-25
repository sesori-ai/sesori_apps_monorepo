import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_tool_interface/sesori_tool_interface.dart";

import "../models/gh_cli_exception.dart";
import "../models/pull_request_target.dart";
import "../repositories/models/pull_request_ci_phase.dart";
import "../repositories/models/pull_request_snapshot.dart";
import "../repositories/models/stored_pull_request_watch.dart";
import "../repositories/pull_request_action_repository.dart";
import "../repositories/pull_request_snapshot_repository.dart";
import "../repositories/pull_request_watch_repository.dart";
import "models/pull_request_watch_results.dart";
import "pull_request_activity_calculator.dart";
import "pull_request_readiness_calculator.dart";
import "pull_request_report_builder.dart";

/// Owns every watch at run time: one shared poll per PR, fanned out to each
/// session that watches it, with reports rendered against each session's own
/// baseline (spec §3–§5).
///
/// Each PR's polls and tool calls run one at a time on its queue. A report
/// is claimed right before the send only while its watch still has the
/// baseline it was rendered against, and becomes the new baseline once sent,
/// so a restart resumes from the stored baselines.
class PullRequestWatchService({
  required final PullRequestSnapshotRepository _snapshots,
  required final PullRequestActionRepository _actions,
  required final PullRequestWatchRepository _watches,
  required final SesoriToolHost _host,
  required final PullRequestActivityCalculator _activity,
  required final PullRequestReadinessCalculator _readiness,
  required final PullRequestReportBuilder _reports,
  required final Clock _clock,
}) {
  static const Duration pollInterval = Duration(seconds: 60);

  /// How long a report waits after the latest activity, so a burst arrives
  /// as one report.
  static const Duration quietWindow = Duration(minutes: 2);

  /// How long a due report waits for running CI before it goes out anyway.
  static const Duration ciWait = Duration(minutes: 30);
  static const Duration idleReminderDelay = Duration(minutes: 25);
  static const int maxConsecutiveFailures = 10;

  /// By the PR's registry key.
  final Map<String, _PullRequestRuntime> _runtimes = {};

  /// The session a caller's watches belong to: its family's root, as for
  /// wake-ups. Null when Sesori no longer knows the caller.
  Future<String?> watchSessionOf({required SesoriToolCaller caller}) async =>
      (await _host.sessions(sessionIds: {caller.sessionId}))[caller.sessionId]?.rootSessionId;

  /// Loads every stored watch. Each PR's first poll then compares each
  /// watch's stored baseline with GitHub, so what changed while the bridge
  /// was off is reported.
  Future<void> resume() async {
    for (final (:sessionId, :watch) in await _watches.loadAll()) {
      _runtimeOf(
        target: PullRequestTarget(owner: watch.owner, repo: watch.repo, number: watch.number),
      ).watches.putIfAbsent(sessionId, () => _Watch(sessionId: sessionId, stored: watch, resumed: true));
    }
  }

  Future<PullRequestWatchStart> watch({required String sessionId, required PullRequestTarget target}) async {
    final String selfLogin;
    try {
      selfLogin = await _actions.selfLogin();
    } on GhCliException catch (error) {
      return PullRequestIdentityFailed(error: error);
    }
    final runtime = _runtimeOf(target: target);
    return await _run(
      runtime: runtime,
      operation: () async {
        if (runtime.watches[sessionId] case final existing?) {
          return PullRequestAlreadyWatched(
            status: _status(runtime: runtime, watch: existing),
          );
        }
        final PullRequestSnapshot snapshot;
        try {
          snapshot = await _snapshots.fetchSnapshot(target: target, selfLogin: selfLogin);
        } on Exception catch (error) {
          return PullRequestFetchFailed(error: error);
        }
        _applySnapshot(runtime: runtime, snapshot: snapshot);
        if (snapshot.state != PullRequestState.open) return PullRequestAlreadyEnded(state: snapshot.state);
        final stored = StoredPullRequestWatch(
          owner: target.owner,
          repo: target.repo,
          number: target.number,
          title: snapshot.title,
          autoMerge: false,
          baseline: _activity.baselineOf(snapshot: snapshot),
          lastReportAt: _clock.now(),
        );
        await _watches.save(sessionId: sessionId, watch: stored);
        runtime.watches[sessionId] = _Watch(sessionId: sessionId, stored: stored, resumed: false);
        return PullRequestWatchStarted(
          title: snapshot.title,
          report: _reports.buildReport(
            target: runtime.target,
            snapshot: snapshot,
            baseline: null,
            forcedHoldMinutes: null,
            autoMergeEnabled: _autoMerge(runtime: runtime),
            opening: PullRequestReportOpening.watchStarted,
          ),
        );
      },
    );
  }

  /// Ends [sessionId]'s watch of [target] at once, without waiting for a
  /// poll in progress; false when there was none.
  Future<bool> unwatch({required String sessionId, required PullRequestTarget target}) async {
    final runtime = _runtimes[target.registryKey];
    final removed = runtime?.watches.remove(sessionId) != null;
    if (runtime != null) _dropIfUnused(runtime: runtime);
    final deleted = await _watches.delete(sessionId: sessionId, target: target);
    return removed || deleted;
  }

  PullRequestWatchStatuses statusOf({required String sessionId}) => PullRequestWatchStatuses(
    watches: [
      for (final runtime in _runtimes.values)
        if (runtime.watches[sessionId] case final watch?) _status(runtime: runtime, watch: watch),
    ],
    watchedPullRequests: _runtimes.values.where((runtime) => runtime.watches.isNotEmpty).length,
  );

  /// Fetches [target] now and renders [sessionId]'s report, which then
  /// counts as delivered to it. Other sessions' reports are unaffected.
  Future<PullRequestReportResult> report({required String sessionId, required PullRequestTarget target}) async {
    final runtime = _runtimes[target.registryKey];
    if (runtime == null || !runtime.watches.containsKey(sessionId)) return const PullRequestNotWatched();
    return await _run(
      runtime: runtime,
      operation: () async {
        final watch = runtime.watches[sessionId];
        if (watch == null) return const PullRequestNotWatched();
        try {
          final snapshot = await _snapshots.fetchSnapshot(
            target: runtime.target,
            selfLogin: await _actions.selfLogin(),
          );
          _applySnapshot(runtime: runtime, snapshot: snapshot);
        } on Exception catch (error) {
          return switch (runtime.snapshot) {
            null => PullRequestReportUnavailable(error: error),
            final previous => PullRequestReportStale(
              report: _render(runtime: runtime, watch: watch, snapshot: previous, forcedHoldMinutes: null),
              error: error,
            ),
          };
        }
        final snapshot = runtime.snapshot;
        // An unwatch while the fetch ran must not be undone.
        if (snapshot == null || !_isCurrent(runtime: runtime, watch: watch)) return const PullRequestNotWatched();
        final report = _render(runtime: runtime, watch: watch, snapshot: snapshot, forcedHoldMinutes: null);
        await _recordReport(runtime: runtime, watch: watch, snapshot: snapshot);
        return PullRequestReportFresh(report: report);
      },
    );
  }

  /// Polls each watched PR whose last poll is [pollInterval] old, one at a
  /// time, and sends the reports and reminders that are due. A PR whose
  /// previous operation still runs waits for the next call.
  Future<void> pollDue() async {
    await _dropInactiveWatches();
    final now = _clock.now();
    for (final runtime in [..._runtimes.values]) {
      final lastPolledAt = runtime.lastPolledAt;
      if (runtime.pendingOperations > 0 || (lastPolledAt != null && now.difference(lastPolledAt) < pollInterval)) {
        continue;
      }
      await _run(
        runtime: runtime,
        operation: () => _poll(runtime: runtime),
      );
    }
  }

  /// Ends watches whose session was archived or deleted, with one lookup
  /// for every watching session.
  Future<void> _dropInactiveWatches() async {
    final sessionIds = {for (final runtime in _runtimes.values) ...runtime.watches.keys};
    if (sessionIds.isEmpty) return;
    final sessions = await _host.sessions(sessionIds: sessionIds);
    for (final runtime in [..._runtimes.values]) {
      for (final sessionId in [...runtime.watches.keys]) {
        if (sessions[sessionId] case SesoriToolSession(archived: false)) continue;
        await _endWatch(runtime: runtime, sessionId: sessionId);
      }
    }
  }

  Future<void> _poll({required _PullRequestRuntime runtime}) async {
    if (runtime.watches.isEmpty) return;
    runtime.lastPolledAt = _clock.now();
    final PullRequestSnapshot snapshot;
    try {
      snapshot = await _snapshots.fetchSnapshot(target: runtime.target, selfLogin: await _actions.selfLogin());
    } on GhCliNotFoundException catch (error) {
      await _stopAll(
        runtime: runtime,
        reason: "Monitor stopped: PR not found (deleted or inaccessible). Last error: ${error.message}",
      );
      return;
    } on Exception catch (error, stackTrace) {
      runtime.consecutiveFailures++;
      Log.w(
        "PR monitor: poll of ${runtime.target.displayKey} failed "
        "(${runtime.consecutiveFailures}/$maxConsecutiveFailures)",
        error,
        stackTrace,
      );
      if (runtime.consecutiveFailures >= maxConsecutiveFailures) {
        await _stopAll(
          runtime: runtime,
          reason: "Monitor stopped: $maxConsecutiveFailures consecutive poll failures. Last error: $error",
        );
      }
      return;
    }
    runtime.consecutiveFailures = 0;
    _applySnapshot(runtime: runtime, snapshot: snapshot);
    _sendDue(runtime: runtime, snapshot: snapshot);
  }

  /// Updates the PR's activity clock from [snapshot] (spec §4). The first
  /// snapshot after a restart is compared with each watch's stored baseline
  /// instead of a previous poll.
  void _applySnapshot({required _PullRequestRuntime runtime, required PullRequestSnapshot snapshot}) {
    final previous = runtime.snapshot;
    var activity = false;
    var ciFailure = false;
    var ended = false;
    var conflict = false;
    if (previous == null) {
      for (final watch in runtime.watches.values) {
        final baseline = watch.stored.baseline;
        if (_activity.covers(baseline: baseline, snapshot: snapshot)) {
          watch.resumed = false;
          continue;
        }
        activity = true;
        ciFailure = ciFailure || _activity.hasNewCiFailureSince(baseline: baseline, next: snapshot);
        ended = ended || (baseline.state == PullRequestState.open && snapshot.state != PullRequestState.open);
        conflict =
            conflict ||
            _activity.hasNewMergeConflict(
              lastDefiniteMergeable: baseline.mergeable == PullRequestMergeable.unknown ? null : baseline.mergeable,
              next: snapshot,
            );
      }
    } else {
      activity = _activity.detectActivity(
        previous: previous,
        next: snapshot,
        lastDefiniteMergeable: runtime.lastDefiniteMergeable,
      );
      ciFailure = _activity.hasNewCiFailure(previous: previous, next: snapshot);
      ended = previous.state == PullRequestState.open && snapshot.state != PullRequestState.open;
      conflict = _activity.hasNewMergeConflict(lastDefiniteMergeable: runtime.lastDefiniteMergeable, next: snapshot);
    }
    if (activity) {
      runtime
        ..dirty = true
        ..lastActivityAt = _clock.now()
        ..holdStartedAt = null;
    }
    // A failing check reports at once, but only once per head.
    final urgentCiFailure =
        ciFailure && snapshot.state == PullRequestState.open && runtime.ciFailureReportedSha != snapshot.headSha;
    if (urgentCiFailure) runtime.ciFailureReportedSha = snapshot.headSha;
    if (urgentCiFailure || conflict || ended) {
      runtime
        ..dirty = true
        ..urgent = true
        ..holdStartedAt = null;
    }
    runtime
      ..snapshot = snapshot
      ..lastPolledAt = _clock.now();
    if (snapshot.mergeable != PullRequestMergeable.unknown) runtime.lastDefiniteMergeable = snapshot.mergeable;
  }

  /// Sends each watch its report once one is due, or its idle reminder.
  void _sendDue({required _PullRequestRuntime runtime, required PullRequestSnapshot snapshot}) {
    final now = _clock.now();
    if (!runtime.dirty) {
      _sendIdleReminders(runtime: runtime, snapshot: snapshot, now: now);
      return;
    }
    int? forcedHoldMinutes;
    if (!runtime.urgent) {
      if (now.difference(runtime.lastActivityAt) < quietWindow) return;
      if (snapshot.state == PullRequestState.open &&
          _activity.ciPhase(snapshot: snapshot) == PullRequestCiPhase.running) {
        final held = now.difference(runtime.holdStartedAt ??= now);
        if (held < ciWait) return;
        forcedHoldMinutes = held.inMinutes;
      }
    }
    // A watch whose previous report still waits gets this activity in its
    // next one, so the PR stays due until every watch has had it.
    var waiting = false;
    for (final watch in [...runtime.watches.values]) {
      if (watch.delivering) {
        waiting = true;
      } else if (!_activity.covers(baseline: watch.stored.baseline, snapshot: snapshot)) {
        _deliverReport(runtime: runtime, watch: watch, snapshot: snapshot, forcedHoldMinutes: forcedHoldMinutes);
      }
    }
    if (!waiting) {
      runtime
        ..dirty = false
        ..urgent = false
        ..holdStartedAt = null;
    }
  }

  void _deliverReport({
    required _PullRequestRuntime runtime,
    required _Watch watch,
    required PullRequestSnapshot snapshot,
    required int? forcedHoldMinutes,
  }) {
    _deliver(
      runtime: runtime,
      watch: watch,
      summary: _reports.buildReportSummary(target: runtime.target, snapshot: snapshot, baseline: watch.stored.baseline),
      guidance: _render(runtime: runtime, watch: watch, snapshot: snapshot, forcedHoldMinutes: forcedHoldMinutes),
      timing: SesoriToolNoticeTiming.derived,
      onSent: () => _recordReport(runtime: runtime, watch: watch, snapshot: snapshot),
      // The baseline stayed, so the PR's next poll reports it again.
      onDropped: () => runtime.dirty = true,
    );
  }

  /// Nudges each watch of an open PR that has had no activity and no report
  /// for [idleReminderDelay], unless it was handed to a human: ready with
  /// auto-merge off.
  void _sendIdleReminders({
    required _PullRequestRuntime runtime,
    required PullRequestSnapshot snapshot,
    required DateTime now,
  }) {
    final autoMerge = _autoMerge(runtime: runtime);
    if (snapshot.state != PullRequestState.open || (!autoMerge && _readiness.hasReadyLabel(snapshot: snapshot))) {
      return;
    }
    for (final watch in [...runtime.watches.values]) {
      final lastReportAt = watch.stored.lastReportAt;
      final idle = now.difference(lastReportAt.isAfter(runtime.lastActivityAt) ? lastReportAt : runtime.lastActivityAt);
      if (watch.delivering || idle < idleReminderDelay) continue;
      _deliver(
        runtime: runtime,
        watch: watch,
        summary: _reports.buildIdleReminderSummary(target: runtime.target),
        guidance: _reports.buildIdleReminder(
          target: runtime.target,
          snapshot: snapshot,
          idleMinutes: idle.inMinutes,
          autoMergeEnabled: autoMerge,
        ),
        timing: SesoriToolNoticeTiming.afterTurn,
        // Repeats one delay later while the PR stays still.
        onSent: () => _saveIfCurrent(
          runtime: runtime,
          watch: watch,
          stored: watch.stored.copyWith(lastReportAt: _clock.now()),
        ),
        // The reminder's time stayed, so the next poll tries again.
        onDropped: () {},
      );
    }
  }

  void _deliver({
    required _PullRequestRuntime runtime,
    required _Watch watch,
    required String summary,
    required String guidance,
    required SesoriToolNoticeTiming timing,
    required Future<bool> Function() onSent,
    required void Function() onDropped,
  }) {
    watch.delivering = true;
    // A get_pr_report while this waited already told the session more.
    final queued = watch.stored;
    bool unchanged() => _isCurrent(runtime: runtime, watch: watch) && identical(watch.stored, queued);
    unawaited(
      () async {
        try {
          final outcome = await _host.deliverNotice(
            sessionId: watch.sessionId,
            summary: summary,
            guidance: guidance,
            timing: timing,
            claim: () async => unchanged(),
          );
          switch (outcome) {
            case SesoriToolNoticeOutcome.sent:
              if (unchanged()) await onSent();
            case SesoriToolNoticeOutcome.claimLost:
              break;
            case SesoriToolNoticeOutcome.skippedInactive:
              if (_isCurrent(runtime: runtime, watch: watch)) {
                await _endWatch(runtime: runtime, sessionId: watch.sessionId);
              }
            case SesoriToolNoticeOutcome.dropped:
              if (_isCurrent(runtime: runtime, watch: watch)) onDropped();
          }
        } finally {
          watch.delivering = false;
        }
      }().catchError((Object error, StackTrace stackTrace) {
        Log.w("PR monitor: settling a notice for ${runtime.target.displayKey} failed", error, stackTrace);
      }),
    );
  }

  /// Marks [snapshot] as reported to [watch]: its new baseline, or the end
  /// of the watch once the PR is merged or closed. False when the watch
  /// ended meanwhile.
  Future<bool> _recordReport({
    required _PullRequestRuntime runtime,
    required _Watch watch,
    required PullRequestSnapshot snapshot,
  }) async {
    if (!_isCurrent(runtime: runtime, watch: watch)) return false;
    watch.resumed = false;
    if (snapshot.state != PullRequestState.open) {
      await _endWatch(runtime: runtime, sessionId: watch.sessionId);
      return true;
    }
    return await _saveIfCurrent(
      runtime: runtime,
      watch: watch,
      stored: watch.stored.copyWith(
        title: snapshot.title,
        baseline: _activity.baselineOf(snapshot: snapshot),
        lastReportAt: _clock.now(),
      ),
    );
  }

  Future<bool> _saveIfCurrent({
    required _PullRequestRuntime runtime,
    required _Watch watch,
    required StoredPullRequestWatch stored,
  }) async {
    if (!_isCurrent(runtime: runtime, watch: watch)) return false;
    await _watches.save(sessionId: watch.sessionId, watch: stored);
    watch.stored = stored;
    return true;
  }

  /// Ends every watch of the PR, telling each session why.
  Future<void> _stopAll({required _PullRequestRuntime runtime, required String reason}) async {
    final watches = [...runtime.watches.values];
    runtime.consecutiveFailures = 0;
    for (final watch in watches) {
      await _endWatch(runtime: runtime, sessionId: watch.sessionId);
      unawaited(
        _host.deliverNotice(
          sessionId: watch.sessionId,
          summary: _reports.buildStopSummary(target: runtime.target),
          guidance: _reports.buildStopNotice(
            target: runtime.target,
            snapshot: runtime.snapshot,
            reason: reason,
            autoMergeEnabled: watch.stored.autoMerge,
          ),
          timing: SesoriToolNoticeTiming.derived,
          claim: null,
        ),
      );
    }
  }

  Future<void> _endWatch({required _PullRequestRuntime runtime, required String sessionId}) async {
    runtime.watches.remove(sessionId);
    _dropIfUnused(runtime: runtime);
    await _watches.delete(sessionId: sessionId, target: runtime.target);
  }

  String _render({
    required _PullRequestRuntime runtime,
    required _Watch watch,
    required PullRequestSnapshot snapshot,
    required int? forcedHoldMinutes,
  }) => _reports.buildReport(
    target: runtime.target,
    snapshot: snapshot,
    baseline: watch.stored.baseline,
    forcedHoldMinutes: forcedHoldMinutes,
    autoMergeEnabled: _autoMerge(runtime: runtime),
    opening: watch.resumed ? PullRequestReportOpening.resumed : PullRequestReportOpening.ongoing,
  );

  PullRequestWatchStatus _status({required _PullRequestRuntime runtime, required _Watch watch}) {
    final snapshot = runtime.snapshot;
    return PullRequestWatchStatus(
      target: runtime.target,
      ciHold: runtime.holdStartedAt != null,
      activityBuffered: runtime.dirty,
      sinceLastReport: _clock.now().difference(watch.stored.lastReportAt),
      consecutiveFailures: runtime.consecutiveFailures,
      ready: snapshot == null ? null : _readiness.hasReadyLabel(snapshot: snapshot),
      autoMerge: watch.stored.autoMerge,
    );
  }

  /// Auto-merge applies to the PR when any of its watches has it on.
  bool _autoMerge({required _PullRequestRuntime runtime}) =>
      runtime.watches.values.any((watch) => watch.stored.autoMerge);

  bool _isCurrent({required _PullRequestRuntime runtime, required _Watch watch}) =>
      identical(_runtimes[runtime.target.registryKey], runtime) && identical(runtime.watches[watch.sessionId], watch);

  _PullRequestRuntime _runtimeOf({required PullRequestTarget target}) => _runtimes.putIfAbsent(
    target.registryKey,
    () => _PullRequestRuntime(target: target, lastActivityAt: _clock.now()),
  );

  /// Runs [operation] after the PR's earlier ones.
  Future<T> _run<T>({required _PullRequestRuntime runtime, required Future<T> Function() operation}) {
    runtime.pendingOperations++;
    final result = runtime.queue.then((_) => operation());
    runtime.queue = result.then<void>((_) {}, onError: (Object _) {});
    return result.whenComplete(() {
      runtime.pendingOperations--;
      _dropIfUnused(runtime: runtime);
    });
  }

  /// Forgets a PR nobody watches once nothing is queued on it.
  void _dropIfUnused({required _PullRequestRuntime runtime}) {
    final key = runtime.target.registryKey;
    if (runtime.watches.isEmpty && runtime.pendingOperations == 0 && identical(_runtimes[key], runtime)) {
      _runtimes.remove(key);
    }
  }
}

/// One watched PR, shared by every session that watches it.
class _PullRequestRuntime({required final PullRequestTarget target, required var DateTime lastActivityAt}) {
  /// By session id.
  final Map<String, _Watch> watches = {};

  /// The last successful poll; null after a restart until the first one.
  PullRequestSnapshot? snapshot;
  PullRequestMergeable? lastDefiniteMergeable;
  DateTime? lastPolledAt;
  int consecutiveFailures = 0;

  /// Activity is waiting for a report.
  bool dirty = false;

  /// The waiting report skips the quiet window and the CI hold.
  bool urgent = false;
  DateTime? holdStartedAt;
  String? ciFailureReportedSha;

  Future<void> queue = Future<void>.value();
  int pendingOperations = 0;
}

/// One session's watch of a [_PullRequestRuntime]'s PR.
///
/// [resumed] is true until the first report after a restart, which says it
/// covers the downtime.
class _Watch({
  required final String sessionId,
  required var StoredPullRequestWatch stored,
  required var bool resumed,
}) {
  /// A report or reminder is waiting for the session.
  bool delivering = false;
}
