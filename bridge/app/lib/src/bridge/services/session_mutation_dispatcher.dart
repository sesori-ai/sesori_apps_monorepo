import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_operation.dart";
import "../repositories/session_repository.dart";
import "session_cleanup_result.dart";
import "session_operation_dispatcher.dart";

sealed class const LocalSessionMutation({required final Session session}) {
  const factory titleUpdated({required Session session}) = SessionTitleUpdated;

  const factory deleted({required Session session}) = SessionDeleted;
}

final class const SessionTitleUpdated({required super.session}) extends LocalSessionMutation;

final class const SessionDeleted({required super.session}) extends LocalSessionMutation;

/// Owns bridge-persisted session mutations and their backend propagation.
class SessionMutationDispatcher({
  required final SessionRepository _sessionRepository,
  required final SessionOperationDispatcher _sessionOperationDispatcher,
}) {
  final StreamController<LocalSessionMutation> _mutationsController = StreamController<LocalSessionMutation>.broadcast(
    sync: true,
  );
  bool _disposed = false;
  Future<void>? _disposeFuture;

  Stream<LocalSessionMutation> get mutations => _mutationsController.stream;

  Future<Session> renameSession({required String sessionId, required String title}) {
    if (_disposed) return Future.error(StateError("SessionMutationDispatcher is disposed"));
    return _sessionOperationDispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.renameSession,
      body: () => _renameSessionAlreadyReserved(sessionId: sessionId, title: title),
    );
  }

  Future<Session?> applyGeneratedTitle({required String sessionId, required String title}) {
    if (_disposed) return Future.error(StateError("SessionMutationDispatcher is disposed"));
    return _sessionOperationDispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.applyGeneratedTitle,
      body: () => _applyGeneratedTitleAlreadyReserved(sessionId: sessionId, title: title),
    );
  }

  /// Runs [cleanup] and the delete under the family lock, then hands the
  /// deleted subtree to [onDeleted] while that lock is still held, so
  /// store-spanning cleanup sees exactly what was removed.
  Future<CleanupResult> deleteSession({
    required String sessionId,
    required Future<CleanupResult> Function() cleanup,
    required Future<void> Function(List<String> deletedSessionIds) onDeleted,
  }) {
    if (_disposed) throw StateError("SessionMutationDispatcher is disposed");
    return _sessionOperationDispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.deleteSession,
      body: () async {
        final cleanupResult = await cleanup();
        if (cleanupResult is CleanupRejected) return cleanupResult;
        final deleted = await _sessionRepository.deleteSession(sessionId: sessionId);
        await onDeleted(deleted.sessionIds);
        _mutationsController.add(LocalSessionMutation.deleted(session: deleted.session));
        return cleanupResult;
      },
    );
  }

  Future<void> dispose() {
    _disposed = true;
    return _disposeFuture ??= _mutationsController.close();
  }

  Future<Session> _renameSessionAlreadyReserved({required String sessionId, required String title}) async {
    final stored = await _sessionRepository.setSessionTitleIfStored(sessionId: sessionId, title: title);
    final renamed = stored ? await _sessionRepository.getCatalogSession(sessionId: sessionId) : null;
    if (renamed == null) {
      throw PluginOperationException.notFound(
        SessionOperation.renameSession.name,
        message: "session $sessionId was not found",
      );
    }
    _mutationsController.add(LocalSessionMutation.titleUpdated(session: renamed));
    await _propagateTitle(sessionId: sessionId, title: title);
    return renamed;
  }

  Future<Session?> _applyGeneratedTitleAlreadyReserved({
    required String sessionId,
    required String title,
  }) async {
    final updated = await _sessionRepository.setGeneratedSessionTitleIfAbsent(
      sessionId: sessionId,
      title: title,
    );
    if (updated == null) return null;
    _mutationsController.add(LocalSessionMutation.titleUpdated(session: updated));
    await _propagateTitle(sessionId: sessionId, title: title);
    return updated;
  }

  Future<void> _propagateTitle({
    required String sessionId,
    required String title,
  }) async {
    try {
      await _sessionRepository.renameSession(sessionId: sessionId, title: title);
    } catch (error, stackTrace) {
      Log.w("Could not propagate title for session $sessionId to its plugin", error, stackTrace);
    }
  }
}
