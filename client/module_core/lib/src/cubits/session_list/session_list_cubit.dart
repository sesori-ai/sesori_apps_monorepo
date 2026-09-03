import "dart:async";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart" hide SessionCleanupRejection;

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../capabilities/server_connection/models/sse_event.dart";
import "../../errors/api_error_remote_failure_x.dart";
import "../../logging/logging.dart";
import "../../platform/route_source.dart";
import "../../repositories/models/repo_provider.dart";
import "../../repositories/models/session_cleanup_rejection.dart";
import "../../repositories/project_repository.dart";
import "../../repositories/session_repository.dart";
import "../../routing/app_routes.dart";
import "../../services/catalog_rescan_service.dart";
import "../../services/models/catalog_rescan_state.dart";
import "../../services/models/session_activity_info.dart";
import "../../services/models/session_list_item_state.dart";
import "../../services/project_viewing_service.dart";
import "../../services/session_list_service.dart";
import "../../services/session_unseen_tracker.dart";
import "../../services/sse_event_tracker.dart";
import "session_list_state.dart";

enum _SessionFetchOutcome() { applied, failed, superseded }

class SessionListCubit({
  required final SessionRepository _sessionRepository,
  required final SessionListService _sessionListService,
  required final ProjectRepository _projectRepository,
  required final ConnectionService _connectionService,
  required final SseEventTracker _sseEventTracker,
  required final SessionUnseenTracker _sessionUnseenTracker,
  required final ProjectViewingService _projectViewingService,
  required final RouteSource _routeSource,
  required final String _projectId,
  required final FailureReporter _failureReporter,
  required final CatalogRescanService _catalogRescanService,
}) extends Cubit<SessionListState> {
  final CompositeSubscription _subscriptions = CompositeSubscription();

  final ProjectViewClaim _projectViewClaim = _projectViewingService.beginListClaim(projectId: _projectId);
  SessionCleanupRejection? _lastCleanupRejection;

  /// Cached git context (base branch + remote repository identity), fetched
  /// alongside sessions. Only overwritten on success so a failed refresh
  /// keeps the last-known values.
  ProjectGitContext? _gitContext;

  this : super(const SessionListState.loading()) {
    loadSessions();
    // The catalog scan, which any surface can start. Its state is only
    // projected onto this list; the operation itself is the service's.
    _subscriptions.add(_catalogRescanService.state.listen(_onCatalogScanState));
    // A committed import raises no list invalidation of its own.
    _subscriptions.add(_catalogRescanService.catalogChanged.listen((_) => _onCatalogChanged()));
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
      _sessionUnseenTracker.sessionUnseen.listen((_) => _onUnseenUpdated()),
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
            SesoriPluginManagementChanged() ||
            SesoriPluginInstallProgress() ||
            SesoriPluginAuthenticationProgress() ||
            SesoriSessionOptionsUpdated() ||
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
            SesoriSessionQueuedPrompts() ||
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

  void _onSessionActivityUpdated(Map<String, Map<String, SessionActivityInfo>> activityByProjectId) {
    if (isClosed) return;
    final current = state;
    if (current is! SessionListLoaded) return;
    _emitFiltered();
  }

  void _onUnseenUpdated() {
    if (isClosed) return;
    final current = state;
    if (current is! SessionListLoaded) return;
    _emitFiltered();
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
  Future<void> markSessionSeen({required String sessionId, required bool read}) async {
    _sessionUnseenTracker.applyLocalSessionUnseen(
      projectId: _projectId,
      sessionId: sessionId,
      unseen: !read,
    );
    _onUnseenUpdated();
    try {
      final response = await _sessionRepository.markSessionSeen(sessionId: sessionId, read: read);
      if (response case ErrorResponse(:final error)) {
        loge("Failed to mark session ${read ? "read" : "unread"}", error);
        if (!isClosed) {
          await _fetchSessions(silent: true, catalogRefresh: false, waitForPrData: false);
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
        await _fetchSessions(silent: true, catalogRefresh: false, waitForPrData: false);
      }
    }
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
      logt("[SessionList] session.updated ignored id=${session.id} reason=project_mismatch");
      return;
    }
    if (state is! SessionListLoaded) {
      logt("[SessionList] session.updated ignored id=${session.id} reason=state_not_loaded");
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
        case SessionListLoading():
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
  // Archive / Delete
  // ---------------------------------------------------------------------------

  /// Archives a session permanently. Returns `true` on success so the screen
  /// can confirm it.
  Future<bool> archiveSession({
    required String sessionId,
    required bool deleteWorktree,
    required bool force,
  }) async {
    if (state is! SessionListLoaded) return false;

    final index = _allSessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return false;

    // Per-invocation, so two overlapping archives can never roll each other's
    // session back.
    final snapshot = _allSessions[index];

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
      response = await _sessionRepository.archiveSession(
        sessionId: sessionId,
        deleteWorktree: deleteWorktree,
        force: force,
      );
    } on SessionCleanupRejectedException catch (error) {
      _lastCleanupRejection = error.rejection;
      _reinsertSession(snapshot);
      return false;
    }

    if (isClosed) return false;

    return switch (response) {
      SuccessResponse() => true,
      ErrorResponse(:final error) => () {
        loge("Failed to archive session: ${error.toString()}");
        // Rollback — re-insert the original session.
        _reinsertSession(snapshot);
        return false;
      }(),
    };
  }

  /// Renames a session. Returns `true` on success so the screen can show
  /// a confirmation message.
  Future<bool> renameSession({required String sessionId, required String title}) async {
    final response = await _sessionRepository.renameSession(sessionId: sessionId, title: title);
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
      response = await _sessionRepository.deleteSession(
        sessionId: sessionId,
        deleteWorktree: deleteWorktree,
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
    final visible = _sessionListService.visibleSessions(
      sessions: _allSessions,
      showArchived: _showArchived,
      activityBySessionId: _sseEventTracker.currentSessionActivity[_projectId] ?? const {},
      listStateBySessionId:
          _sessionUnseenTracker.currentSessionUnseen[_projectId] ?? const <String, SessionListItemState>{},
    );

    if (isClosed) return;
    final projectActivity = _sseEventTracker.currentSessionActivity[_projectId] ?? <String, SessionActivityInfo>{};
    final currentState = state;
    final isRefreshing = currentState is SessionListLoaded ? currentState.isRefreshing : false;
    emit(
      SessionListState.loaded(
        sessions: visible,
        showArchived: _showArchived,
        activeSessionIds: projectActivity,
        unseenBySessionId: _unseenBySessionId(visible),
        isRefreshing: isRefreshing,
        // Re-derived from its owner, like the two fields above it. Threading
        // the previous loaded state forward would not do: the refresh this
        // scan itself triggers rebuilds from a state that may not exist yet,
        // and the terminal row it was fired for would be erased.
        catalogScan: _catalogRescanService.state.value,
        baseBranch: _gitContext?.baseBranch,
        repoSlug: _gitContext?.repoSlug,
        repoProvider: _gitContext?.repoProvider ?? RepoProvider.other,
      ),
    );
  }

  Future<void> loadSessions() async {
    emit(const SessionListState.loading());
    await _fetchSessions(silent: false, catalogRefresh: false, waitForPrData: false);
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
    await _connectionService.reconnectAndAwaitOutcome(timeout: const Duration(seconds: 15));
    if (isClosed) return;
    await _fetchSessions(silent: false, catalogRefresh: false, waitForPrData: false);
  }

  /// In-flight silent refresh, used for coalescing.
  Future<_SessionFetchOutcome>? _activeRefresh;

  /// Whether the current silent refresh honors an explicit pull's PR-data wait.
  bool _activeRefreshWaitsForPrData = false;

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

  /// Re-fetches sessions without showing the full-screen loading indicator.
  /// Concurrent ordinary calls coalesce onto the current silent refresh.
  ///
  /// When [waitForPrData] is true the bridge will wait up to 5 s for
  /// GitHub PR metadata before returning. This is appropriate only for
  /// explicit user-initiated pull-to-refresh; background triggers such as
  /// reconnects, route navigation, or SSE events should leave it false.
  Future<bool> refreshSessions({bool waitForPrData = false}) {
    return _awaitRefreshResult(
      refresh: _refreshSessions(
        force: false,
        catalogRefresh: false,
        waitForPrData: waitForPrData,
      ),
    );
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

  Future<_SessionFetchOutcome> _refreshSessions({
    required bool force,
    required bool catalogRefresh,
    required bool waitForPrData,
  }) {
    final active = _activeRefresh;
    if (!force && active != null) return active;

    late final Future<_SessionFetchOutcome> refresh;
    refresh =
        _fetchSessions(
          silent: true,
          catalogRefresh: catalogRefresh,
          waitForPrData: waitForPrData,
        ).whenComplete(() {
          if (!identical(_activeRefresh, refresh)) return;
          _activeRefresh = null;
          _activeRefreshWaitsForPrData = false;
        });
    _activeRefresh = refresh;
    _activeRefreshWaitsForPrData = waitForPrData;
    return refresh;
  }

  Future<_SessionFetchOutcome> _fetchSessions({
    required bool silent,
    required bool catalogRefresh,
    required bool waitForPrData,
  }) {
    final requestGeneration = ++_fetchGeneration;
    final catalogChangeGeneration = _catalogChangeGeneration;
    final fetch = _runFetchSessions(
      silent: silent,
      catalogRefresh: catalogRefresh,
      waitForPrData: waitForPrData,
      requestGeneration: requestGeneration,
      catalogChangeGeneration: catalogChangeGeneration,
    );
    _latestFetch = fetch;
    return fetch;
  }

  Future<_SessionFetchOutcome> _runFetchSessions({
    required bool silent,
    required bool catalogRefresh,
    required bool waitForPrData,
    required int requestGeneration,
    required int catalogChangeGeneration,
  }) async {
    var didApplySnapshot = false;
    try {
      // Captured BEFORE the fetch so the seed can't overwrite a live update
      // that arrives while the (possibly PR-data-delayed) request is in flight.
      final unseenTick = _sessionUnseenTracker.tick;
      final (sessionsResponse, gitContextResponse) = await (
        _sessionListService.listSessions(
          projectId: _projectId,
          waitForPrData: waitForPrData,
        ),
        _projectRepository.getGitContext(projectId: _projectId),
      ).wait;
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

      // Update cached git context on success; silently ignore errors so
      // the session list still loads even if the endpoint is unavailable.
      if (gitContextResponse case SuccessResponse(:final data)) {
        _gitContext = data;
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
          _projectViewingService.markClaimReady(claim: _projectViewClaim, projectId: _projectId);
          _consumeCatalogChangesThrough(generation: catalogChangeGeneration);
          didApplySnapshot = true;
          return _SessionFetchOutcome.applied;

        case ErrorResponse(:final error):
          if (silent && state is! SessionListLoading) {
            logw("Failed to refresh sessions: ${error.toString()}");
          } else {
            _projectViewingService.markClaimFailed(claim: _projectViewClaim);
            loge("Session list load failed", error);
            emit(SessionListState.failed(reason: error.remoteFailureReason));
          }
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
      // A catalog snapshot superseding an explicit pull is still that pull's
      // winning response, so preserve its bounded PR-data wait.
      final waitForPrData = _activeRefresh == null ? false : _activeRefreshWaitsForPrData;
      late final _SessionFetchOutcome outcome;
      try {
        outcome = await _refreshSessions(
          force: true,
          catalogRefresh: true,
          waitForPrData: waitForPrData,
        );
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

  /// Starts a catalog scan across every harness this bridge can import from.
  void startCatalogScan() => unawaited(_catalogRescanService.startAll());

  /// Stops the scan in flight.
  void cancelCatalogScan() => unawaited(_catalogRescanService.cancel());

  /// Clears a finished scan the user has read.
  void dismissCatalogScan() => _catalogRescanService.dismiss();

  void _onCatalogScanState(CatalogRescanState scan) {
    if (isClosed) return;
    if (state case final SessionListLoaded loaded) {
      emit(loaded.copyWith(catalogScan: scan));
    }
  }

  @override
  Future<void> close() {
    _projectViewingService.releaseClaim(claim: _projectViewClaim);
    _subscriptions.dispose();
    return super.close();
  }
}
