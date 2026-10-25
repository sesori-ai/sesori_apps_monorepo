import "dart:async";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart" hide SessionCleanupRejection;

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../capabilities/server_connection/models/sse_event.dart";
import "../../logging/logging.dart";
import "../../repositories/models/session_cleanup_rejection.dart";
import "../../repositories/session_repository.dart";
import "../../services/catalog_rescan_service.dart";
import "../../services/models/optimistic_rename_tracker.dart";
import "../../services/models/session_cleanup_outcome.dart";
import "../../services/models/session_list_filter.dart";
import "../../services/models/session_list_item_state.dart";
import "../../services/session_cleanup_service.dart";
import "../../services/session_list_service.dart";
import "../../services/session_unseen_tracker.dart";
import "../../services/sse_event_tracker.dart";
import "session_list_state.dart";

enum _SessionFetchOutcome() {
  applied,
  failed,
  superseded,
}

/// One project's session actions (rename, delete, mark seen) for the
/// rows a list already shows. It starts from the caller's [sessions] and keeps
/// them in step with bridge events and silent refreshes.
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
  required final CatalogRescanService _catalogRescanService,
}) extends Cubit<SessionListState> {
  final CompositeSubscription _subscriptions = CompositeSubscription();
  int _pendingActionOperations = 0;
  Completer<void>? _actionOperationsDrained;
  SessionCleanupRejection? _lastCleanupRejection;

  /// The full server response; the state shows only its unarchived sessions.
  List<Session> _allSessions = sessions;

  this : super(const SessionListState(sessions: [], activeSessionIds: {}, unseenBySessionId: {})) {
    _emitFiltered();
    // A committed import raises no list invalidation of its own.
    _subscriptions.add(_catalogRescanService.catalogChanged.listen((_) => _onCatalogChanged()));
    _subscriptions.add(_connectionService.events.listen(_handleEvent));
    // skip(1) ignores the BehaviorSubject replay of the current status —
    // we only want to react to actual transitions (e.g. disconnected → connected).
    _subscriptions.add(_connectionService.status.skip(1).listen(_onConnectionStatusChanged));
    _subscriptions.add(_sseEventTracker.sessionActivity.listen((_) => _emitFiltered()));
    _subscriptions.add(_sessionUnseenTracker.sessionUnseen.listen((_) => _emitFiltered()));
    _subscriptions.add(_connectionService.dataMayBeStale.listen((_) => unawaited(refreshSessions())));
  }

  /// An action scope can outlive a failed refresh. Synchronize the named menu
  /// target from the consumer's current inventory without replacing other rows
  /// (which may still have their own mutation in flight).
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
        case SesoriSessionCreated(:final info):
          _onSessionCreated(info);
        case SesoriSessionUpdated(:final info):
          _onSessionUpdated(info);
        case SesoriSessionDeleted(:final info):
          _onSessionDeleted(info);
        case SesoriServerConnected() ||
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
        case SesoriSessionsUpdated(:final projectID):
          if (projectID == _projectId) {
            unawaited(refreshSessions());
          }
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
  /// within the round trip. On failure, a silent refetch re-seeds the
  /// authoritative flags instead of local rollback bookkeeping.
  Future<void> markSessionSeen({required String sessionId, required bool read}) => _runActionScopeOperation(
    operation: () => _markSessionSeen(sessionId: sessionId, read: read),
  );

  Future<void> _markSessionSeen({required String sessionId, required bool read}) async {
    _sessionUnseenTracker.applyLocalSessionUnseen(
      projectId: _projectId,
      sessionId: sessionId,
      unseen: !read,
    );
    _emitFiltered();
    try {
      final response = await _sessionRepository.markSessionSeen(sessionId: sessionId, read: read);
      if (response case ErrorResponse(:final error)) {
        loge("Failed to mark session ${read ? "read" : "unread"}", error);
        if (!isClosed) {
          await _fetchSessions(catalogRefresh: false);
        }
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
      if (!isClosed) {
        await _fetchSessions(catalogRefresh: false);
      }
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

  void _onSessionCreated(Session session) {
    // Only add root sessions that belong to this project.
    if (session.parentID != null) {
      logt("[SessionList] session.created ignored id=${session.id} reason=child");
      return;
    }
    if (session.projectID != _projectId) {
      logd("[SessionList] session.created ignored id=${session.id} reason=project_mismatch");
      return;
    }

    // Avoid duplicates.
    if (_allSessions.any((s) => s.id == session.id)) {
      logd("[SessionList] session.created ignored id=${session.id} reason=duplicate");
      return;
    }

    _allSessions = _sessionListService.upsertSession(sessions: _allSessions, session: session);
    logd("[SessionList] session.created added id=${session.id}");
    _emitFiltered();
  }

  void _onSessionUpdated(Session session) {
    if (session.projectID != _projectId) {
      logt("[SessionList] session.updated ignored id=${session.id} reason=project_mismatch");
      return;
    }

    final index = _allSessions.indexWhere((s) => s.id == session.id);

    if (index < 0) {
      // Session was created elsewhere — add it if it belongs here.
      logt("[SessionList] session.updated not_found id=${session.id} action=add_via_created");
      _onSessionCreated(session);
      return;
    }

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

  void _onConnectionStatusChanged(ConnectionStatus status) {
    logd("[SessionList] connection status: ${status.runtimeType}");
    if (isClosed) return;
    if (status is ConnectionConnected) unawaited(refreshSessions());
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
        if (!isClosed) {
          unawaited(_refreshSessions(force: true, catalogRefresh: false));
        }
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
  Future<SessionCleanupOutcome?> deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool force,
  }) => _runActionScopeOperation(
    operation: () => _deleteSession(
      sessionId: sessionId,
      deleteWorktree: deleteWorktree,
      force: force,
    ),
  );

  Future<SessionCleanupOutcome?> _deleteSession({
    required String sessionId,
    required bool deleteWorktree,
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

  /// Keeps pre-rename list responses from repainting an old title while the
  /// mutation is still pending.
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

  /// In-flight silent refresh, used for coalescing.
  Future<_SessionFetchOutcome>? _activeRefresh;

  /// Most recently started read. This is not a coalescing barrier: a refresh
  /// whose response was superseded uses it only to observe the winning result.
  Future<_SessionFetchOutcome>? _latestFetch;

  /// Monotonically orders list reads so an older response cannot overwrite a
  /// snapshot requested after it.
  int _fetchGeneration = 0;

  /// Durable catalog commits observed by this cubit, and the newest commit a
  /// successfully applied list snapshot has covered.
  int _catalogChangeGeneration = 0;
  int _catalogChangeConsumedGeneration = 0;
  bool _catalogRefreshPausedAfterFailure = false;
  Future<void>? _catalogRefresh;

  /// Re-fetches sessions silently. Concurrent ordinary calls coalesce onto the
  /// current refresh.
  Future<bool> refreshSessions() {
    return _awaitRefreshResult(refresh: _refreshSessions(force: false, catalogRefresh: false));
  }

  /// A catalog refresh can supersede an explicit pull. Wait for the newer read
  /// so the caller reports that read's outcome rather than premature success.
  Future<bool> _awaitRefreshResult({required Future<_SessionFetchOutcome> refresh}) async {
    var latest = refresh;
    while (true) {
      switch (await latest) {
        case _SessionFetchOutcome.applied:
          return true;
        case _SessionFetchOutcome.failed:
          return false;
        case _SessionFetchOutcome.superseded:
          final winningFetch = _latestFetch;
          if (winningFetch == null || identical(winningFetch, latest)) return false;
          latest = winningFetch;
      }
    }
  }

  Future<_SessionFetchOutcome> _refreshSessions({required bool force, required bool catalogRefresh}) {
    final active = _activeRefresh;
    if (!force && active != null) return active;

    late final Future<_SessionFetchOutcome> refresh;
    refresh = _fetchSessions(catalogRefresh: catalogRefresh).whenComplete(() {
      if (identical(_activeRefresh, refresh)) _activeRefresh = null;
    });
    _activeRefresh = refresh;
    return refresh;
  }

  Future<_SessionFetchOutcome> _fetchSessions({required bool catalogRefresh}) {
    final requestGeneration = ++_fetchGeneration;
    final catalogChangeGeneration = _catalogChangeGeneration;
    final fetch = _runFetchSessions(
      catalogRefresh: catalogRefresh,
      requestGeneration: requestGeneration,
      catalogChangeGeneration: catalogChangeGeneration,
    );
    _latestFetch = fetch;
    return fetch;
  }

  Future<_SessionFetchOutcome> _runFetchSessions({
    required bool catalogRefresh,
    required int requestGeneration,
    required int catalogChangeGeneration,
  }) async {
    var didApplySnapshot = false;
    try {
      // Captured BEFORE the fetch so the seed can't overwrite a live update
      // that arrives while the request is in flight.
      final unseenTick = _sessionUnseenTracker.tick;
      final sessionsResponse = await _sessionListService.listSessions(projectId: _projectId, waitForPrData: false);
      if (isClosed) return _SessionFetchOutcome.superseded;
      if (requestGeneration != _fetchGeneration) {
        if (sessionsResponse case ErrorResponse(:final error)) {
          logw(
            "Discarded superseded session list response "
            "(request generation $requestGeneration, current $_fetchGeneration)",
            error,
          );
        }
        return _SessionFetchOutcome.superseded;
      }

      switch (sessionsResponse) {
        case SuccessResponse(:final data):
          _allSessions = data.items;
          // The REST flags are authoritative at fetch time — seed the tracker so
          // a stale live `true` can't keep a row bold after a clear was missed
          // (e.g. the session was read on another phone while reconnecting).
          _sessionUnseenTracker.seedSessions(
            projectId: _projectId,
            stateBySessionId: {
              for (final session in data.items)
                session.id: (
                  unseen: session.unseen,
                  lastUserActivityAt: session.lastUserActivityAt,
                ),
            },
            sinceTick: unseenTick,
          );
          _emitFiltered();
          _consumeCatalogChangesThrough(generation: catalogChangeGeneration);
          didApplySnapshot = true;
          return _SessionFetchOutcome.applied;

        case ErrorResponse(:final error):
          logw("Failed to refresh sessions: ${error.toString()}");
          return _SessionFetchOutcome.failed;
      }
    } finally {
      if (!catalogRefresh && didApplySnapshot) _rearmCatalogRefreshAfterOrdinaryFetch();
    }
  }

  void _onCatalogChanged() {
    if (isClosed) return;
    _catalogChangeGeneration++;
    _catalogRefreshPausedAfterFailure = false;
    _ensureCatalogRefresh();
  }

  void _consumeCatalogChangesThrough({required int generation}) {
    if (generation > _catalogChangeConsumedGeneration) {
      _catalogChangeConsumedGeneration = generation;
    }
  }

  void _ensureCatalogRefresh() {
    if (isClosed ||
        _catalogRefresh != null ||
        _catalogRefreshPausedAfterFailure ||
        _catalogChangeConsumedGeneration >= _catalogChangeGeneration) {
      return;
    }

    late final Future<void> refresh;
    refresh = _drainCatalogRefreshes().whenComplete(() {
      if (!identical(_catalogRefresh, refresh)) return;
      _catalogRefresh = null;
      _ensureCatalogRefresh();
    });
    _catalogRefresh = refresh;
    unawaited(refresh);
  }

  Future<void> _drainCatalogRefreshes() async {
    while (!isClosed && _catalogChangeConsumedGeneration < _catalogChangeGeneration) {
      final targetGeneration = _catalogChangeGeneration;
      late final _SessionFetchOutcome outcome;
      try {
        outcome = await _refreshSessions(force: true, catalogRefresh: true);
      } on Object catch (error, stackTrace) {
        loge("Catalog-change session refresh failed unexpectedly", error, stackTrace);
        _catalogRefreshPausedAfterFailure = true;
        return;
      }

      if (_catalogChangeConsumedGeneration >= _catalogChangeGeneration) return;
      switch (outcome) {
        case _SessionFetchOutcome.applied:
        case _SessionFetchOutcome.superseded:
          continue;
        case _SessionFetchOutcome.failed:
          if (targetGeneration < _catalogChangeGeneration) continue;
          _catalogRefreshPausedAfterFailure = true;
          return;
      }
    }
  }

  void _rearmCatalogRefreshAfterOrdinaryFetch() {
    if (isClosed || !_catalogRefreshPausedAfterFailure) return;
    _catalogRefreshPausedAfterFailure = false;
    _ensureCatalogRefresh();
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
