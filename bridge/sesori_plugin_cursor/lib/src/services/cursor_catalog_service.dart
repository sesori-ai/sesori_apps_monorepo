import "dart:async";

import "package:acp_plugin/acp_plugin.dart" show AcpCommandTracker, AcpNewSessionResult;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../models/cursor_catalog_models.dart";
import "../repositories/cursor_catalog_repository.dart";
import "../trackers/cursor_catalog_tracker.dart";

/// Coordinates bounded, isolated Cursor catalog discovery.
class CursorCatalogService {
  CursorCatalogService({
    required CursorCatalogRepository repository,
    required CursorCatalogTracker tracker,
    required AcpCommandTracker commandTracker,
    required AcpCommandTracker stagedCommandTracker,
    required Duration totalTimeout,
    required int maxCandidates,
  }) : _repository = repository,
       _tracker = tracker,
       _commandTracker = commandTracker,
       _stagedCommandTracker = stagedCommandTracker,
       _totalTimeout = totalTimeout,
       _maxCandidates = maxCandidates;

  final CursorCatalogRepository _repository;
  final CursorCatalogTracker _tracker;
  final AcpCommandTracker _commandTracker;
  final AcpCommandTracker _stagedCommandTracker;
  final Duration _totalTimeout;
  final int _maxCandidates;
  Future<CursorCatalogProbeOutcome>? _inFlight;
  Future<bool>? _forcedInFlight;
  final Set<String> _retriedScopes = {};

  Future<void> ensureCatalog({required String scope}) async {
    while (!_tracker.isComplete) {
      final pending = _inFlight;
      if (pending != null) {
        await pending;
        continue;
      }

      final outcome = _tracker.outcomeForScope(scope: scope);
      if (outcome == CursorCatalogProbeOutcome.complete || outcome == CursorCatalogProbeOutcome.exhausted) {
        return;
      }
      if (outcome == CursorCatalogProbeOutcome.retryableFailure && !_retriedScopes.add(scope)) {
        return;
      }

      final operation = _probeAndCommitReuse(scope: scope);
      _inFlight = operation;
      try {
        await operation;
      } finally {
        if (identical(_inFlight, operation)) _inFlight = null;
      }
      return;
    }
  }

  /// Runs one bounded probe regardless of prior complete/exhausted/retried
  /// state. Concurrent forced callers join the same operation. Discovery is
  /// applied transactionally so a failed probe leaves the last-good tracker
  /// untouched.
  Future<bool> refreshCatalog({required String scope}) {
    final pending = _forcedInFlight;
    if (pending != null) return pending;

    late final Future<bool> operation;
    operation = _refreshCatalog(scope: scope).whenComplete(() {
      if (identical(_forcedInFlight, operation)) _forcedInFlight = null;
    });
    _forcedInFlight = operation;
    return operation;
  }

  CursorCatalogCaptureResult captureSessionConfig({
    required AcpNewSessionResult result,
    required bool fromNewSession,
    required String? thoughtLevelModelId,
    required bool captureThoughtLevelDefault,
  }) {
    final snapshot = _repository.mapSessionResult(result: result);
    return _tracker.applySnapshot(
      snapshot: snapshot,
      fromNewSession: fromNewSession,
      thoughtLevelModelId: thoughtLevelModelId,
      captureThoughtLevelDefault: captureThoughtLevelDefault,
    );
  }

  Future<void> dispose() => _repository.dispose();

  Future<bool> _refreshCatalog({required String scope}) async {
    while (_inFlight != null) {
      final pending = _inFlight!;
      await pending;
    }

    final operation = _probeAndCommitRefresh(scope: scope);
    _inFlight = operation;
    final CursorCatalogProbeOutcome outcome;
    try {
      outcome = await operation;
    } finally {
      if (identical(_inFlight, operation)) _inFlight = null;
    }
    return outcome != CursorCatalogProbeOutcome.retryableFailure;
  }

  Future<CursorCatalogProbeOutcome> _probeAndCommitReuse({required String scope}) async {
    final outcome = await _probe(scope: scope, tracker: _tracker);
    if (outcome != CursorCatalogProbeOutcome.retryableFailure) {
      _commitStagedCommands();
    }
    return outcome;
  }

  Future<CursorCatalogProbeOutcome> _probeAndCommitRefresh({required String scope}) async {
    final discovered = CursorCatalogTracker();
    final outcome = await _probe(scope: scope, tracker: discovered);
    if (outcome == CursorCatalogProbeOutcome.retryableFailure) return outcome;
    _tracker.replaceDiscoveredCatalog(
      discovered: discovered,
      scope: scope,
      outcome: outcome,
    );
    _commitStagedCommands();
    return outcome;
  }

