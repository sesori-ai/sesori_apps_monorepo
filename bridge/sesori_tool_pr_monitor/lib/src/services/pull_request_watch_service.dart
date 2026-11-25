import "dart:async";

import "package:clock/clock.dart";
import "package:sesori_shared/sesori_shared.dart" show PullRequestWatchStatus, PullRequestWatchStatusMerged;
import "package:sesori_tool_interface/sesori_tool_interface.dart";

import "../models/gh_cli_exception.dart";
import "../models/pull_request_target.dart";
import "../repositories/models/pull_request_ci_phase.dart";
import "../repositories/models/pull_request_snapshot.dart";
import "../repositories/models/stored_pull_request_watch.dart";
import "../repositories/pull_request_action_repository.dart";
import "../repositories/pull_request_snapshot_repository.dart";
import "../repositories/pull_request_watch_repository.dart";
import "models/pull_request_merge_state.dart";
import "models/pull_request_watch_results.dart";
import "pull_request_activity_calculator.dart";
import "pull_request_feedback_builder.dart";
import "pull_request_merge_service.dart";
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
  required final PullRequestFeedbackBuilder _feedback,
  required final PullRequestMergeService _merges,
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

  final StreamController<Set<String>> _watchesChanged = StreamController<Set<String>>.broadcast();

  /// The local day whose earlier merged watches are cleared.
  DateTime? _mergedClearedFor;

  /// The sessions whose watches started, ended, or changed their status or
  /// auto-merge, so the app's views of them follow.
  Stream<Set<String>> get watchesChanged => _watchesChanged.stream;

  /// The session a caller's watches belong to: its family's root, as for
  /// wake-ups. Null when Sesori no longer knows the caller.
  Future<String?> watchSessionOf({required SesoriToolCaller caller}) async =>
      (await _host.sessions(sessionIds: {caller.sessionId}))[caller.sessionId]?.rootSessionId;

  /// Loads every stored watch. Each PR's first poll then compares each
  /// watch's stored baseline with GitHub, so what changed while the bridge
  /// was off is reported.
  Future<void> resume() async {
    for (final (:sessionId, :watch) in await _watches.loadAll()) {
      // A merged watch only stays listed, until midnight.
      if (watch.status is PullRequestWatchStatusMerged) continue;
      _runtimeOf(
        target: PullRequestTarget(owner: watch.owner, repo: watch.repo, number: watch.number),
      ).watches.putIfAbsent(sessionId, () => _Watch(sessionId: sessionId, stored: watch, resumed: true));
    }
  }

  /// With [autoMerge], a ready label the PR already carries is removed
  /// first, unless auto-merge already applied to it.
  Future<PullRequestWatchStart> watch({
    required String sessionId,
    required PullRequestTarget target,
    required bool autoMerge,
  }) async {
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
        final PullRequestSnapshot fetched;
        try {
          fetched = await _snapshots.fetchSnapshot(target: target, selfLogin: selfLogin);
        } on Exception catch (error) {
          return PullRequestFetchFailed(error: error);
        }
        var snapshot = await _applySnapshot(runtime: runtime, snapshot: fetched);
        if (snapshot.state != PullRequestState.open) return PullRequestAlreadyEnded(state: snapshot.state);
        final readyLabelRemoved =
            autoMerge && !_autoMerge(runtime: runtime) && _readiness.hasReadyLabel(snapshot: snapshot);
        if (readyLabelRemoved) {
          try {
            snapshot = _applyStep(
              runtime: runtime,
              step: await _merges.resetForAutoMerge(target: target, snapshot: snapshot, state: runtime.merge),
            );
          } on Exception catch (error) {
            return PullRequestReadyResetFailed(error: error);
          }
        }
        final stored = StoredPullRequestWatch(
          owner: target.owner,
          repo: target.repo,
          number: target.number,
          title: snapshot.title,
          autoMerge: autoMerge,
          baseline: _activity.baselineOf(snapshot: snapshot),
          lastReportAt: _clock.now(),
          status: _readiness.watchStatus(
            snapshot: snapshot,
            autoMerge: autoMerge || _autoMerge(runtime: runtime),
          ),
        );
        await _watches.save(sessionId: sessionId, watch: stored);
        runtime.watches[sessionId] = _Watch(sessionId: sessionId, stored: stored, resumed: false);
        _announce(sessionIds: {sessionId});
        return PullRequestWatchStarted(
          title: snapshot.title,
          report: _reports.buildReport(
            target: runtime.target,
            snapshot: snapshot,
            baseline: null,
            forcedHoldMinutes: null,
            autoMergeEnabled: _autoMerge(runtime: runtime),
            readinessFailure: runtime.merge.retry,
            mergeAttempt: null,
            opening: PullRequestReportOpening.watchStarted,
          ),
          autoMerge: _autoMerge(runtime: runtime),
          readyLabelRemoved: readyLabelRemoved,
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
    if (removed || deleted) _announce(sessionIds: {sessionId});
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
        final PullRequestSnapshot fetched;
        try {
          fetched = await _snapshots.fetchSnapshot(target: runtime.target, selfLogin: await _actions.selfLogin());
        } on Exception catch (error) {
          return switch (runtime.snapshot) {
            null => PullRequestReportUnavailable(error: error),
            final previous => PullRequestReportStale(
              report: _render(runtime: runtime, watch: watch, snapshot: previous, forcedHoldMinutes: null),
              error: error,
            ),
          };
        }
        var snapshot = await _applySnapshot(runtime: runtime, snapshot: fetched);
        if (runtime.dirty) snapshot = await _prepareReport(runtime: runtime, snapshot: snapshot);
        // An unwatch while the fetch ran must not be undone.
        if (!_isCurrent(runtime: runtime, watch: watch)) return const PullRequestNotWatched();
        final report = _render(runtime: runtime, watch: watch, snapshot: snapshot, forcedHoldMinutes: null);
        // ponytail: like a delivered report, this one shows the readiness
        // news once; other watchers see the PR state, not the notice.
        snapshot = _applyStep(
          runtime: runtime,
          step: _merges.afterReport(snapshot: snapshot, state: runtime.merge),
        );
        await _recordReport(runtime: runtime, watch: watch, snapshot: snapshot);
        return PullRequestReportFresh(report: report);
      },
    );
  }

  /// `mark_pr_ready` or `unmark_pr_ready`. On a watched PR it also settles
  /// readiness, and with auto-merge on a mark makes the one merge attempt; on
  /// any other PR it only changes the label. Throws when the label change
  /// fails.
  Future<PullRequestReadyChange> setReady({
    required String sessionId,
    required PullRequestTarget target,
    required bool ready,
  }) async {
    final runtime = _runtimes[target.registryKey];
    if (runtime == null) return await _merges.setStandaloneReady(target: target, ready: ready);
    return await _run(
      runtime: runtime,
      operation: () async {
        if (runtime.watches.isEmpty) return await _merges.setStandaloneReady(target: target, ready: ready);
        final result = await _merges.setReady(
          target: target,
          snapshot: await _currentSnapshot(runtime: runtime),
          ready: ready,
          autoMerge: _autoMerge(runtime: runtime),
          state: runtime.merge,
        );
        final snapshot = _applyStep(runtime: runtime, step: result.step);
        if (runtime.watches[sessionId] case final watch?) {
          await _saveIfCurrent(
            runtime: runtime,
            watch: watch,
            stored: _acknowledged(stored: watch.stored, snapshot: snapshot),
          );
        }
        return result.change;
      },
    );
  }

  /// Turns auto-merge on or off for [sessionId]'s watch. When that turns it
  /// on for the PR, a ready label the PR carries is removed so that only a
  /// fresh judgment merges it. Throws when that removal fails.
  Future<PullRequestAutoMergeResult> setAutoMerge({
    required String sessionId,
    required PullRequestTarget target,
    required bool enabled,
  }) async {
    final runtime = _runtimes[target.registryKey];
    if (runtime == null || !runtime.watches.containsKey(sessionId)) return const PullRequestAutoMergeNotWatched();
    return await _run(
      runtime: runtime,
      operation: () async {
        final watch = runtime.watches[sessionId];
        if (watch == null) return const PullRequestAutoMergeNotWatched();
        if (watch.stored.autoMerge == enabled) return PullRequestAutoMergeUnchanged(enabled: enabled);
        var stored = watch.stored.copyWith(autoMerge: enabled);
        var readyLabelRemoved = false;
        if (enabled && !_autoMerge(runtime: runtime)) {
          final snapshot = await _currentSnapshot(runtime: runtime);
          if (snapshot.state == PullRequestState.open && _readiness.hasReadyLabel(snapshot: snapshot)) {
            final reset = _applyStep(
              runtime: runtime,
              step: await _merges.resetForAutoMerge(target: target, snapshot: snapshot, state: runtime.merge),
            );
            stored = _acknowledged(stored: stored, snapshot: reset);
            readyLabelRemoved = true;
          }
        }
        if (!await _saveIfCurrent(runtime: runtime, watch: watch, stored: stored)) {
          return const PullRequestAutoMergeNotWatched();
        }
        _announce(sessionIds: {sessionId});
        return PullRequestAutoMergeSet(
          enabled: enabled,
          effective: _autoMerge(runtime: runtime),
          readyLabelRemoved: readyLabelRemoved,
        );
      },
    );
  }

  /// `get_pr_feedback`: the PR's current feedback in full. Throws when the
  /// fetch fails.
  Future<String> feedback({required PullRequestTarget target}) async => _feedback.build(
    target: target,
    snapshot: await _snapshots.fetchSnapshot(target: target, selfLogin: await _actions.selfLogin()),
  );

  /// `reply_on_pr`: posts [body] as the agent's reply and returns its URL.
  Future<String> reply({required PullRequestTarget target, required String? threadId, required String body}) =>
      _actions.reply(target: target, threadId: threadId, body: body);

  /// Polls each watched PR whose last poll is [pollInterval] old, one at a
  /// time, and sends the reports and reminders that are due. A PR whose
  /// previous operation still runs waits for the next call.
  Future<void> pollDue() async {
    await _clearMergedWatches();
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

  /// Deletes the watches merged before today, once per local day.
  Future<void> _clearMergedWatches() async {
    final now = _clock.now().toLocal();
    final today = DateTime(now.year, now.month, now.day);
    if (_mergedClearedFor == today) return;
    final cleared = <String>{};
    for (final (:sessionId, :watch) in await _watches.loadAll()) {
      if (watch.status case PullRequestWatchStatusMerged(:final mergedAt)
          when DateTime.fromMillisecondsSinceEpoch(mergedAt).isBefore(today)) {
        await _watches.delete(
          sessionId: sessionId,
          target: PullRequestTarget(owner: watch.owner, repo: watch.repo, number: watch.number),
        );
        cleared.add(sessionId);
      }
    }
    _mergedClearedFor = today;
    _announce(sessionIds: cleared);
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
    await _sendDue(
      runtime: runtime,
      snapshot: await _applySnapshot(runtime: runtime, snapshot: snapshot),
    );
  }

  /// The last poll, or a fresh one after a restart.
  Future<PullRequestSnapshot> _currentSnapshot({required _PullRequestRuntime runtime}) async =>
      runtime.snapshot ??
      await _applySnapshot(
        runtime: runtime,
        snapshot: await _snapshots.fetchSnapshot(target: runtime.target, selfLogin: await _actions.selfLogin()),
      );

  /// Updates the PR's activity clock and readiness from [snapshot] (spec
  /// §4, §6) and returns the PR as it now stands. The first snapshot after a
  /// restart is compared with each watch's stored baseline instead of a
  /// previous poll, and has no earlier state to invalidate readiness against.
  Future<PullRequestSnapshot> _applySnapshot({
    required _PullRequestRuntime runtime,
    required PullRequestSnapshot snapshot,
  }) async {
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
    var current = snapshot;
    if (previous != null) {
      current = _applyStep(
        runtime: runtime,
        step: await _merges.applyPoll(
          target: runtime.target,
          previous: previous,
          next: snapshot,
          lastDefiniteMergeable: runtime.lastDefiniteMergeable,
          activity: activity,
          autoMerge: _autoMerge(runtime: runtime),
          state: runtime.merge,
        ),
      );
    }
    if (snapshot.mergeable != PullRequestMergeable.unknown) runtime.lastDefiniteMergeable = snapshot.mergeable;
    return current;
  }

  /// Takes on a readiness step's state and snapshot and the report it calls
  /// for, and returns the snapshot.
  PullRequestSnapshot _applyStep({required _PullRequestRuntime runtime, required PullRequestMergeStep step}) {
    runtime
      ..merge = step.state
      ..snapshot = step.snapshot;
    switch (step.need) {
      case PullRequestReportNeed.none:
        break;
      case PullRequestReportNeed.afterQuiet:
        runtime
          ..dirty = true
          ..lastActivityAt = _clock.now()
          ..holdStartedAt = null;
      case PullRequestReportNeed.now:
        runtime
          ..dirty = true
          ..urgent = true
          ..holdStartedAt = null;
    }
    return step.snapshot;
  }

  Future<PullRequestSnapshot> _prepareReport({
    required _PullRequestRuntime runtime,
    required PullRequestSnapshot snapshot,
  }) async => _applyStep(
    runtime: runtime,
    step: await _merges.prepareReport(
      target: runtime.target,
      snapshot: snapshot,
      autoMerge: _autoMerge(runtime: runtime),
      state: runtime.merge,
    ),
  );

  /// Sends each watch its report once one is due, or its idle reminder.
  Future<void> _sendDue({required _PullRequestRuntime runtime, required PullRequestSnapshot snapshot}) async {
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
    final current = await _prepareReport(runtime: runtime, snapshot: snapshot);
    // A readiness failure or merge result is news even with the PR unchanged.
    final PullRequestMergeState(:retry, :reportedRetry, :mergeAttempt) = runtime.merge;
    final readinessNews = mergeAttempt != null || (retry != null && !retry.sameFailureAs(other: reportedRetry));
    // A watch whose previous report still waits gets this activity in its
    // next one, so the PR stays due until every watch has had it.
    var waiting = false;
    for (final watch in [...runtime.watches.values]) {
      if (watch.delivering) {
        waiting = true;
      } else if (readinessNews || !_activity.covers(baseline: watch.stored.baseline, snapshot: current)) {
        _deliverReport(runtime: runtime, watch: watch, snapshot: current, forcedHoldMinutes: forcedHoldMinutes);
      }
    }
    if (!waiting) {
      runtime
        ..dirty = false
        ..urgent = false
        ..holdStartedAt = null;
      _applyStep(
        runtime: runtime,
        step: _merges.afterReport(snapshot: current, state: runtime.merge),
      );
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
          readinessFailure: runtime.merge.retry,
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
    // A get_pr_report or a label change while this waited already told the
    // session more.
    final queued = watch.stored.baseline;
    bool unchanged() => _isCurrent(runtime: runtime, watch: watch) && identical(watch.stored.baseline, queued);
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
  /// of the watch once the PR is merged or closed. A merged watch stays
  /// listed until midnight. False when the watch ended meanwhile.
  Future<bool> _recordReport({
    required _PullRequestRuntime runtime,
    required _Watch watch,
    required PullRequestSnapshot snapshot,
  }) async {
    if (!_isCurrent(runtime: runtime, watch: watch)) return false;
    watch.resumed = false;
    if (snapshot.state == PullRequestState.merged) {
      runtime.watches.remove(watch.sessionId);
      _dropIfUnused(runtime: runtime);
      await _watches.save(
        sessionId: watch.sessionId,
        watch: watch.stored.copyWith(
          title: snapshot.title,
          status: PullRequestWatchStatus.merged(mergedAt: _clock.now().millisecondsSinceEpoch),
        ),
      );
      _announce(sessionIds: {watch.sessionId});
      return true;
    }
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
            readinessFailure: runtime.merge.retry,
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
    _announce(sessionIds: {sessionId});
  }

  /// Stores each watch's status when the PR's last poll changed it.
  Future<void> _syncStatuses({required _PullRequestRuntime runtime}) async {
    final snapshot = runtime.snapshot;
    // A merged or closed PR's watches end with their next report.
    if (snapshot == null || snapshot.state != PullRequestState.open) return;
    final status = _readiness.watchStatus(
      snapshot: snapshot,
      autoMerge: _autoMerge(runtime: runtime),
    );
    final changed = <String>{};
    for (final watch in [...runtime.watches.values]) {
      if (watch.stored.status == status) continue;
      if (await _saveIfCurrent(
        runtime: runtime,
        watch: watch,
        stored: watch.stored.copyWith(status: status),
      )) {
        changed.add(watch.sessionId);
      }
    }
    _announce(sessionIds: changed);
  }

  void _announce({required Set<String> sessionIds}) {
    if (sessionIds.isNotEmpty) _watchesChanged.add(sessionIds);
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
    readinessFailure: runtime.merge.retry,
    mergeAttempt: runtime.merge.mergeAttempt,
    opening: watch.resumed ? PullRequestReportOpening.resumed : PullRequestReportOpening.ongoing,
  );

  PullRequestWatchDetail _status({required _PullRequestRuntime runtime, required _Watch watch}) {
    final snapshot = runtime.snapshot;
    return PullRequestWatchDetail(
      target: runtime.target,
      ciHold: runtime.holdStartedAt != null,
      activityBuffered: runtime.dirty,
      sinceLastReport: _clock.now().difference(watch.stored.lastReportAt),
      consecutiveFailures: runtime.consecutiveFailures,
      ready: snapshot == null ? null : _readiness.hasReadyLabel(snapshot: snapshot),
      autoMerge: watch.stored.autoMerge,
    );
  }

  /// A tool call changed the label, so the caller already knows that state.
  StoredPullRequestWatch _acknowledged({
    required StoredPullRequestWatch stored,
    required PullRequestSnapshot snapshot,
  }) => stored.copyWith(
    baseline: stored.baseline.copyWith(ready: _readiness.hasReadyLabel(snapshot: snapshot)),
    lastReportAt: _clock.now(),
  );

  /// Auto-merge applies to the PR when any of its watches has it on.
  bool _autoMerge({required _PullRequestRuntime runtime}) =>
      runtime.watches.values.any((watch) => watch.stored.autoMerge);

  bool _isCurrent({required _PullRequestRuntime runtime, required _Watch watch}) =>
      identical(_runtimes[runtime.target.registryKey], runtime) && identical(runtime.watches[watch.sessionId], watch);

  _PullRequestRuntime _runtimeOf({required PullRequestTarget target}) => _runtimes.putIfAbsent(
    target.registryKey,
    () => _PullRequestRuntime(target: target, lastActivityAt: _clock.now()),
  );

  /// Runs [operation] after the PR's earlier ones, then stores the watches'
  /// new status.
  Future<T> _run<T>({required _PullRequestRuntime runtime, required Future<T> Function() operation}) {
    runtime.pendingOperations++;
    final result = runtime.queue.then((_) async {
      final value = await operation();
      await _syncStatuses(runtime: runtime);
      return value;
    });
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
  PullRequestMergeState merge = PullRequestMergeState.initial;

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
