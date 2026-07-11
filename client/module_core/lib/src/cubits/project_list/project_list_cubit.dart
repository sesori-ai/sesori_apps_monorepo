import "dart:async";

import "package:bloc/bloc.dart";
import "package:meta/meta.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/project/project_service.dart";
import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../errors/api_error_remote_failure_x.dart";
import "../../logging/logging.dart";
import "../../platform/route_source.dart";
import "../../routing/app_routes.dart";
import "../../services/registered_bridges_service.dart";
import "../../services/session_unseen_tracker.dart";
import "../../services/sse_event_tracker.dart";
import "add_project_outcome.dart";
import "project_list_state.dart";

/// How long to wait after an activity event before auto-refreshing project
/// data. Events during this window are coalesced into a single refresh.
@visibleForTesting
const refreshThrottleDuration = Duration(seconds: 30);

@visibleForTesting
const initialProjectLoadConnectionWaitTimeout = Duration(seconds: 15);

class ProjectListCubit extends Cubit<ProjectListState> {
  final ProjectService _projectService;
  final ConnectionService _connectionService;
  final SseEventTracker _sseEventTracker;
  final SessionUnseenTracker _sessionUnseenTracker;
  final RegisteredBridgesService _registeredBridgesService;
  final FailureReporter _failureReporter;
  final CompositeSubscription _subscriptions = CompositeSubscription();

  // ignore: no_slop_linter/prefer_required_named_parameters, public cubit constructor API
  ProjectListCubit(
    ProjectService projectService,
    ConnectionService connectionService,
    SseEventTracker sseEventTracker,
    RouteSource routeSource, {
    required SessionUnseenTracker sessionUnseenTracker,
    required RegisteredBridgesService registeredBridgesService,
    required FailureReporter failureReporter,
  }) : _projectService = projectService,
       _connectionService = connectionService,
       _sseEventTracker = sseEventTracker,
       _sessionUnseenTracker = sessionUnseenTracker,
       _registeredBridgesService = registeredBridgesService,
       _failureReporter = failureReporter,
       super(const ProjectListState.loading()) {
    unawaited(_loadInitialProjects());

    // 1. Immediate activity badge updates (no API call).
    _subscriptions.add(
      _sseEventTracker.projectActivity.listen(_onActivityUpdated),
    );

    // 1a. Immediate project timestamp updates from SSE events (no API call).
    _subscriptions.add(
      _sseEventTracker.projectTimestampUpdates.listen(_onProjectTimestampUpdated),
    );

    // 1b. Immediate unseen (bold) updates (no API call).
    _subscriptions.add(
      _sessionUnseenTracker.projectUnseen.listen((_) => _onUnseenUpdated()),
    );

    // 2. Auto-refresh: throttled project data fetch, active only while the
    //    projects page is visible. switchMap cancels the inner subscription
    //    when the route leaves projects and restarts it when coming back.
    _subscriptions.add(
      routeSource.currentRouteStream
          .switchMap((route) {
            if (route != AppRouteDef.projects) return const Stream<void>.empty();
            return _sseEventTracker.projectActivity.throttleTime(
              refreshThrottleDuration,
              trailing: true,
              leading: false,
            );
          })
          .listen((_) {
            if (isClosed) return;
            unawaited(refreshProjects());
          }),
    );

    // 3. Navigate-back refresh: one immediate fetch when the user returns to
    //    the projects page. pairwise() ensures this doesn't fire on the
    //    initial route emission (needs two values before it emits).
    _subscriptions.add(
      routeSource.currentRouteStream
          .distinct()
          .pairwise()
          .where((pair) => pair.first != AppRouteDef.projects && pair.last == AppRouteDef.projects)
          .listen((_) {
            if (isClosed) return;
            unawaited(refreshProjects());
          }),
    );

    // 4. Connection reconnect: silent refresh when connection is restored.
    //    skip(1) ignores the BehaviorSubject replay of the current status —
    //    we only want to react to actual transitions (e.g. disconnected → connected).
    _subscriptions.add(
      _connectionService.status.skip(1).listen(_onConnectionStatusChanged),
    );

    // 5. Stale reconnect: refresh when the relay detects stale state.
    _subscriptions.add(
      _connectionService.dataMayBeStale.listen((_) => _onStaleReconnect()),
    );
  }

