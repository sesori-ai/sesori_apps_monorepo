import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_operation.dart";
import "../repositories/session_interruption_repository.dart";
import "../repositories/session_repository.dart";
import "session_cleanup_result.dart";
import "session_operation_dispatcher.dart";

sealed class const LocalSessionMutation({required final Session session}) {
  const factory titleUpdated({required Session session}) = SessionTitleUpdated;

  const factory deleted({required Session session}) = SessionDeleted;
}

final class const SessionTitleUpdated({required super.session}) extends LocalSessionMutation;

final class const SessionDeleted({required super.session}) extends LocalSessionMutation;

final class const SessionContinuationUpdated({required super.session}) extends LocalSessionMutation;

/// The session's interruption was recorded, acknowledged or re-anchored.
final class const SessionInterruptionUpdated({required super.session}) extends LocalSessionMutation;

final class const SessionApprovalOverrideUpdated({required super.session}) extends LocalSessionMutation;

final class const SessionPinnedUpdated({required super.session}) extends LocalSessionMutation;

final class const SessionArchived({required super.session}) extends LocalSessionMutation;

/// An edit removed these messages from the session's conversation; each
/// reaches the history store and every client as a removed message.
final class const SessionMessagesRewound({
  required super.session,

  /// Exact ids, never a range: the edited prompt's own messages may already
  /// be stored.
  required final List<String> removedMessageIds,
}) extends LocalSessionMutation;

