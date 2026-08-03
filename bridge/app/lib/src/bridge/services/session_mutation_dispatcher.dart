import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_operation.dart";
import "../repositories/session_repository.dart";
import "session_cleanup_result.dart";
import "session_operation_dispatcher.dart";

/// Owns bridge-persisted session mutations and their backend propagation.
class SessionMutationDispatcher {
  final SessionRepository _sessionRepository;
  final SessionOperationDispatcher _sessionOperationDispatcher;
  final StreamController<Session> _deletedSessionsController = StreamController<Session>.broadcast(sync: true);
  bool _disposed = false;
  Future<void>? _disposeFuture;

  SessionMutationDispatcher({
    required SessionRepository sessionRepository,
    required SessionOperationDispatcher sessionOperationDispatcher,
  }) : _sessionRepository = sessionRepository,
       _sessionOperationDispatcher = sessionOperationDispatcher;

  Stream<Session> get deletedSessions => _deletedSessionsController.stream;

  Future<Session> renameSession({required String sessionId, required String title}) {
    if (_disposed) return Future.error(StateError("SessionMutationDispatcher is disposed"));
    return _sessionOperationDispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.renameSession,
      interaction: null,
      body: () => _renameSessionAlreadyReserved(sessionId: sessionId, title: title),
    );
  }

  Future<Session> renameInitialSession({
    required UnpublishedSessionBinding binding,
    required String title,
  }) {
    if (_disposed) return Future.error(StateError("SessionMutationDispatcher is disposed"));
    return _sessionOperationDispatcher.dispatchInitial(
      binding: binding,
      body: () async {
        final renamed = await _sessionRepository.setInitialSessionTitle(
          binding: binding,
          title: title,
        );
        await _propagateTitle(
          sessionId: binding.session.id,
          propagate: () => _sessionRepository.renameInitialSession(binding: binding, title: title),
        );
        return renamed;
      },
    );
  }

  Future<CleanupResult> deleteSession({
    required String sessionId,
    required Future<CleanupResult> Function() cleanup,
  }) {
    if (_disposed) throw StateError("SessionMutationDispatcher is disposed");
    return _sessionOperationDispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.deleteSession,
      interaction: null,
      body: () async {
        final cleanupResult = await cleanup();
        if (cleanupResult is CleanupRejected) return cleanupResult;
        final deleted = await _sessionRepository.deleteSession(sessionId: sessionId);
        _deletedSessionsController.add(deleted);
        return cleanupResult;
      },
    );
  }

  Future<void> dispose() {
    _disposed = true;
    return _disposeFuture ??= _deletedSessionsController.close();
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
    await _propagateTitle(
      sessionId: sessionId,
      propagate: () => _sessionRepository.renameSession(sessionId: sessionId, title: title),
    );
    return renamed;
  }

  Future<void> _propagateTitle({
    required String sessionId,
    required Future<Object?> Function() propagate,
  }) async {
    try {
      await propagate();
    } catch (error, stackTrace) {
      Log.w("Could not propagate title for session $sessionId to its plugin", error, stackTrace);
    }
  }
}
