import "package:sesori_tool_interface/sesori_tool_interface.dart" show Log;

import "../models/pull_request_target.dart";
import "../repositories/models/pull_request_merge_outcome.dart";
import "../repositories/models/pull_request_snapshot.dart";
import "../repositories/pull_request_action_repository.dart";
import "models/pull_request_merge_state.dart";
import "models/pull_request_watch_results.dart";
import "pull_request_readiness_calculator.dart";

/// The ready label and auto-merge (spec §6–§7). It holds no state: each call
/// takes the PR's [PullRequestMergeState] and snapshot and returns the new
/// ones, so the caller's per-PR queue is the only owner.
///
/// Only a label this service adds triggers a merge, so a label a human adds
/// is observed but never merges.
class PullRequestMergeService({
  required final PullRequestActionRepository _actions,
  required final PullRequestReadinessCalculator _readiness,
}) {
  /// What one poll means for readiness: withdraw a ready label the new state
  /// invalidates, retry a failed change, and ask for a report when the PR
  /// became ready-eligible or lost its label from outside. [activity] is
  /// whether the poll found reportable activity.
  Future<PullRequestMergeStep> applyPoll({
    required PullRequestTarget target,
    required PullRequestSnapshot previous,
    required PullRequestSnapshot next,
    required PullRequestMergeable? lastDefiniteMergeable,
    required bool activity,
    required bool autoMerge,
    required PullRequestMergeState state,
  }) async {
    var current = activity ? state.copyWith(resetPending: false) : state;
    if (next.state != PullRequestState.open) {
      return _step(
        snapshot: next,
        state: _cleared(state: current),
      );
    }
    final wasReady = _readiness.hasReadyLabel(snapshot: previous);
    final observedReady = _readiness.hasReadyLabel(snapshot: next);

    if (current.retry case final retry?) {
      if (retry.ready &&
          _readiness.hasReadinessInvalidation(
            previous: retry.baseline,
            next: next,
            lastDefiniteMergeable: lastDefiniteMergeable,
          )) {
        current = _cleared(state: current);
        if (!observedReady) return _step(snapshot: next, state: current, need: PullRequestReportNeed.afterQuiet);
        return await _withdraw(target: target, snapshot: next, state: current);
      }
      if (observedReady == retry.ready) {
        // A failed add never authorizes a merge, even when its label shows up.
        return _step(
          snapshot: next,
          state: _cleared(state: current).copyWith(restoreAfterReport: current.restoreAfterReport || !retry.ready),
          need: PullRequestReportNeed.now,
        );
      }
      if (!retry.ready || _readiness.assess(snapshot: next).eligible) {
        final changed = await _change(
          target: target,
          snapshot: next,
          state: current,
          ready: retry.ready,
          autoMerge: autoMerge,
        );
        if (_readiness.hasReadyLabel(snapshot: changed.snapshot) != retry.ready) return changed;
        return _step(
          snapshot: changed.snapshot,
          state: changed.state.copyWith(restoreAfterReport: changed.state.restoreAfterReport || !retry.ready),
          need: PullRequestReportNeed.now,
        );
      }
      current = _cleared(state: current);
    }

    if (wasReady &&
        _readiness.hasReadinessInvalidation(
          previous: previous,
          next: next,
          lastDefiniteMergeable: lastDefiniteMergeable,
        )) {
      if (!observedReady) {
        return _step(
          snapshot: next,
          state: current.copyWith(restoreAfterReport: true),
          need: PullRequestReportNeed.now,
        );
      }
      return await _withdraw(target: target, snapshot: next, state: current);
    }
    // A label removed from outside, or a PR that just became eligible, is
    // labelled again by the next quiet report.
    if (!observedReady &&
        (wasReady || (_readiness.assess(snapshot: next).eligible && !_readiness.assess(snapshot: previous).eligible))) {
      return _step(snapshot: next, state: current, need: PullRequestReportNeed.afterQuiet);
    }
    return _step(snapshot: next, state: current);
  }

  /// Right before a report: labels an eligible PR ready, and with
  /// [autoMerge] makes the one merge attempt whose result the report shows.
  Future<PullRequestMergeStep> prepareReport({
    required PullRequestTarget target,
    required PullRequestSnapshot snapshot,
    required bool autoMerge,
    required PullRequestMergeState state,
  }) async {
    if (state.restoreAfterReport ||
        state.resetPending ||
        snapshot.state != PullRequestState.open ||
        _readiness.hasReadyLabel(snapshot: snapshot) ||
        !_readiness.assess(snapshot: snapshot).eligible) {
      return _step(snapshot: snapshot, state: state);
    }
    return await _change(target: target, snapshot: snapshot, state: state, ready: true, autoMerge: autoMerge);
  }

  /// Once a report went out: its failure and merge notice were shown, and a
  /// withdrawn label may come back after the next quiet window.
  PullRequestMergeStep afterReport({required PullRequestSnapshot snapshot, required PullRequestMergeState state}) {
    final restore =
        state.restoreAfterReport &&
        snapshot.state == PullRequestState.open &&
        !_readiness.hasReadyLabel(snapshot: snapshot) &&
        _readiness.assess(snapshot: snapshot).eligible;
    return _step(
      snapshot: snapshot,
      state: state.copyWith(reportedRetry: state.retry, mergeAttempt: null, restoreAfterReport: false),
      need: restore ? PullRequestReportNeed.afterQuiet : PullRequestReportNeed.none,
    );
  }

  /// `mark_pr_ready` or `unmark_pr_ready` on a watched PR. It accepts the
  /// current state as it is, and with [autoMerge] a mark merges at the last
  /// polled head. A failed label change throws.
  Future<({PullRequestMergeStep step, PullRequestReadyChange change})> setReady({
    required PullRequestTarget target,
    required PullRequestSnapshot snapshot,
    required bool ready,
    required bool autoMerge,
    required PullRequestMergeState state,
  }) async {
    final change = await setStandaloneReady(target: target, ready: ready);
    final changed = _withReadyLabel(snapshot: snapshot, ready: ready);
    final next = _cleared(state: state).copyWith(mergeAttempt: null, resetPending: false, restoreAfterReport: false);
    if (ready) {
      return (
        step: _step(snapshot: changed, state: next),
        change: PullRequestMarkedReady(
          mergeAttempt: autoMerge ? await _merge(target: target, snapshot: changed) : null,
        ),
      );
    }
    // Still eligible, so the next quiet report labels it again.
    final eligible = _readiness.assess(snapshot: changed).eligible;
    return (
      step: _step(
        snapshot: changed,
        state: next,
        need: eligible ? PullRequestReportNeed.afterQuiet : PullRequestReportNeed.none,
      ),
      change: change,
    );
  }

  /// The label change alone, for a PR nobody watches. Throws on failure.
  Future<PullRequestReadyChange> setStandaloneReady({required PullRequestTarget target, required bool ready}) async {
    if (!ready) return PullRequestUnmarkedReady(wasCarried: await _actions.removeReadyLabel(target: target));
    await _actions.addReadyLabel(target: target);
    return const PullRequestMarkedReady(mergeAttempt: null);
  }

  /// Turning auto-merge on removes an existing ready label, so a handoff made
  /// without it is never merged without a fresh judgment. Throws on failure.
  Future<PullRequestMergeStep> resetForAutoMerge({
    required PullRequestTarget target,
    required PullRequestSnapshot snapshot,
    required PullRequestMergeState state,
  }) async {
    await _actions.removeReadyLabel(target: target);
    final changed = _withReadyLabel(snapshot: snapshot, ready: false);
    return _step(
      snapshot: changed,
      state: _cleared(
        state: state,
      ).copyWith(resetPending: _readiness.assess(snapshot: changed).eligible, restoreAfterReport: false),
    );
  }

  /// Removes an invalidated ready label; the report saying so goes now.
  Future<PullRequestMergeStep> _withdraw({
    required PullRequestTarget target,
    required PullRequestSnapshot snapshot,
    required PullRequestMergeState state,
  }) async {
    final changed = await _change(target: target, snapshot: snapshot, state: state, ready: false, autoMerge: false);
    final withdrawn = !_readiness.hasReadyLabel(snapshot: changed.snapshot);
    return _step(
      snapshot: changed.snapshot,
      state: withdrawn ? changed.state.copyWith(restoreAfterReport: true) : changed.state,
      need: PullRequestReportNeed.now,
    );
  }

  /// An automatic label change. A failure keeps the PR as it was, records the
  /// retry, and asks for a report at once when its error is new.
  Future<PullRequestMergeStep> _change({
    required PullRequestTarget target,
    required PullRequestSnapshot snapshot,
    required PullRequestMergeState state,
    required bool ready,
    required bool autoMerge,
  }) async {
    try {
      if (ready) {
        await _actions.addReadyLabel(target: target);
      } else {
        await _actions.removeReadyLabel(target: target);
      }
    } on Exception catch (error, stackTrace) {
      Log.w("PR monitor: readiness automation failed for ${target.displayKey}", error, stackTrace);
      final previous = state.retry;
      final retry = PullRequestReadinessRetry(
        ready: ready,
        baseline: previous != null && previous.ready == ready ? previous.baseline : snapshot,
        cause: error,
      );
      return _step(
        snapshot: snapshot,
        state: state.copyWith(retry: retry),
        need: retry.sameFailureAs(other: state.reportedRetry) ? PullRequestReportNeed.none : PullRequestReportNeed.now,
      );
    }
    final changed = _withReadyLabel(snapshot: snapshot, ready: ready);
    final next = _cleared(state: state);
    if (!ready || !autoMerge) return _step(snapshot: changed, state: next);
    return _step(
      snapshot: changed,
      state: next.copyWith(
        mergeAttempt: await _merge(target: target, snapshot: changed),
      ),
    );
  }

  /// The one squash merge a ready label from this service allows, at
  /// [snapshot]'s head and title.
  Future<PullRequestMergeAttempt> _merge({
    required PullRequestTarget target,
    required PullRequestSnapshot snapshot,
  }) async {
    final head = snapshot.headSha;
    final outcome = await _actions.squashMerge(target: target, headSha: head, title: snapshot.title);
    switch (outcome) {
      case PullRequestMerged():
        break;
      case PullRequestMergeHeadChanged():
        Log.i("PR monitor: auto-merge of ${target.displayKey} canceled, the head moved from $head");
      case PullRequestMergeRejected(:final reason, :final cause):
        Log.w("PR monitor: auto-merge of ${target.displayKey} failed: $reason", cause);
      case PullRequestMergeOutcomeUnknown(:final detail, :final cause):
        Log.w("PR monitor: auto-merge outcome of ${target.displayKey} is unknown: $detail", cause);
    }
    return PullRequestMergeAttempt(headSha: head, outcome: outcome);
  }

  PullRequestMergeState _cleared({required PullRequestMergeState state}) =>
      state.copyWith(retry: null, reportedRetry: null);

  /// [snapshot] as if GitHub already showed the label change.
  PullRequestSnapshot _withReadyLabel({required PullRequestSnapshot snapshot, required bool ready}) =>
      snapshot.copyWith(
        labels: [
          for (final label in snapshot.labels)
            if (label.toLowerCase() != agentReadyLabel) label,
          if (ready) agentReadyLabel,
        ],
      );

  PullRequestMergeStep _step({
    required PullRequestSnapshot snapshot,
    required PullRequestMergeState state,
    PullRequestReportNeed need = PullRequestReportNeed.none,
  }) => PullRequestMergeStep(snapshot: snapshot, state: state, need: need);
}