/// Owns bridge-persisted session mutations and their backend propagation.
class SessionMutationDispatcher({
  required final SessionRepository _sessionRepository,
  required final SessionOperationDispatcher _sessionOperationDispatcher,
  required final SessionInterruptionRepository _interruptions,
}) {
  final StreamController<LocalSessionMutation> _mutationsController = StreamController<LocalSessionMutation>.broadcast(
    sync: true,
  );
  final Set<String> _sessionIdsSuppressedFromEvents = <String>{};
  bool _disposed = false;
  Future<void>? _disposeFuture;

  Stream<LocalSessionMutation> get mutations => _mutationsController.stream;

  void continuationUpdated({required Session session}) =>
      _mutationsController.add(SessionContinuationUpdated(session: session));

  /// Announces the session's changed interruption record. A session that is
  /// gone, or a bridge already shutting down, has no client to tell; the
  /// record itself is stored.
  Future<void> interruptionUpdated({required String sessionId}) async {
    final session = await _sessionRepository.getCatalogSession(sessionId: sessionId);
    if (session == null || _mutationsController.isClosed) return;
    _mutationsController.add(SessionInterruptionUpdated(session: session));
  }

  /// Acknowledges the session's interruption, because the user opened the
  /// session or the bridge accepted a prompt for it, and announces it when it
  /// flipped. Best effort: the trigger already succeeded, so a failure is only
  /// logged.
  Future<void> acknowledgeInterruption({required String sessionId}) async {
    try {
      if (!await _interruptions.acknowledge(sessionId: sessionId)) return;
      await interruptionUpdated(sessionId: sessionId);
    } on Object catch (error, stackTrace) {
      Log.w("Could not acknowledge the interruption of session $sessionId", error, stackTrace);
    }
  }

  void sessionArchived({required Session session}) => _mutationsController.add(SessionArchived(session: session));

  void messagesRewound({required Session session, required List<String> removedMessageIds}) =>
      _mutationsController.add(SessionMessagesRewound(session: session, removedMessageIds: removedMessageIds));

  bool shouldSuppressEventsForSession({required String sessionId}) {
    return _sessionIdsSuppressedFromEvents.contains(sessionId);
  }

  Future<Session> renameSession({required String sessionId, required String title}) {
    if (_disposed) return Future.error(StateError("SessionMutationDispatcher is disposed"));
    return _sessionOperationDispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.renameSession,
      body: () => _renameSessionAlreadyReserved(sessionId: sessionId, title: title),
    );
  }

  /// Stores the session's approval override (null follows the bridge YOLO
  /// setting) and announces the updated session to every client.
  Future<Session> setApprovalOverride({
    required String sessionId,
    required SessionApprovalMode? approvalOverride,
  }) {
    if (_disposed) return Future.error(StateError("SessionMutationDispatcher is disposed"));
    return _sessionOperationDispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.setApprovalOverride,
      body: () async {
        final updated = await _sessionRepository.setApprovalOverride(
          sessionId: sessionId,
          approvalOverride: approvalOverride,
        );
        if (updated == null) {
          throw PluginOperationException.notFound(
            operation: SessionOperation.setApprovalOverride.name,
            message: "session $sessionId was not found",
          );
        }
        _mutationsController.add(SessionApprovalOverrideUpdated(session: updated));
        return updated;
      },
    );
  }

  /// Pins or unpins the session and announces the updated session to every
  /// client. Only an unarchived root session can be pinned; anything else,
  /// like a missing session, is not found.
  Future<Session> setPinned({required String sessionId, required bool pinned}) {
    if (_disposed) return Future.error(StateError("SessionMutationDispatcher is disposed"));
    return _sessionOperationDispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.setPinned,
      body: () async {
        final updated = await _sessionRepository.setPinned(sessionId: sessionId, pinned: pinned);
        if (updated == null) {
          throw PluginOperationException.notFound(
            operation: SessionOperation.setPinned.name,
            message: "session $sessionId was not found or cannot be pinned",
          );
        }
        _mutationsController.add(SessionPinnedUpdated(session: updated));
        return updated;
      },
    );
  }

  /// Places pinned [sessionId] directly below pinned [afterSessionId], or at
  /// the top of the pinned group when it is null, and announces every
  /// session whose place changed to every client, top first, so a list
  /// applying them one at a time never shows a row out of place. Either
  /// session not being pinned is not found.
  Future<List<Session>> movePin({required String sessionId, required String? afterSessionId}) {
    if (_disposed) return Future.error(StateError("SessionMutationDispatcher is disposed"));
    return _sessionOperationDispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.movePin,
      body: () async {
        final moved = await _sessionRepository.movePin(sessionId: sessionId, afterSessionId: afterSessionId);
        if (moved == null) {
          throw PluginOperationException.notFound(
            operation: SessionOperation.movePin.name,
            message: "session $sessionId or $afterSessionId is not pinned",
          );
        }
        for (final session in moved) {
          _mutationsController.add(SessionPinnedUpdated(session: session));
        }
        return moved;
      },
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
    required Future<void> Function(DeletedSessionSubtree deleted) onDeleted,
  }) {
    if (_disposed) throw StateError("SessionMutationDispatcher is disposed");
    return _sessionOperationDispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.deleteSession,
      body: () async {
        final newlySuppressedSessionIds = <String>{};
        var deletionCommitted = false;
        try {
          if (_sessionIdsSuppressedFromEvents.add(sessionId)) {
            newlySuppressedSessionIds.add(sessionId);
          }
          for (final subtreeSessionId in await _sessionRepository.getSessionSubtreeIds(sessionId: sessionId)) {
            if (_sessionIdsSuppressedFromEvents.add(subtreeSessionId)) {
              newlySuppressedSessionIds.add(subtreeSessionId);
            }
          }
          final cleanupResult = await cleanup();
          if (cleanupResult is CleanupRejected) return cleanupResult;
          final deleted = await _sessionRepository.deleteSession(sessionId: sessionId);
          _sessionIdsSuppressedFromEvents.addAll(deleted.sessionIds);
          deletionCommitted = true;
          await onDeleted(deleted);
          _mutationsController.add(LocalSessionMutation.deleted(session: deleted.session));
          return cleanupResult;
        } finally {
          if (!deletionCommitted) {
            _sessionIdsSuppressedFromEvents.removeAll(newlySuppressedSessionIds);
          }
        }
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
        operation: SessionOperation.renameSession.name,
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
