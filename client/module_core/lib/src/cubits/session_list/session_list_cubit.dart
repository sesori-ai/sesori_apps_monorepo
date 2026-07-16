import "dart:async";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../api/session_api.dart";
import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../capabilities/server_connection/models/sse_event.dart";
import "../../capabilities/session/session_service.dart";
import "../../errors/api_error_remote_failure_x.dart";
import "../../logging/logging.dart";
import "../../platform/route_source.dart";
import "../../repositories/project_repository.dart";
import "../../routing/app_routes.dart";
import "../../services/models/session_activity_info.dart";
import "../../services/session_list_service.dart";
import "../../services/sse_event_tracker.dart";
import "../../trackers/session_attention_tracker.dart";
import "session_list_state.dart";

class SessionListCubit extends Cubit<SessionListState> {
  final CompositeSubscription _subscriptions = CompositeSubscription();

  final SessionService _sessionService;
  final SessionListService _sessionListService;
  final ProjectRepository _projectRepository;
  final ConnectionService _connectionService;
  final SseEventTracker _sseEventTracker;
  final SessionAttentionTracker _sessionAttentionTracker;
  final RouteSource _routeSource;
  final String _projectId;
  final FailureReporter _failureReporter;

  /// Tracks the session state before the last archive/unarchive action
  /// so the screen can offer an undo toast.
  Session? _undoSnapshot;

  SessionCleanupRejection? _lastCleanupRejection;

  /// Cached base branch name, fetched alongside sessions.
  String? _baseBranch;

  SessionListCubit({
    required SessionService sessionService,
    required SessionListService sessionListService,
    required ProjectRepository projectRepository,
    required ConnectionService connectionService,
    required SseEventTracker sseEventTracker,
    required SessionAttentionTracker sessionAttentionTracker,
    required RouteSource routeSource,
    required String projectId,
    required FailureReporter failureReporter,
  }) : _sessionService = sessionService,
       _sessionListService = sessionListService,
       _projectRepository = projectRepository,
       _connectionService = connectionService,
       _sseEventTracker = sseEventTracker,
       _sessionAttentionTracker = sessionAttentionTracker,
       _routeSource = routeSource,
       _projectId = projectId,
       _failureReporter = failureReporter,
       super(const SessionListState.loading()) {
    loadSessions();
    _subscriptions.add(_connectionService.events.listen(_handleEvent));
    // 1. Navigate-back refresh: one immediate fetch when the user returns to
    //    the sessions page. pairwise() ensures this doesn't fire on the
    //    initial route emission (needs two values before it emits).
    _subscriptions.add(
      _routeSource.currentRouteStream
          .distinct()
          .pairwise()
          .where((pair) => pair.first != AppRouteDef.sessions && pair.last == AppRouteDef.sessions)
          .listen((_) {
            if (isClosed) return;
            unawaited(refreshSessions());
          }),
    );
    // skip(1) ignores the BehaviorSubject replay of the current status —
    // we only want to react to actual transitions (e.g. disconnected → connected).
    _subscriptions.add(_connectionService.status.skip(1).listen(_onConnectionStatusChanged));
    _subscriptions.add(
      _sseEventTracker.sessionActivity.listen(_onSessionActivityUpdated),
    );
    _subscriptions.add(
      _sessionAttentionTracker.sessionUnseen.listen((_) => _onUnseenUpdated()),
    );
    _subscriptions.add(
      _sessionAttentionTracker.sessionLastUserInteractionAt.listen((_) => _onUserInteractionUpdated()),
    );
    _subscriptions.add(
      _connectionService.dataMayBeStale.listen((_) => _onStaleReconnect()),
    );
  }

  String get projectId => _projectId;

  SessionCleanupRejection? get lastCleanupRejection => _lastCleanupRejection;