  void _commitStagedCommands() {
    if (!_stagedCommandTracker.hasSnapshot) return;
    _commandTracker.replaceSnapshot(commands: _stagedCommandTracker.commands);
  }

  Future<CursorCatalogProbeOutcome> _probe({
    required String scope,
    required CursorCatalogTracker tracker,
  }) async {
    final target = tracker;
    _stagedCommandTracker.clear();
    final stopwatch = Stopwatch()..start();
    try {
      final supported = await _repository.open(
        timeout: _remaining(stopwatch: stopwatch),
      );

      try {
        final bootstrap = await _repository.loadAvailableCatalog(
          timeout: _remaining(stopwatch: stopwatch),
        );
        if (bootstrap != null) {
          target.applyBootstrapSnapshot(snapshot: bootstrap);
        }
      } on Object catch (error, stack) {
        Log.w(
          "[cursor] account catalog discovery failed; falling back to existing sessions",
          error,
          stack,
        );
      }

      if (target.isComplete) {
        target.recordOutcome(
          scope: scope,
          outcome: CursorCatalogProbeOutcome.complete,
        );
        return CursorCatalogProbeOutcome.complete;
      }

      if (!supported) {
        target.recordOutcome(
          scope: scope,
          outcome: CursorCatalogProbeOutcome.exhausted,
        );
        return CursorCatalogProbeOutcome.exhausted;
      }

      final candidateResult = await _repository.listCandidates(
        scope: scope,
        timeout: _remaining(stopwatch: stopwatch),
      );
      final ordered = candidateResult.candidates.toList(growable: false)
        ..sort(
          (left, right) => (right.updatedAtMs ?? 0).compareTo(left.updatedAtMs ?? 0),
        );
      final bounded = ordered.take(_maxCandidates);
      var loadFailed = false;
      var attempted = 0;
      for (final candidate in bounded) {
        attempted++;
        try {
          final snapshot = await _repository.loadCandidate(
            candidate: candidate,
            timeout: _remaining(stopwatch: stopwatch),
          );
          target.applySnapshot(
            snapshot: snapshot,
            fromNewSession: false,
            thoughtLevelModelId: null,
            captureThoughtLevelDefault: false,
          );
          if (target.isComplete) break;
        } on TimeoutException {
          rethrow;
        } on Object catch (error, stack) {
          loadFailed = true;
          Log.w(
            "[cursor] catalog session/load failed; continuing "
            "(scope=$scope, sessionId=${candidate.sessionId})",
            error,
            stack,
          );
        }
      }

      if (target.isComplete) {
        target.recordOutcome(
          scope: scope,
          outcome: CursorCatalogProbeOutcome.complete,
        );
        return CursorCatalogProbeOutcome.complete;
      }

      final inspectedBoundedCandidates = attempted == ordered.length || attempted == _maxCandidates;
      if (candidateResult.exhaustive && !loadFailed && inspectedBoundedCandidates) {
        target.recordOutcome(
          scope: scope,
          outcome: CursorCatalogProbeOutcome.exhausted,
        );
        return CursorCatalogProbeOutcome.exhausted;
      }

      return _recordRetryableFailure(tracker: target, scope: scope);
    } on TimeoutException catch (error, stack) {
      Log.w(
        "[cursor] catalog probe timed out (scope=$scope)",
        error,
        stack,
      );
      return _recordRetryableFailure(tracker: target, scope: scope);
    } on Object catch (error, stack) {
      Log.w(
        "[cursor] catalog probe failed (scope=$scope)",
        error,
        stack,
      );
      return _recordRetryableFailure(tracker: target, scope: scope);
    } finally {
      await _resetRepository(
        failureMessage: "[cursor] failed to stop catalog probe process (scope=$scope)",
      );
    }
  }

  CursorCatalogProbeOutcome _recordRetryableFailure({
    required CursorCatalogTracker tracker,
    required String scope,
  }) {
    tracker.recordOutcome(
      scope: scope,
      outcome: CursorCatalogProbeOutcome.retryableFailure,
    );
    return CursorCatalogProbeOutcome.retryableFailure;
  }

  Future<void> _resetRepository({required String failureMessage}) async {
    try {
      await _repository.reset();
    } on Object catch (error, stack) {
      Log.w(failureMessage, error, stack);
    }
  }

  Duration _remaining({required Stopwatch stopwatch}) {
    final remaining = _totalTimeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException("Cursor catalog probe exceeded $_totalTimeout");
    }
    return remaining;
  }
}
