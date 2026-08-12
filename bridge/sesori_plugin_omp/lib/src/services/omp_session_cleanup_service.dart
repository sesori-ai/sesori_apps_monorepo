import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../repositories/omp_session_cleanup_repository.dart";

/// Finds and deletes OMP-owned persisted session artifacts through ACP.
class OmpSessionCleanupService {
  OmpSessionCleanupService({
    required OmpSessionCleanupRepository repository,
    required String launchDirectory,
    required Duration totalTimeout,
    required int maxPages,
  }) : _repository = repository,
       _launchDirectory = launchDirectory,
       _totalTimeout = totalTimeout,
       _maxPages = maxPages;

  final OmpSessionCleanupRepository _repository;
  final String _launchDirectory;
  final Duration _totalTimeout;
  final int _maxPages;

  Future<void> deletePersistedSession({required String backendSessionId}) async {
    final stopwatch = Stopwatch()..start();
    String? fallbackDirectory;
    try {
      await _repository.open(
        cwd: _launchDirectory,
        timeout: _remaining(stopwatch),
      );

      String? cursor;
      for (var page = 0; page < _maxPages; page++) {
        final result = await _repository.listPage(
          cursor: cursor,
          timeout: _remaining(stopwatch),
        );
        for (final session in result.sessions) {
          if (session.sessionId != backendSessionId) continue;
          final cwd = session.cwd;
          fallbackDirectory = cwd == null || cwd.trim().isEmpty ? await _repository.createScratchDirectory() : null;
          await _deleteResident(
            sessionId: backendSessionId,
            cwd: fallbackDirectory ?? cwd!,
            stopwatch: stopwatch,
          );
          return;
        }
        final next = result.nextCursor;
        if (next == null || next.isEmpty) return;
        cursor = next;
      }

      fallbackDirectory = await _repository.createScratchDirectory();
      await _deleteResident(
        sessionId: backendSessionId,
        cwd: fallbackDirectory,
        stopwatch: stopwatch,
      );
    } finally {
      if (fallbackDirectory != null) {
        try {
          await _repository.deleteScratchDirectory();
        } on Object catch (error, stack) {
          Log.w("[omp] failed to remove cleanup scratch directory", error, stack);
        }
      }
      await _repository.settle();
    }
  }

  Future<void> dispose() => _repository.dispose();

  Future<void> _deleteResident({
    required String sessionId,
    required String cwd,
    required Stopwatch stopwatch,
  }) async {
    await _repository.resume(
      sessionId: sessionId,
      cwd: cwd,
      timeout: _remaining(stopwatch),
    );
    await _repository.delete(
      sessionId: sessionId,
      timeout: _remaining(stopwatch),
    );
    await _repository.close(
      sessionId: sessionId,
      timeout: _remaining(stopwatch),
    );
  }

  Duration _remaining(Stopwatch stopwatch) {
    final remaining = _totalTimeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw TimeoutException("OMP persisted cleanup exceeded $_totalTimeout");
    }
    return remaining;
  }
}