  void setActiveProject(Project project) {
    _connectionService.setActiveDirectory(project.id);
  }

  void _onUnseenUpdated() {
    if (isClosed) return;
    if (state case final ProjectListLoaded loaded) {
      emit(loaded.copyWith(unseenByProjectId: _unseenByProjectId(loaded.projects)));
    }
  }

  /// Merges the REST-loaded `Project.hasUnseenChanges` with the live tracker
  /// map (the tracker takes precedence once it has an entry).
  Map<String, bool> _unseenByProjectId(List<Project> projects) {
    final live = _sessionUnseenTracker.currentProjectUnseen;
    return {
      for (final project in projects) project.id: live[project.id] ?? project.hasUnseenChanges,
    };
  }

  void _onActivityUpdated(Map<String, int> activityById) {
    try {
      if (state case final ProjectListLoaded loaded) {
        if (isClosed) return;
        emit(loaded.copyWith(activityById: activityById));
      }
    } catch (e, st) {
      loge("Activity update handler error", e, st);
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "project_list_activity",
              fatal: false,
              reason: "Failed to handle project activity update",
              information: [activityById.toString()],
            )
            .catchError((Object error, StackTrace stackTrace) {
              loge("Failed to report project activity update error", error, stackTrace);
            }),
      );
    }
  }

  void _onProjectTimestampUpdated(Map<String, int> timestampByProjectId) {
    try {
      if (isClosed) return;
      if (state case final ProjectListLoaded loaded) {
        final merged = _mergeProjectTimestampUpdates(
          projects: loaded.projects,
          timestampByProjectId: timestampByProjectId,
        );
        if (!merged.changed) return;

        emit(
          loaded.copyWith(
            projects: merged.projects,
            unseenByProjectId: _unseenByProjectId(merged.projects),
          ),
        );
      }
    } catch (e, st) {
      loge("Project timestamp update handler error", e, st);
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "project_list_timestamp_update",
              fatal: false,
              reason: "Failed to handle project timestamp update",
              information: [timestampByProjectId.toString()],
            )
            .catchError((Object error, StackTrace stackTrace) {
              loge("Failed to report project timestamp update error", error, stackTrace);
            }),
      );
    }
  }

  ({bool changed, List<Project> projects}) _mergeProjectTimestampUpdates({
    required Iterable<Project> projects,
    required Map<String, int> timestampByProjectId,
  }) {
    var changed = false;
    final mergedProjects = projects.map((project) {
      final updated = timestampByProjectId[project.id];
      final time = project.time;
      if (updated == null || time == null || updated <= time.updated) return project;

      changed = true;
      return project.copyWith(time: time.copyWith(updated: updated));
    });
    final sortedProjects = _sortProjects(mergedProjects);
    return (changed: changed, projects: sortedProjects);
  }

  List<Project> _sortProjects(Iterable<Project> projects) {
    return projects.toList()..sort((a, b) => _compareProjectsByTimestampAndName(a: a, b: b));
  }

  int _compareProjectsByTimestampAndName({required Project a, required Project b}) {
    final aUpdated = a.time?.updated;
    final bUpdated = b.time?.updated;
    if (aUpdated == null && bUpdated != null) return 1;
    if (aUpdated != null && bUpdated == null) return -1;

    final updatedCompare = switch ((aUpdated, bUpdated)) {
      (final aUpdatedValue?, final bUpdatedValue?) => bUpdatedValue.compareTo(aUpdatedValue),
      _ => 0,
    };
    if (updatedCompare != 0) return updatedCompare;

    final nameCompare = _effectiveName(a).toLowerCase().compareTo(_effectiveName(b).toLowerCase());
    if (nameCompare != 0) return nameCompare;

    return a.id.compareTo(b.id);
  }

  String _effectiveName(Project project) => project.name ?? project.path;

  /// Whether the bridge (the user's computer) is currently unreachable. With
  /// nothing loaded, the bridge-disconnected flow (setup onboarding or "turn
  /// on your bridge") is surfaced; a non-empty loaded list is kept instead.
  /// `ConnectionLost` is excluded: the list stays loaded so the inline
  /// connection banner (with its reconnect action) owns that state.
  bool get _isBridgeUnavailable => switch (_connectionService.currentStatus) {
    ConnectionDisconnected() || ConnectionBridgeOffline() => true,
    ConnectionConnected() || ConnectionReconnecting() || ConnectionLost() => false,
  };

  void _onConnectionStatusChanged(ConnectionStatus status) {
    logd("[ProjectList] connection status: ${status.runtimeType}");
    if (isClosed) return;
    switch (status) {
      case ConnectionConnected():
        // A reconnect driven by reconnectBridge (the onboarding pull-to-
        // refresh) already owns the reload. Connecting emits this very
        // ConnectionConnected transition synchronously, so without this guard
        // we'd fire a second, non-coalesced fetch and flash a full-screen
        // loading state over the onboarding. Defer to reconnectBridge.
        if (_reconnectBridgeInFlight) break;
        switch (state) {
          case ProjectListLoaded():
            unawaited(refreshProjects());
          case ProjectListFailed():
          case ProjectListBridgeDisconnected():
            unawaited(loadProjects());
          case ProjectListLoading():
            break; // Load already in progress.
        }
      // The relay connection is fully torn down — nothing is reachable and no
      // banner represents this state, so surface the bridge-disconnected flow.
      case ConnectionDisconnected():
        unawaited(_emitBridgeDisconnected());
      case ConnectionBridgeOffline():
        // A non-empty loaded list stays browsable while the bridge is offline —
        // the top-nav connection banner owns the messaging. The full-screen
        // bridge-disconnected flow is reserved for when there is nothing to
        // show (launch before the bridge starts, or an empty list whose
        // onboarding checklist would contradict an offline banner).
        if (state case ProjectListLoaded(:final projects) when projects.isNotEmpty) break;
        unawaited(_emitBridgeDisconnected());
      // Keep the current UI. A loaded list keeps hosting the inline connection
      // banner, which owns the ConnectionLost reconnect action;
      // ConnectionReconnecting is a brief transient.
      case ConnectionReconnecting():
      case ConnectionLost():
        break;
    }
  }

  /// Emits [ProjectListBridgeDisconnected], resolving whether the account has
  /// any registered bridges so the UI can pick the right recovery flow (set
  /// up a bridge vs. turn the existing one on).
  ///
  /// The lookup is async, so the bridge may have come back while it was in
  /// flight — in that case the connected transition owns the next state and
  /// this emit is skipped. Re-emitting an unchanged state is harmless (bloc
  /// dedupes equal states).
  Future<void> _emitBridgeDisconnected() async {
    final hasRegisteredBridges = await _registeredBridgesService.hasRegisteredBridges();
    if (isClosed) return;
    if (!_isBridgeUnavailable) return;
    emit(ProjectListState.bridgeDisconnected(hasRegisteredBridges: hasRegisteredBridges));
    // The machine identity arrives as an enrichment of the already-shown state:
    // the latch above resolves without the network in the common (latched)
    // case, so the recovery view is never held back by this fetch — and a
    // failed fetch (e.g. the phone itself is offline) simply leaves the
    // machine-name row hidden. The setup onboarding has no machine row, so a
    // bridge-less account skips the fetch entirely.
    if (!hasRegisteredBridges) return;
    final bridges = await _registeredBridgesService.getRegisteredBridges();
    if (isClosed || bridges.isEmpty) return;
    // The bridge may have come back while the fetch was in flight — the
    // connected transition owns the next state then.
    if (!_isBridgeUnavailable) return;
    if (state case ProjectListBridgeDisconnected(:final hasRegisteredBridges)) {
      emit(
        ProjectListState.bridgeDisconnected(
          hasRegisteredBridges: hasRegisteredBridges,
          bridges: bridges,
        ),
      );
    }
  }

  void _onStaleReconnect() {
    if (isClosed) return;
    if (state case final ProjectListLoaded loaded) {
      emit(loaded.copyWith(isRefreshing: true));
      unawaited(
        refreshProjects().whenComplete(() {
          if (isClosed) return;
          final current = state;
          if (current is ProjectListLoaded) {
            emit(current.copyWith(isRefreshing: false));
          }
        }),
      );
    }
  }

  Future<void> loadProjects() async {
    emit(const ProjectListState.loading());
    await _fetchProjects();
  }

  Future<void> _loadInitialProjects() async {
    await _prepareInitialConnection();
    if (isClosed) return;
    if (_isBridgeUnavailable) {
      await _emitBridgeDisconnected();
      return;
    }
    await _fetchProjects();
  }

  Future<void> _prepareInitialConnection() async {
    switch (_connectionService.currentStatus) {
      case ConnectionConnected():
      case ConnectionLost():
      case ConnectionBridgeOffline():
        return;
      case ConnectionDisconnected():
        await _connectionService.connectWithFreshAuthToken();
      case ConnectionReconnecting():
        await _waitForInitialConnectionIfNeeded();
    }
  }

  Future<void> _waitForInitialConnectionIfNeeded() async {
    switch (_connectionService.currentStatus) {
      case ConnectionConnected():
      case ConnectionLost():
      case ConnectionBridgeOffline():
        return;
      case ConnectionDisconnected():
      case ConnectionReconnecting():
        break;
    }

    try {
      await _connectionService.status
          .where(
            (status) => status is ConnectionConnected || status is ConnectionLost || status is ConnectionBridgeOffline,
          )
          .first
          .timeout(initialProjectLoadConnectionWaitTimeout);
    } on TimeoutException catch (_) {
      logw("Initial project load continuing before relay connection is ready");
    }
  }

  /// Retries loading projects after a failure.
  ///
  /// Unlike [loadProjects], this method triggers a relay reconnection
  /// when the connection is not active, then waits for the result before
  /// fetching. This ensures the retry actually reaches the bridge instead
  /// of failing immediately with a "not connected" error.
  Future<void> retryLoadProjects() async {
    emit(const ProjectListState.loading());
    // Yield to the event loop so the loading indicator renders before
    // the reconnection / fetch attempt (which may resolve synchronously
    // when the relay is disconnected).
    await Future<void>.delayed(Duration.zero);
    if (isClosed) return;
    await _reconnectIfNeeded();
    if (isClosed) return;
    await _fetchProjects();
  }

  /// Attempts to reconnect the relay when it is not in the
  /// [ConnectionConnected] state. Returns once the connection resolves
  /// (connected, lost, or timed out).
  Future<void> _reconnectIfNeeded() async {
    if (_connectionService.currentStatus is ConnectionConnected) return;

    if (_connectionService.currentStatus is! ConnectionReconnecting) {
      _connectionService.reconnect();
    }
    // If reconnect is now in progress, wait for the outcome.
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

  /// True while [reconnectBridge] is re-establishing the connection. The
  /// connection-status listener ([_onConnectionStatusChanged]) defers its own
  /// reload to reconnectBridge during this window — see the guard there.
  bool _reconnectBridgeInFlight = false;

  /// In-flight bridge reconnect, used for coalescing.
  Future<void>? _activeReconnect;

  /// Re-attempts to reach the bridge from the disconnected state. Recovery from
  /// [ProjectListBridgeDisconnected] is otherwise passive — it waits for a
  /// [ConnectionConnected] transition that, for a never-connected bridge
  /// ([ConnectionDisconnected]), may never arrive on its own. This actively
  /// re-establishes the connection, then reloads.
  ///
  /// Does not emit a loading state: the caller (a [RefreshIndicator]) shows its
  /// own progress, so the disconnected body stays visible until a result is
  /// known.
  ///
  /// Concurrent calls are coalesced: the page's pull-to-refresh and the offline
  /// body's Reconnect button both land here and neither blocks the other, so a
  /// second attempt would fetch behind the first and release
  /// [_reconnectBridgeInFlight] while the first is still connecting.
  Future<void> reconnectBridge() {
    return _activeReconnect ??= _reconnectBridge().whenComplete(() => _activeReconnect = null);
  }

  /// [_reconnectBridgeInFlight] is held for the whole method so the
  /// ConnectionConnected transition emitted while connecting doesn't also drive
  /// [_onConnectionStatusChanged] into a duplicate (loading-flashing) reload —
  /// reconnectBridge owns the single, silent fetch below.
  Future<void> _reconnectBridge() async {
    _reconnectBridgeInFlight = true;
    try {
      if (_connectionService.currentStatus is ConnectionDisconnected) {
        // No active config yet — establish a fresh connection from scratch.
        await _connectionService.connectWithFreshAuthToken();
      } else {
        // An existing config dropped (e.g. bridge offline) — reconnect it.
        await _reconnectIfNeeded();
      }
      if (isClosed) return;
      if (_isBridgeUnavailable) {
        await _emitBridgeDisconnected();
        return;
      }
      await _fetchProjects();
    } finally {
      _reconnectBridgeInFlight = false;
    }
  }

  /// In-flight silent refresh, used for coalescing.
  Future<bool>? _activeRefresh;

  /// Re-fetches projects without showing the full-screen loading indicator.
  /// Concurrent calls are coalesced: if a refresh is already in-flight, the
  /// existing Future is returned instead of starting a second network request.
  Future<bool> refreshProjects() {
    return _activeRefresh ??= _fetchProjects(silent: true).whenComplete(() => _activeRefresh = null);
  }

  /// Calls the bridge API to hide the project, then optimistically removes
  /// it from the current state on success.
  Future<void> hideProject(String projectId) async {
    final response = await _projectService.hideProject(projectId: projectId);
    if (isClosed) return;
    if (response is! SuccessResponse) return;
    if (state case final ProjectListLoaded loaded) {
      final remaining = loaded.projects.where((p) => p.id != projectId).toList();
      emit(
        loaded.copyWith(
          projects: remaining,
          unseenByProjectId: _unseenByProjectId(remaining),
        ),
      );
      // Hiding the last project lands on the connected-empty body, which
      // names the machine — same follow-up enrichment as an empty fetch.
      if (remaining.isEmpty) unawaited(_enrichLoadedEmptyWithBridges());
    }
  }

  /// Creates a new project at [path].
  ///
  /// On success the project list is refreshed. A permission denial from the
  /// bridge is reported distinctly so the UI can show an actionable message.
  Future<AddProjectOutcome> createProject({required String path}) async {
    final response = await _projectService.createProject(path: path);
    if (isClosed) return AddProjectOutcome.otherError;
    switch (response) {
      case SuccessResponse():
        await refreshProjects();
        return AddProjectOutcome.success;
      case ErrorResponse(:final error):
        return _addProjectFailureOutcome(error);
    }
  }

  /// Renames the project with [projectId] to [name].
  /// Returns `true` on success (and refreshes the project list), `false` on error.
  Future<bool> renameProject({required String projectId, required String name}) async {
    final response = await _projectService.renameProject(projectId: projectId, name: name);
    if (isClosed) return false;
    switch (response) {
      case SuccessResponse():
        await refreshProjects();
        return true;
      case ErrorResponse():
        return false;
    }
  }

  /// Discovers an existing project at [path].
  ///
  /// On success the project list is refreshed. A permission denial from the
  /// bridge is reported distinctly so the UI can show an actionable message.
  Future<AddProjectOutcome> discoverProject({required String path}) async {
    final response = await _projectService.discoverProject(path: path);
    if (isClosed) return AddProjectOutcome.otherError;
    switch (response) {
      case SuccessResponse():
        await refreshProjects();
        return AddProjectOutcome.success;
      case ErrorResponse(:final error):
        return _addProjectFailureOutcome(error);
    }
  }

  /// Fetches child directories of [prefix] for the directory browser.
  ///
  /// A permission denial from the bridge is reported distinctly so the browser
  /// can show an actionable macOS Full Disk Access message.
  Future<FilesystemSuggestionsOutcome> fetchFilesystemSuggestions({required String? prefix}) async {
    final response = await _projectService.getFilesystemSuggestions(prefix: prefix);
    switch (response) {
      case SuccessResponse(:final data):
        return FilesystemSuggestionsSuccess(suggestions: data);
      case ErrorResponse(:final error):
        if (_isPermissionDenied(error)) {
          return const FilesystemSuggestionsPermissionDenied();
        }
        return const FilesystemSuggestionsError();
    }
  }

  AddProjectOutcome _addProjectFailureOutcome(ApiError error) {
    if (_isPermissionDenied(error)) {
      return AddProjectOutcome.permissionDenied;
    }
    return AddProjectOutcome.otherError;
  }

  bool _isPermissionDenied(ApiError error) {
    return error is NonSuccessCodeError && error.errorCode == 403;
  }

  /// The current loaded state's registered bridges, or empty outside a loaded
  /// state.
  List<BridgeSummary> get _loadedBridges => switch (state) {
    ProjectListLoaded(:final bridges) => bridges,
    ProjectListLoading() || ProjectListFailed() || ProjectListBridgeDisconnected() => const [],
  };

  /// Enriches an empty loaded list with the account's registered bridges so
  /// the connected-but-empty body can name the machine it is connected to.
  /// Mirrors the bridge-disconnected enrichment: the empty state shows
  /// immediately and the machine row lands in a follow-up emit once the fetch
  /// resolves; a failed fetch (empty list) leaves the row hidden. No
  /// registered-bridges gate is needed here — a loaded state means a bridge is
  /// connected, so the account has one by definition.
  Future<void> _enrichLoadedEmptyWithBridges() async {
    final bridges = await _registeredBridgesService.getRegisteredBridges();
    if (isClosed || bridges.isEmpty) return;
    // Projects may have arrived while the fetch was in flight — that state
    // owns the screen and has no machine row to enrich.
    if (state case final ProjectListLoaded loaded when loaded.projects.isEmpty) {
      emit(loaded.copyWith(bridges: bridges));
    }
  }

  Future<bool> _fetchProjects({bool silent = false}) async {
    // Captured BEFORE the fetch so the seed can't overwrite a live update that
    // arrives while the request is in flight.
    final unseenTick = _sessionUnseenTracker.tick;
    final projectResponse = await _projectService.listProjects();
    if (isClosed) return false;

    switch (projectResponse) {
      case SuccessResponse(data: Projects(data: final projects)):
        final sortedProjects = _mergeProjectTimestampUpdates(
          projects: projects,
          timestampByProjectId: _sseEventTracker.currentProjectTimestampUpdates,
        ).projects;
        // The REST aggregate is authoritative at fetch time — seed the tracker
        // so a stale live `true` can't keep a project bold after its last
        // unseen session was archived/deleted while an echo was missed.
        _sessionUnseenTracker.seedProjects(
          {for (final p in sortedProjects) p.id: p.hasUnseenChanges},
          sinceTick: unseenTick,
        );
        emit(
          ProjectListState.loaded(
            projects: sortedProjects,
            activityById: _sseEventTracker.currentProjectActivity,
            unseenByProjectId: _unseenByProjectId(sortedProjects),
            // Carrying the previous machine identity over keeps the row from
            // flickering out and back across a refresh of a still-empty list.
            bridges: sortedProjects.isEmpty ? _loadedBridges : const [],
          ),
        );
        if (sortedProjects.isEmpty) unawaited(_enrichLoadedEmptyWithBridges());
        return true;

      case ErrorResponse(:final error):
        if (silent) {
          logw("Failed to refresh projects: ${error.toString()}");
        } else if (_isBridgeUnavailable) {
          // The fetch failed because the bridge isn't connected — show the
          // bridge-disconnected flow rather than a generic error.
          await _emitBridgeDisconnected();
        } else {
          loge("Project list load failed", error);
          emit(ProjectListState.failed(reason: error.remoteFailureReason));
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
