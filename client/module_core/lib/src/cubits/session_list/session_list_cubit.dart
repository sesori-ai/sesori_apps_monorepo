import "dart:async";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart" hide SessionCleanupRejection;

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/sse_event.dart";
import "../../logging/logging.dart";
import "../../repositories/models/session_cleanup_rejection.dart";
import "../../repositories/session_repository.dart";
import "../../services/models/optimistic_rename_tracker.dart";
import "../../services/models/session_cleanup_outcome.dart";
import "../../services/models/session_list_filter.dart";
import "../../services/models/session_list_item_state.dart";
import "../../services/session_cleanup_service.dart";
import "../../services/session_list_service.dart";
import "../../services/session_unseen_tracker.dart";
import "../../services/sse_event_tracker.dart";
import "session_list_state.dart";

/// One project's session actions (rename, delete, mark seen) for the
/// rows a list already shows. It holds only the caller's [sessions] and those
/// passed to [updateActionSession], and keeps them in step with bridge events.
/// It never fetches the project's session list.
class SessionListCubit({
  required List<Session> sessions,
  required final SessionRepository _sessionRepository,
  required final SessionCleanupService _sessionCleanupService,
  required final SessionListService _sessionListService,
  required final ConnectionService _connectionService,
  required final SseEventTracker _sseEventTracker,
  required final SessionUnseenTracker _sessionUnseenTracker,
  required final String _projectId,
  required final FailureReporter _failureReporter,
}) extends Cubit<SessionListState> {
  final CompositeSubscription _subscriptions = CompositeSubscription();
  int _pendingActionOperations = 0;
  Completer<void>? _actionOperationsDrained;
  SessionCleanupRejection? _lastCleanupRejection;

  /// The sessions this cubit acts on; the state shows only the unarchived ones.
  List<Session> _allSessions = sessions;

  this : super(const SessionListState(sessions: [], activeSessionIds: {}, unseenBySessionId: {})) {
    _emitFiltered();
    _subscriptions.add(_connectionService.events.listen(_handleEvent));
    _subscriptions.add(_sseEventTracker.sessionActivity.listen((_) => _emitFiltered()));
    _subscriptions.add(_sessionUnseenTracker.sessionUnseen.listen((_) => _emitFiltered()));
  }

  /// Synchronizes the named menu target from the consumer's current inventory
  /// without replacing other rows (which may still have their own mutation in
  /// flight).
  void updateActionSession({required Session session}) {
    _allSessions = _sessionListService.upsertSession(sessions: _allSessions, session: session);
    _emitFiltered();
  }

  String get projectId => _projectId;

  SessionCleanupRejection? get lastCleanupRejection => _lastCleanupRejection;

  void _handleEvent(SseEvent event) {
    try {
      if (isClosed) return;
      logt("[SessionList] event received: ${event.data.runtimeType}");
      final data = event.data;
      switch (data) {
        case SesoriSessionUpdated(:final info):
          _onSessionUpdated(info);
        case SesoriSessionDeleted(:final info):
          _onSessionDeleted(info);
        // A new session is not one this cubit was given.
        case SesoriSessionCreated() ||
            SesoriServerConnected() ||
            SesoriServerHeartbeat() ||
            SesoriServerInstanceDisposed() ||
            SesoriGlobalDisposed() ||
            SesoriCatalogImportProgress() ||
            SesoriMcpInventoryChanged() ||
            SesoriMcpAuthenticationChanged() ||
            SesoriPluginManagementChanged() ||
            SesoriPluginInstallProgress() ||
            SesoriPluginAuthenticationProgress() ||
            SesoriSessionOptionsUpdated() ||
            SesoriSessionDiff() ||
            SesoriSessionError() ||
            SesoriSessionCompacted() ||
            SesoriSessionPromptSettled() ||
            SesoriSessionStatus() ||
            SesoriMessageUpdated() ||
            SesoriMessageRemoved() ||
            SesoriMessagePartUpdated() ||
            SesoriMessagePartDelta() ||
            SesoriMessagePartRemoved() ||
            SesoriPermissionAsked() ||
            SesoriPermissionReplied() ||
            SesoriPermissionUpdated() ||
            SesoriQuestionAsked() ||
            SesoriQuestionReplied() ||
            SesoriQuestionRejected() ||
            SesoriCommandExecuted() ||
            SesoriTodoUpdated() ||
            SesoriSessionPromptDefaultsChanged() ||
            SesoriSessionQueuedPrompts() ||
            SesoriProjectsSummary() ||
            SesoriProjectUpdated() ||
            SesoriVcsBranchUpdated() ||
            SesoriFileEdited() ||
            SesoriInstallationUpdateAvailable() ||
            SesoriTuiToastShow() ||
            // Unseen changes are consumed via the SessionUnseenTracker stream.
            SesoriSessionUnseenChanged():
          break;
      }
    } catch (e, st) {
      loge("SSE event handler error", e, st);
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "session_list_event:${event.data.runtimeType.toString()}",
              fatal: false,
              reason: "Failed to handle session list event",
              information: [event.data.runtimeType.toString()],
            )
            .catchError((Object error, StackTrace stackTrace) {
              loge("Failed to report session list SSE handler error", error, stackTrace);
            }),
      );
    }
  }

  /// Merges the REST-loaded `Session.unseen` with the live tracker map (the
  /// tracker takes precedence once it has an entry).
  Map<String, bool> _unseenBySessionId(List<Session> sessions) {
    final live = _sessionUnseenTracker.currentSessionUnseen[_projectId] ?? const <String, SessionListItemState>{};
    return {
      for (final session in sessions) session.id: live[session.id]?.unseen ?? session.unseen,
    };
  }

  /// Marks a session read (clears its bold) or unread (forces bold). Applied
  /// optimistically to the tracker so the row updates immediately; the bridge
  /// echo delivers the authoritative state (including the project aggregate)
  /// within the round trip. On failure, the tracker gets back the value it
  /// held before the optimistic write.
  Future<void> markSessionSeen({required String sessionId, required bool read}) => _runActionScopeOperation(
    operation: () => _markSessionSeen(sessionId: sessionId, read: read),
  );

  Future<void> _markSessionSeen({required String sessionId, required bool read}) async {
    final previous = _sessionUnseenTracker.applyLocalSessionUnseen(
      projectId: _projectId,
      sessionId: sessionId,
      unseen: !read,
    );
    _emitFiltered();
    void restore() => _sessionUnseenTracker.restoreLocalSessionUnseen(
      projectId: _projectId,
      sessionId: sessionId,
      previous: previous,
    );
    try {
      final response = await _sessionRepository.markSessionSeen(sessionId: sessionId, read: read);
      if (response case ErrorResponse(:final error)) {
        loge("Failed to mark session ${read ? "read" : "unread"}", error);
        restore();
      }
    } catch (e, st) {
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "session_list_mark_seen",
              fatal: false,
              reason: "Failed to mark session seen",
              information: [sessionId, "read=$read"],
            )
            .catchError((Object error, StackTrace stackTrace) {
              loge("Failed to report mark-seen error", error, stackTrace);
            }),
      );
      restore();
    }
  }

  /// Keeps an action-only owner usable while its confirmation UI is open.
  void Function() retainActionScope() {
    var released = false;
    _pendingActionOperations++;
    return () {
      if (released) return;
      released = true;
      _completeActionOperation();
    };
  }

  Future<T> _runActionScopeOperation<T>({required Future<T> Function() operation}) {
    final release = retainActionScope();
    return operation().whenComplete(release);
  }

  void _completeActionOperation() {
    _pendingActionOperations--;
    if (_pendingActionOperations != 0) return;
    _actionOperationsDrained?.complete();
    _actionOperationsDrained = null;
  }

  void _onSessionUpdated(Session session) {
    if (session.projectID != _projectId) {
      logt("[SessionList] session.updated ignored id=${session.id} reason=project_mismatch");
      return;
    }

    final index = _allSessions.indexWhere((s) => s.id == session.id);
    if (index < 0) return;

    _allSessions = _sessionListService.applySessionUpdatedEvent(
      sessions: _allSessions,
      existingSession: _allSessions[index],
      session: session,
    );
    logt("[SessionList] session.updated updated id=${session.id}");
    _emitFiltered();
  }

  void _onSessionDeleted(Session session) {
    if (session.projectID != _projectId) {
      logd("[SessionList] session.deleted ignored id=${session.id} reason=project_mismatch");
      return;
    }

    final before = _allSessions.length;
    _allSessions = _sessionListService.removeSession(
      sessions: _allSessions,
      sessionId: session.id,
    );
    if (_allSessions.length == before) {
      logd("[SessionList] session.deleted not_found id=${session.id}");
      return;
    }

    logd("[SessionList] session.deleted removed id=${session.id}");
    _emitFiltered();
  }

  // ---------------------------------------------------------------------------
  // Rename / Delete
  // ---------------------------------------------------------------------------

  /// Renames a session optimistically. Returns `false` after restoring the
  /// prior title when the bridge rejects the rename.
  Future<bool> renameSession({required String sessionId, required String title}) => _runActionScopeOperation(
    operation: () => _renameSession(sessionId: sessionId, title: title),
  );

  Future<bool> _renameSession({required String sessionId, required String title}) async {
    final index = _allSessions.indexWhere((session) => session.id == sessionId);
    if (index < 0) return false;

    final token = ++_nextRenameToken;
    final renameState = _renameStateBySessionId.putIfAbsent(
      sessionId,
      () => OptimisticRenameTracker(confirmedValue: _allSessions[index].title),
    );
    renameState.begin(token: token, value: title);
    _allSessions = _sessionListService.upsertSession(
      sessions: _allSessions,
      session: _allSessions[index].copyWith(title: title),
    );
    _emitFiltered();

    final ApiResponse<Session> response;
    try {
      response = await _sessionRepository.renameSession(sessionId: sessionId, title: title);
    } on Object {
      _completeSessionRename(
        sessionId: sessionId,
        token: token,
        title: title,
        succeeded: false,
      );
      return false;
    }

    switch (response) {
      case SuccessResponse():
        _completeSessionRename(
          sessionId: sessionId,
          token: token,
          title: title,
          succeeded: true,
        );
        return true;
      case ErrorResponse():
        _completeSessionRename(
          sessionId: sessionId,
          token: token,
          title: title,
          succeeded: false,
        );
        return false;
    }
  }

  void _completeSessionRename({
    required String sessionId,
    required int token,
    required String title,
    required bool succeeded,
  }) {
    final renameState = _renameStateBySessionId[sessionId];
    if (renameState == null) return;
    renameState.complete(token: token, value: title, succeeded: succeeded);
    if (!renameState.isSettled) {
      _emitFiltered();
      return;
    }

    _renameStateBySessionId.remove(sessionId);
    if (isClosed) return;
    final index = _allSessions.indexWhere((session) => session.id == sessionId);
    if (index >= 0) {
      _allSessions = _sessionListService.upsertSession(
        sessions: _allSessions,
        session: _allSessions[index].copyWith(title: renameState.confirmedValue),
      );
    }
    _emitFiltered();
  }

  /// Deletes a session permanently. Null when it was not deleted; then
  /// [lastCleanupRejection] says whether the bridge refused the cleanup.
  /// [deleteSessionFolder] also removes a "No project" session's own folder.
  Future<SessionCleanupOutcome?> deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteSessionFolder,
    required bool force,
  }) => _runActionScopeOperation(
    operation: () => _deleteSession(
      sessionId: sessionId,
      deleteWorktree: deleteWorktree,
      deleteSessionFolder: deleteSessionFolder,
      force: force,
    ),
  );

  Future<SessionCleanupOutcome?> _deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteSessionFolder,
    required bool force,
  }) async {
    final index = _allSessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return null;

    final originalSession = _allSessions[index];

    // Optimistically remove.
    _allSessions = _sessionListService.removeSession(
      sessions: _allSessions,
      sessionId: sessionId,
    );
    _emitFiltered();

    _lastCleanupRejection = null;

    final ApiResponse<SessionCleanupOutcome> response;
    try {
      response = await _sessionCleanupService.deleteSession(
        sessionId: sessionId,
        deleteWorktree: deleteWorktree,
        deleteSessionFolder: deleteSessionFolder,
        force: force,
      );
    } on SessionCleanupRejectedException catch (error) {
      logd("[SessionList] delete rejected: cleanup issues=${error.rejection.issues}");
      _lastCleanupRejection = error.rejection;
      _reinsertSession(originalSession);
      return null;
    }

    if (isClosed) return null;

    return switch (response) {
      SuccessResponse(:final data) => data,
      ErrorResponse(:final error) => () {
        loge("Failed to delete session: ${error.toString()}");
        _reinsertSession(originalSession);
        return null;
      }(),
    };
  }

  void _reinsertSession(Session session) {
    _allSessions = _sessionListService.upsertSession(sessions: _allSessions, session: session);
    _emitFiltered();
  }

  // ---------------------------------------------------------------------------

  /// Keeps session events from repainting an old title while the mutation is
  /// still pending, and settles overlapping renames on the last confirmed one.
  final Map<String, OptimisticRenameTracker> _renameStateBySessionId = {};
  int _nextRenameToken = 0;

  void _emitFiltered() {
    final visible = _sessionListService.visibleSessions(
      sessions: _allSessions.map((session) {
        final renameState = _renameStateBySessionId[session.id];
        return renameState == null ? session : session.copyWith(title: renameState.visibleValue);
      }),
      filter: SessionListFilter.active,
      activityBySessionId: _sseEventTracker.currentSessionActivity[_projectId] ?? const {},
      listStateBySessionId:
          _sessionUnseenTracker.currentSessionUnseen[_projectId] ?? const <String, SessionListItemState>{},
    );

    if (isClosed) return;
    emit(
      SessionListState(
        sessions: visible,
        activeSessionIds: _sseEventTracker.currentSessionActivity[_projectId] ?? const {},
        unseenBySessionId: _unseenBySessionId(visible),
      ),
    );
  }

  @override
  Future<void> close() async {
    // A local change or bridge event can remove an action-only sidebar row.
    // Let its admitted operation and response handling finish before closing.
    if (_pendingActionOperations > 0) {
      final drained = _actionOperationsDrained ??= Completer<void>();
      await drained.future;
    }
    await _subscriptions.dispose();
    await super.close();
  }
}
