import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../repositories/session_repository.dart";

/// Retries physical cleanup for permanently tombstoned backend sessions.
class DeletedSessionStorageCleanupService {
  DeletedSessionStorageCleanupService({
    required SessionRepository sessionRepository,
  }) : _sessionRepository = sessionRepository;

  final SessionRepository _sessionRepository;

  Future<void> reconcile() async {
    try {
      await _reconcile();
    } on Object catch (error, stackTrace) {
      Log.w(
        "Deleted session storage reconciliation failed; continuing startup",
        error,
        stackTrace,
      );
    }
  }

  Future<void> _reconcile() async {
    for (final pluginId in await _sessionRepository.persistedSessionCleanupPluginIds) {
      final Set<String> sessionIds;
      try {
        sessionIds = await _sessionRepository.getTombstonedBackendSessionIdsForCleanup(
          pluginId: pluginId,
        );
      } on Object catch (error, stackTrace) {
        Log.w(
          "Failed to read deleted sessions for persisted storage cleanup "
          "(plugin=$pluginId); retrying next startup",
          error,
          stackTrace,
        );
        continue;
      }

      final orderedSessionIds = sessionIds.toList(growable: false)..sort();
      for (final sessionId in orderedSessionIds) {
        try {
          await _sessionRepository.deletePersistedSession(
            pluginId: pluginId,
            backendSessionId: sessionId,
          );
        } on Object catch (error, stackTrace) {
          Log.w(
            "Failed to delete persisted session storage "
            "(plugin=$pluginId, sessionId=$sessionId); retrying next startup",
            error,
            stackTrace,
          );
        }
      }
    }
  }
}