  void _handleEvent(SseEvent event) {
    try {
      if (isClosed) return;
      logd("[SessionList] event received: ${event.data.runtimeType}");
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
            SesoriSessionDiff() ||
            SesoriSessionError() ||
            SesoriSessionCompacted() ||
            SesoriSessionStatus() ||
            SesoriMessageUpdated() ||
            SesoriMessageRemoved() ||
            SesoriMessagePartUpdated() ||
            SesoriMessagePartDelta() ||
            SesoriMessagePartRemoved() ||
            SesoriPtyCreated() ||
            SesoriPtyUpdated() ||
            SesoriPtyExited() ||
            SesoriPtyDeleted() ||
            SesoriPermissionAsked() ||
            SesoriPermissionReplied() ||
            SesoriPermissionUpdated() ||
            SesoriQuestionAsked() ||
            SesoriQuestionReplied() ||
            SesoriQuestionRejected() ||
            SesoriCommandExecuted() ||
            SesoriTodoUpdated() ||
            SesoriSessionPromptDefaultsChanged() ||
            SesoriProjectsSummary() ||
            SesoriProjectUpdated() ||
            SesoriVcsBranchUpdated() ||
            SesoriFileEdited() ||
            SesoriFileWatcherUpdated() ||
            SesoriLspUpdated() ||
            SesoriLspClientDiagnostics() ||
            SesoriMcpToolsChanged() ||
            SesoriMcpBrowserOpenFailed() ||
            SesoriInstallationUpdated() ||
            SesoriInstallationUpdateAvailable() ||
            SesoriWorkspaceReady() ||
            SesoriWorkspaceFailed() ||
            SesoriTuiToastShow() ||
            SesoriWorktreeReady() ||
            SesoriWorktreeFailed() ||
            // Attention changes are consumed via SessionAttentionTracker streams.
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

  void _onSessionActivityUpdated(Map<String, Map<String, SessionActivityInfo>> activityByProjectId) {
    if (isClosed) return;
    if (state is! SessionListLoaded) return;
    _emitFiltered();
  }

  void _onUserInteractionUpdated() {
    if (isClosed || state is! SessionListLoaded) return;
    _emitFiltered();
  }

  void _onUnseenUpdated() {
    if (isClosed) return;
    final current = state;
    if (current is! SessionListLoaded) return;
    emit(current.copyWith(unseenBySessionId: _unseenBySessionId(current.sessions)));
  }

  /// Merges the REST-loaded `Session.unseen` with the live tracker map (the
  /// tracker takes precedence once it has an entry).
  Map<String, bool> _unseenBySessionId(List<Session> sessions) {
    final live = _sessionAttentionTracker.currentSessionUnseen[_projectId] ?? const <String, bool>{};
    return {
      for (final session in sessions) session.id: live[session.id] ?? session.unseen,
    };
  }

  /// Marks a session read (clears its bold) or unread (forces bold). Applied
  /// optimistically to the tracker so the row updates immediately; the bridge
  /// echo delivers the authoritative state (including the project aggregate)
  /// within the round trip. On failure, a silent refetch re-seeds the
  /// authoritative flags instead of local rollback bookkeeping.
  Future<void> markSessionSeen({required String sessionId, required bool read}) async {
    _sessionAttentionTracker.applyLocalSessionUnseen(
      projectId: _projectId,
      sessionId: sessionId,
      unseen: !read,
    );
    _onUnseenUpdated();
    try {
      final response = await _sessionService.markSessionSeen(sessionId: sessionId, read: read);
      if (response case ErrorResponse(:final error)) {
        loge("Failed to mark session ${read ? "read" : "unread"}", error);
        if (!isClosed) await _fetchSessions(silent: true);
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
      if (!isClosed) await _fetchSessions(silent: true);
    }
  }

  void _onSessionCreated(Session session) {
    // Only add root sessions that belong to this project.
    if (session.parentID != null) {
      logd("[SessionList] session.created ignored id=${session.id} reason=child");
      return;
    }
    if (session.projectID != _projectId) {
      logd("[SessionList] session.created ignored id=${session.id} reason=project_mismatch");
      return;
    }

    if (state is! SessionListLoaded) {
      logd("[SessionList] session.created ignored id=${session.id} reason=state_not_loaded");
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
      logd("[SessionList] session.updated ignored id=${session.id} reason=project_mismatch");
      return;
    }
    if (state is! SessionListLoaded) {
      logd("[SessionList] session.updated ignored id=${session.id} reason=state_not_loaded");
      return;
    }

    final index = _allSessions.indexWhere((s) => s.id == session.id);

    if (index < 0) {
      // Session was unarchived (or created elsewhere) — add it if it belongs here.
      logd("[SessionList] session.updated not_found id=${session.id} action=add_via_created");
      _onSessionCreated(session);
      return;
    }

    _allSessions = _sessionListService.upsertSession(sessions: _allSessions, session: session);
    logd("[SessionList] session.updated updated id=${session.id}");
    _emitFiltered();
  }

  void _onSessionDeleted(Session session) {
    if (session.projectID != _projectId) {
      logd("[SessionList] session.deleted ignored id=${session.id} reason=project_mismatch");
      return;
    }
    if (state is! SessionListLoaded) {
      logd("[SessionList] session.deleted ignored id=${session.id} reason=state_not_loaded");
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
    if (status is ConnectionConnected) {
      switch (state) {
        case SessionListLoaded():
          unawaited(refreshSessions());
        case SessionListFailed():
          unawaited(loadSessions());
        case SessionListLoading() || SessionListStaleProject():
          break;
      }
    }
  }

  void _onStaleReconnect() {
    if (isClosed) return;
    final current = state;
    if (current is! SessionListLoaded) return;
    final loaded = current;
    emit(loaded.copyWith(isRefreshing: true));
    unawaited(
      refreshSessions().whenComplete(() {
        if (isClosed) return;
        final current = state;
        if (current is SessionListLoaded) {
          emit(current.copyWith(isRefreshing: false));
        }
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Archive / Unarchive / Delete
  // ---------------------------------------------------------------------------

  /// Archives a session. Returns `true` on success so the screen can show
  /// an undo toast.
  Future<bool> archiveSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    if (state is! SessionListLoaded) return false;

    final index = _allSessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return false;

    // Store for undo before removing.
    _undoSnapshot = _allSessions[index];

    // Optimistically mark as archived in the backing list so _emitFiltered
    // hides it when showArchived is off.
    final archivedSession = _allSessions[index].copyWith(
      time: _allSessions[index].time?.copyWith(archived: DateTime.now().millisecondsSinceEpoch),
    );
    _allSessions = _sessionListService.upsertSession(
      sessions: _allSessions,
      session: archivedSession,
    );
    _emitFiltered();

    _lastCleanupRejection = null;

    final ApiResponse<Session> response;
    try {
      response = await _sessionService.archiveSession(
        sessionId: sessionId,
        deleteWorktree: deleteWorktree,
        deleteBranch: deleteBranch,
        force: force,
      );
    } on SessionCleanupRejectedException catch (error) {
      _lastCleanupRejection = error.rejection;
      _rollbackLastAction();
      return false;
    }

    if (isClosed) return false;

    return switch (response) {
      SuccessResponse() => true,
      ErrorResponse(:final error) => () {
        loge("Failed to archive session: ${error.toString()}");
        // Rollback — re-insert the original session.
        _rollbackLastAction();
        return false;
      }(),
    };
  }

  /// Unarchives a session. Returns `true` on success so the screen can show
  /// a confirmation message.
  ///
  Future<bool> unarchiveSession(String sessionId) async {
    if (state is! SessionListLoaded) return false;

    final index = _allSessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return false;

    _undoSnapshot = _allSessions[index];

    final unarchivedSession = _allSessions[index].copyWith(
      time: _allSessions[index].time?.copyWith(archived: null),
    );
    _allSessions = _sessionListService.upsertSession(
      sessions: _allSessions,
      session: unarchivedSession,
    );
    _emitFiltered();

    final response = await _sessionService.unarchiveSession(sessionId: sessionId);
    if (isClosed) return false;

    return switch (response) {
      SuccessResponse(:final data) => () {
        _lastCleanupRejection = null;
        _reinsertSession(data);
        return true;
      }(),
      ErrorResponse(:final error) => () {
        loge("Failed to unarchive session: ${error.toString()}");
        _rollbackLastAction();
        return false;
      }(),
    };
  }

  /// Undoes the last archive or unarchive operation by reversing the action.
  Future<bool> undoLastArchiveAction() async {
    final snapshot = _undoSnapshot;
    if (snapshot == null) return false;
    _undoSnapshot = null;

    // If the snapshot was archived, the last action was an unarchive → re-archive.
    // If the snapshot was not archived, the last action was an archive → unarchive.
    final wasArchived = snapshot.time?.archived != null;
    final response = wasArchived
        ? await _sessionService.archiveSession(
            sessionId: snapshot.id,
            deleteWorktree: false,
            deleteBranch: false,
            force: false,
          )
        : await _sessionService.unarchiveSession(sessionId: snapshot.id);
    if (isClosed) return false;

    switch (response) {
      case SuccessResponse(:final data):
        _reinsertSession(data);
        return true;
      case ErrorResponse(:final error):
        loge("Failed to undo archive action: ${error.toString()}");
        return false;
    }
  }

  /// Clears undo state. Called when the undo toast dismisses.
  void clearLastActionUndo() {
    _undoSnapshot = null;
  }

  /// Renames a session. Returns `true` on success so the screen can show
  /// a confirmation message.
  Future<bool> renameSession({required String sessionId, required String title}) async {
    final response = await _sessionService.renameSession(sessionId: sessionId, title: title);
    if (isClosed) return false;

    switch (response) {
      case SuccessResponse():
        await refreshSessions();
        return true;
      case ErrorResponse():
        return false;
    }
  }

  /// Deletes a session permanently.
  Future<bool> deleteSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool deleteBranch,
    required bool force,
  }) async {
    if (state is! SessionListLoaded) return false;

    final index = _allSessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return false;

    final originalSession = _allSessions[index];

    // Optimistically remove.
    _allSessions = _sessionListService.removeSession(
      sessions: _allSessions,
      sessionId: sessionId,
    );
    _emitFiltered();

    _lastCleanupRejection = null;

    final ApiResponse<void> response;
    try {
      response = await _sessionService.deleteSession(
        sessionId: sessionId,
        deleteWorktree: deleteWorktree,
        deleteBranch: deleteBranch,
        force: force,
      );
    } on SessionCleanupRejectedException catch (error) {
      logd("[SessionList] delete rejected: cleanup issues=${error.rejection.issues}");
      _lastCleanupRejection = error.rejection;
      _reinsertSession(originalSession);
      return false;
    }

    if (isClosed) return false;

    return switch (response) {
      SuccessResponse() => true,
      ErrorResponse(:final error) => () {
        loge("Failed to delete session: ${error.toString()}");
        _reinsertSession(originalSession);
        return false;
      }(),
    };
  }

  void _rollbackLastAction() {
    final session = _undoSnapshot;
    if (session == null) return;
    _undoSnapshot = null;
    _reinsertSession(session);
  }

  void _reinsertSession(Session session) {
    if (state is! SessionListLoaded) return;

    _allSessions = _sessionListService.upsertSession(sessions: _allSessions, session: session);
    _emitFiltered();
  }

  // ---------------------------------------------------------------------------

  /// Tracks the full unfiltered server response so toggling archived
  /// doesn't require a network round-trip.
  List<Session> _allSessions = [];
  bool _showArchived = false;

  void toggleArchived() {
    _showArchived = !_showArchived;
    _emitFiltered();
  }

  void _emitFiltered() {
    final projectActivity = _sseEventTracker.currentSessionActivity[_projectId] ?? <String, SessionActivityInfo>{};
    final lastUserInteractionAtBySessionId =
        _sessionAttentionTracker.currentSessionLastUserInteractionAt[_projectId] ?? const <String, int?>{};
    final visible = _sessionListService.visibleSessions(
      sessions: _allSessions,
      showArchived: _showArchived,
      activeSessionIds: projectActivity.keys.toSet(),
      lastUserInteractionAtBySessionId: lastUserInteractionAtBySessionId,
    );

    if (isClosed) return;
    final currentState = state;
    final isRefreshing = currentState is SessionListLoaded ? currentState.isRefreshing : false;
    emit(
      SessionListState.loaded(
        sessions: visible,
        showArchived: _showArchived,
        activeSessionIds: projectActivity,
        unseenBySessionId: _unseenBySessionId(visible),
        isRefreshing: isRefreshing,
        baseBranch: _baseBranch,
      ),
    );
  }

  Future<void> loadSessions() async {
    emit(const SessionListState.loading());
    await _fetchSessions();
  }

  /// Retries loading sessions after a failure.
  ///
  /// Unlike [loadSessions], this method triggers a relay reconnection
  /// when the connection is not active, then waits for the result before
  /// fetching. This ensures the retry actually reaches the bridge instead
  /// of failing immediately with a "not connected" error.
  Future<void> retryLoadSessions() async {
    emit(const SessionListState.loading());
    await Future<void>.delayed(Duration.zero);
    if (isClosed) return;
    await _reconnectIfNeeded();
    if (isClosed) return;
    await _fetchSessions();
  }

  /// Attempts to reconnect the relay when it is not in the
  /// [ConnectionConnected] state. Returns once the connection resolves
  /// (connected, lost, or timed out).
  Future<void> _reconnectIfNeeded() async {
    if (_connectionService.currentStatus is ConnectionConnected) return;

    if (_connectionService.currentStatus is! ConnectionReconnecting) {
      _connectionService.reconnect();
    }
    if (_connectionService.currentStatus is! ConnectionReconnecting) return;

    try {
      await _connectionService.status
          .where((s) => s is! ConnectionReconnecting)
          .first
          .timeout(const Duration(seconds: 15));
    } on TimeoutException catch (_) {
      // Fall through — fetch will fail gracefully with a user-visible error.
    }
  }

  /// In-flight silent refresh, used for coalescing.
  Future<bool>? _activeRefresh;

  /// Re-fetches sessions without showing the full-screen loading indicator.
  /// Concurrent calls are coalesced: if a refresh is already in-flight, the
  /// existing Future is returned instead of starting a second network request.
  ///
  /// When [waitForPrData] is true the bridge will wait up to 5 s for
  /// GitHub PR metadata before returning. This is appropriate only for
  /// explicit user-initiated pull-to-refresh; background triggers such as
  /// reconnects, route navigation, or SSE events should leave it false.
  Future<bool> refreshSessions({bool waitForPrData = false}) {
    return _activeRefresh ??= _fetchSessions(
      silent: true,
      waitForPrData: waitForPrData,
    ).whenComplete(() => _activeRefresh = null);
  }

  Future<bool> _fetchSessions({bool silent = false, bool waitForPrData = false}) async {
    // Captured BEFORE the fetch so the seed can't overwrite a live update that
    // arrives while the (possibly PR-data-delayed) request is in flight.
    final attentionTick = _sessionAttentionTracker.tick;
    final (sessionsResponse, baseBranchResponse) = await (
      _sessionListService.listSessions(
        projectId: _projectId,
        waitForPrData: waitForPrData,
      ),
      _projectRepository.getBaseBranch(projectId: _projectId),
    ).wait;
    if (isClosed) return false;

    // Update cached base branch on success; silently ignore errors so
    // the session list still loads even if the endpoint is unavailable.
    if (baseBranchResponse case SuccessResponse(:final data)) {
      _baseBranch = data.baseBranch;
    }

    switch (sessionsResponse) {
      case SuccessResponse(:final data):
        _allSessions = data.items;
        // The REST flags are authoritative at fetch time — seed the tracker so
        // a stale live `true` can't keep a row bold after a clear was missed
        // (e.g. the session was read on another phone while reconnecting).
        _sessionAttentionTracker.seedSessions(
          projectId: _projectId,
          unseenBySessionId: {for (final s in data.items) s.id: s.unseen},
          lastUserInteractionAtBySessionId: {
            for (final s in data.items) s.id: s.lastUserInteractionAt,
          },
          sinceTick: attentionTick,
        );
        _emitFiltered();
        return true;

      case ErrorResponse(:final error):
        if (silent) {
          logw("Failed to refresh sessions: ${error.toString()}");
        } else {
          loge("Session list load failed", error);
          emit(SessionListState.failed(reason: error.remoteFailureReason));
        }
        return false;
    }
  }

  @override
  Future<void> close() {
    _subscriptions.dispose();
    return super.close();
  }
}
