import "dart:async";

import "package:acp_plugin/acp_plugin.dart" show AcpNewSessionResult;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../models/cursor_catalog_models.dart";
import "../repositories/cursor_catalog_repository.dart";
import "../trackers/cursor_catalog_tracker.dart";

/// Coordinates bounded, isolated Cursor catalog discovery.
class CursorCatalogService {
  CursorCatalogService({
    required CursorCatalogRepository repository,
    required CursorCatalogTracker tracker,
    required Duration totalTimeout,
    required int maxCandidates,
  }) : _repository = repository,
       _tracker = tracker,
       _totalTimeout = totalTimeout,
       _maxCandidates = maxCandidates;

  final CursorCatalogRepository _repository;
  final CursorCatalogTracker _tracker;
  final Duration _totalTimeout;
  final int _maxCandidates;
  Future<void>? _inFlight;
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

      final operation = _probe(scope: scope);
      _inFlight = operation;
      try {
        await operation;
      } finally {
        if (identical(_inFlight, operation)) _inFlight = null;
      }
      return;
    }
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

  Future<void> _probe({required String scope}) async {
    final stopwatch = Stopwatch()..start();
    try {
      final supported = await _repository.open(
        timeout: _remaining(stopwatch: stopwatch),
      );
      if (!supported) {
        _tracker.recordOutcome(
          scope: scope,
          outcome: CursorCatalogProbeOutcome.exhausted,
        );
        return;
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
          _tracker.applySnapshot(
            snapshot: snapshot,
            fromNewSession: false,
            thoughtLevelModelId: null,
            captureThoughtLevelDefault: false,
          );
          if (_tracker.isComplete) break;
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

      if (_tracker.isComplete) {
        _tracker.recordOutcome(
          scope: scope,
          outcome: CursorCatalogProbeOutcome.complete,
        );
        return;
      }

      final inspectedBoundedCandidates = attempted == ordered.length || attempted == _maxCandidates;
      if (candidateResult.exhaustive && !loadFailed && inspectedBoundedCandidates) {
        _tracker.recordOutcome(
          scope: scope,
          outcome: CursorCatalogProbeOutcome.exhausted,
        );
        return;
      }

      _recordRetryableFailure(scope: scope);
    } on TimeoutException catch (error, stack) {
      Log.w(
        "[cursor] catalog probe timed out (scope=$scope)",
        error,
        stack,
      );
      _recordRetryableFailure(scope: scope);
    } on Object catch (error, stack) {
      Log.w(
        "[cursor] catalog probe failed (scope=$scope)",
        error,
        stack,
      );
      _recordRetryableFailure(scope: scope);
    } finally {
      await _resetRepository(
        failureMessage: "[cursor] failed to stop catalog probe process (scope=$scope)",
      );
    }
  }

  void _recordRetryableFailure({required String scope}) {
    _tracker.recordOutcome(
      scope: scope,
      outcome: CursorCatalogProbeOutcome.retryableFailure,
    );
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
