import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_operation.dart";
import "../repositories/session_repository.dart";

/// Serializes bridge-owned session mutations that share pending-title state.
class SessionMutationDispatcher {
  final SessionRepository _sessionRepository;
  final StreamController<Session> _deletedSessionsController = StreamController<Session>.broadcast(sync: true);
  final Map<String, String?> _pendingTitles = {};
  // Tracks local renames until their matching backend title event arrives.
  final Map<String, String> _renameTitlesAwaitingEvents = {};
  // Each superseded local title consumes at most one delayed backend event.
  final Map<String, Set<String>> _supersededRenameTitles = {};
  Future<void> _tail = Future<void>.value();
  bool _disposed = false;

  SessionMutationDispatcher({required SessionRepository sessionRepository}) : _sessionRepository = sessionRepository;

  Stream<Session> get deletedSessions => _deletedSessionsController.stream;

  Future<void> captureTitle({required String sessionId, required String? title}) {
    return _serialized(() async {
      final superseded = _supersededRenameTitles[sessionId];
      if (superseded?.remove(title) ?? false) {
        if (superseded!.isEmpty) _supersededRenameTitles.remove(sessionId);
        return;
      }
      _renameTitlesAwaitingEvents.remove(sessionId);
      await _captureTitle(sessionId: sessionId, title: title);
    });
  }

  /// Completes after the authoritative DB title is stored. Backend propagation
  /// continues on the serialized tail so delete and dispose cannot overtake it.
  Future<Session> renameSession({required String sessionId, required String title}) {
    final persistedResult = Completer<Session>();
    unawaited(
      _serialized(() async {
        try {
          final stored = await _sessionRepository.setSessionTitleIfStored(sessionId: sessionId, title: title);
          final renamed = stored ? await _sessionRepository.getCatalogSession(sessionId: sessionId) : null;
          if (renamed == null) {
            throw PluginOperationException.notFound(
              SessionOperation.renameSession.name,
              message: "session $sessionId was not found",
            );
          }
          final previousTitle = _renameTitlesAwaitingEvents[sessionId];
          if (previousTitle != null && previousTitle != title) {
            (_supersededRenameTitles[sessionId] ??= {}).add(previousTitle);
          }
          _renameTitlesAwaitingEvents[sessionId] = title;
          final superseded = _supersededRenameTitles[sessionId];
          superseded?.remove(title);
          if (superseded?.isEmpty ?? false) _supersededRenameTitles.remove(sessionId);
          persistedResult.complete(renamed);
        } catch (error, stackTrace) {
          persistedResult.completeError(error, stackTrace);
          return;
        }
        try {
          await _sessionRepository.renameSession(sessionId: sessionId, title: title);
        } catch (error, stackTrace) {
          if (_renameTitlesAwaitingEvents[sessionId] == title) {
            _renameTitlesAwaitingEvents.remove(sessionId);
          }
          Log.w("Could not propagate title for session $sessionId to its plugin", error, stackTrace);
        }
      }),
    );
    return persistedResult.future;
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
      final deleted = await _sessionRepository.deleteSession(sessionId: sessionId);
      _pendingTitles.remove(sessionId);
      _renameTitlesAwaitingEvents.remove(sessionId);
      _supersededRenameTitles.remove(sessionId);
      _deletedSessionsController.add(deleted);
    });
  }

  Future<void> drain() => _serialized(() async {});

  Future<void> dispose() {
    if (_disposed) return Future.value();
    _disposed = true;
    return _serialized(() async {
      _renameTitlesAwaitingEvents.clear();
      _supersededRenameTitles.clear();
      await _deletedSessionsController.close();
    });
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
}
