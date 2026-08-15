import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../repositories/session_repository.dart";

/// Retries physical cleanup for permanently tombstoned backend sessions.
class DeletedSessionStorageCleanupService({
  required final SessionRepository _sessionRepository,
}) {
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
      final Set<TombstonedSessionCleanup> sessions;
      try {
        sessions = await _sessionRepository.getTombstonedSessionsForCleanup(
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

      final orderedSessions = sessions.toList(growable: false)
        ..sort((a, b) => a.backendSessionId.compareTo(b.backendSessionId));
      for (final session in orderedSessions) {
        try {
          await _sessionRepository.deletePersistedSession(
            pluginId: pluginId,
            backendSessionId: session.backendSessionId,
            directory: session.directory,
          );
        } on Object catch (error, stackTrace) {
          Log.w(
            "Failed to delete persisted session storage "
            "(plugin=$pluginId, sessionId=${session.backendSessionId}); retrying next startup",
            error,
            stackTrace,
          );
        }
      }
    }
  }
}
