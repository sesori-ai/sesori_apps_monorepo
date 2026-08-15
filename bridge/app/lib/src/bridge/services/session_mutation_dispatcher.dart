import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/session_operation.dart";
import "../repositories/session_repository.dart";
import "session_cleanup_result.dart";
import "session_operation_dispatcher.dart";
import "worktree_service.dart";

sealed class const LocalSessionMutation({required final Session session}) {
  const factory titleUpdated({required Session session}) = SessionTitleUpdated;

  const factory branchUpdated({required Session session}) = SessionBranchUpdated;

  const factory deleted({required Session session}) = SessionDeleted;
}

final class const SessionTitleUpdated({required super.session}) extends LocalSessionMutation;

final class const SessionBranchUpdated({required super.session}) extends LocalSessionMutation;

final class const SessionDeleted({required super.session}) extends LocalSessionMutation;

/// Owns bridge-persisted session mutations and their backend propagation.
class SessionMutationDispatcher({
  required final SessionRepository _sessionRepository,
  required final SessionOperationDispatcher _sessionOperationDispatcher,
  required final WorktreeService _worktreeService,
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

  Future<Session?> applyGeneratedBranchName({
    required String sessionId,
    required String branchName,
  }) {
    if (_disposed) return Future.error(StateError("SessionMutationDispatcher is disposed"));
    return _sessionOperationDispatcher.dispatch(
      sessionId: sessionId,
      operation: SessionOperation.applyGeneratedBranchName,
      body: () => _applyGeneratedBranchNameAlreadyReserved(
        sessionId: sessionId,
        branchName: branchName,
      ),
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

  Future<Session?> _applyGeneratedBranchNameAlreadyReserved({
    required String sessionId,
    required String branchName,
  }) async {
    final stored = await _sessionRepository.getStoredSession(sessionId: sessionId);
    final worktreePath = stored?.worktreePath;
    final initialBranchName = stored?.branchName;
    if (stored == null ||
        stored.parentSessionId != null ||
        !stored.isDedicated ||
        worktreePath == null ||
        initialBranchName == null) {
      return null;
    }

    final rename = await _worktreeService.renameGeneratedBranch(
      worktreePath: worktreePath,
      initialBranchName: initialBranchName,
      generatedBranchName: branchName,
    );
    if (rename is GeneratedBranchRenameSkipped) return null;
    final generatedBranchName = (rename as GeneratedBranchRenamed).branchName;

    final bool persisted;
    try {
      persisted = await _sessionRepository.replaceGeneratedSessionBranch(
        sessionId: sessionId,
        expectedBranchName: initialBranchName,
        branchName: generatedBranchName,
      );
    } on Object catch (error, stackTrace) {
      try {
        await _worktreeService.rollbackGeneratedBranchRename(
          worktreePath: worktreePath,
          generatedBranchName: generatedBranchName,
          initialBranchName: initialBranchName,
        );
      } on Object catch (rollbackError, rollbackStackTrace) {
        Log.w(
          "Could not roll back an unpersisted generated branch rename for session $sessionId",
          rollbackError,
          rollbackStackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    if (!persisted) {
      try {
        await _worktreeService.rollbackGeneratedBranchRename(
          worktreePath: worktreePath,
          generatedBranchName: generatedBranchName,
          initialBranchName: initialBranchName,
        );
        Log.w("Generated branch persistence changed for session $sessionId; restored its initial branch");
      } on Object catch (rollbackError, rollbackStackTrace) {
        Log.w(
          "Could not roll back a generated branch after conditional persistence changed for session $sessionId",
          rollbackError,
          rollbackStackTrace,
        );
      }
      return null;
    }
    final updated = await _sessionRepository.getCatalogSession(sessionId: sessionId);
    if (updated == null) return null;
    _mutationsController.add(LocalSessionMutation.branchUpdated(session: updated));
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
