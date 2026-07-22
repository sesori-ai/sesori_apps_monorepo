import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_operation.dart";
import "../repositories/session_repository.dart";

/// Serializes bridge-owned session mutations that share pending-title state.
class SessionMutationDispatcher {
  static const _backendTitleGuardDuration = Duration(seconds: 1);

  final SessionRepository _sessionRepository;
  final StreamController<Session> _deletedSessionsController = StreamController<Session>.broadcast(sync: true);
  final Map<String, String?> _pendingTitles = {};
  final Map<String, ({String title, DateTime? expiresAt})> _backendTitleGuards = {};
  Future<void> _tail = Future<void>.value();
  Future<void> _backendTail = Future<void>.value();
  bool _disposed = false;

  SessionMutationDispatcher({required SessionRepository sessionRepository}) : _sessionRepository = sessionRepository;

  Stream<Session> get deletedSessions => _deletedSessionsController.stream;

  Future<void> captureTitle({required String sessionId, required String? title}) {
    return _serialized(() async {
      final guard = _backendTitleGuards[sessionId];
      if (guard != null) {
        final active = guard.expiresAt == null || DateTime.now().isBefore(guard.expiresAt!);
        if (active && guard.title != title) return;
        _backendTitleGuards.remove(sessionId);
      }
      await _captureTitle(sessionId: sessionId, title: title);
    });
  }

  /// Completes after the authoritative DB title is stored. Backend propagation
  /// continues on its own serialized tail so later DB writes stay immediate
  /// while delete and dispose still cannot overtake backend synchronization.
  Future<Session> renameSession({required String sessionId, required String title}) {
    return _serialized(() async {
      final stored = await _sessionRepository.setSessionTitleIfStored(sessionId: sessionId, title: title);
      final renamed = stored ? await _sessionRepository.getCatalogSession(sessionId: sessionId) : null;
      if (renamed == null) {
        throw PluginOperationException.notFound(
          SessionOperation.renameSession.name,
          message: "session $sessionId was not found",
        );
      }
      _backendTitleGuards[sessionId] = (title: title, expiresAt: null);
      unawaited(
        _serializedBackend(() => _propagateTitle(sessionId: sessionId, title: title)),
      );
      return renamed;
    });
  }

  Future<void> applyPendingTitle({required String sessionId}) {
    return _serialized(() async {
      if (!_pendingTitles.containsKey(sessionId)) return;
      final stored = await _sessionRepository.setSessionTitleIfStored(
        sessionId: sessionId,
        title: _pendingTitles[sessionId],
      );
      if (stored) _pendingTitles.remove(sessionId);
    });
  }

  Future<void> deleteSession({required String sessionId}) {
    if (_disposed) return Future.error(StateError("SessionMutationDispatcher is disposed"));
    return _serialized(() async {
      final deleted = await _serializedBackend(() => _sessionRepository.deleteSession(sessionId: sessionId));
      _pendingTitles.remove(sessionId);
      _backendTitleGuards.remove(sessionId);
      _deletedSessionsController.add(deleted);
    });
  }

  Future<void> drain() => _serialized(() => _serializedBackend(() async {}));

  Future<void> dispose() {
    if (_disposed) return Future.value();
    _disposed = true;
    return _serialized(() async {
      await _serializedBackend(() async {});
      _backendTitleGuards.clear();
      await _deletedSessionsController.close();
    });
  }

  Future<void> _propagateTitle({required String sessionId, required String title}) async {
    try {
      await _sessionRepository.renameSession(sessionId: sessionId, title: title);
    } catch (error, stackTrace) {
      Log.w("Could not propagate title for session $sessionId to its plugin", error, stackTrace);
    } finally {
      final guard = _backendTitleGuards[sessionId];
      if (guard?.title == title && guard?.expiresAt == null) {
        _backendTitleGuards[sessionId] = (
          title: title,
          expiresAt: DateTime.now().add(_backendTitleGuardDuration),
        );
      }
    }
  }

  Future<void> _captureTitle({required String sessionId, required String? title}) async {
    if (await _sessionRepository.isSessionTombstoned(sessionId: sessionId)) return;
    final stored = await _sessionRepository.setSessionTitleIfStored(
      sessionId: sessionId,
      title: title,
    );
    if (!stored) _pendingTitles[sessionId] = title;
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final previous = _tail;
    final release = Completer<void>();
    _tail = release.future;
    return () async {
      await previous;
      try {
        return await operation();
      } finally {
        release.complete();
      }
    }();
  }

  Future<T> _serializedBackend<T>(Future<T> Function() operation) {
    final previous = _backendTail;
    final release = Completer<void>();
    _backendTail = release.future;
    return () async {
      await previous;
      try {
        return await operation();
      } finally {
        release.complete();
      }
    }();
  }
}
