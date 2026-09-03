import "dart:async";

import "package:bloc/bloc.dart";
import "package:meta/meta.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../errors/api_error_remote_failure_x.dart";
import "../../foundation/models/product_analytics/product_analytics_event.dart";
import "../../logging/logging.dart";
import "../../platform/route_source.dart";
import "../../repositories/models/analytics_delivery_result.dart";
import "../../repositories/project_repository.dart";
import "../../routing/app_routes.dart";
import "../../services/catalog_rescan_service.dart";
import "../../services/loaded_state_analytics_reporter.dart";
import "../../services/models/catalog_rescan_state.dart";
import "../../services/models/session_activity_info.dart";
import "../../services/product_analytics_service.dart";
import "../../services/project_list_service.dart";
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

enum _ProjectFetchOutcome() {
  applied,
  failed,
  superseded,
}

class ProjectListCubit(
  final ProjectRepository _projectRepository,
  final ConnectionService _connectionService,
  final SseEventTracker _sseEventTracker,
  RouteSource routeSource, {
  required final ProjectListService _projectListService,
  required final SessionUnseenTracker _sessionUnseenTracker,
  required final RegisteredBridgesService _registeredBridgesService,
  required final ProductAnalyticsService _productAnalyticsService,
  required final LoadedStateAnalyticsReporter _loadedStateAnalyticsReporter,
  required final FailureReporter _failureReporter,
  required final CatalogRescanService _catalogRescanService,
}) extends Cubit<ProjectListState> {
  final CompositeSubscription _subscriptions = CompositeSubscription();

  // ignore: no_slop_linter/prefer_required_named_parameters, public cubit constructor API
  this : super(const ProjectListState.loading()) {
    unawaited(_loadInitialProjects());

    // 1. Immediate activity badge updates (no API call).
    _subscriptions.add(
      _sseEventTracker.projectActivity.listen(_onActivityUpdated),
    );
    _subscriptions.add(
      _sseEventTracker.sessionActivity.listen(_onSessionActivityUpdated),
    );

    // 1a. Immediate project timestamp updates from SSE events (no API call).
    _subscriptions.add(
      _sseEventTracker.projectTimestampUpdates.listen(_onProjectTimestampUpdated),
    );

    // 1a2. The catalog scan, which any surface can start. Its state is only
    //     projected onto the list; the operation itself is the service's.
    _subscriptions.add(_catalogRescanService.state.listen(_onCatalogScanState));
    // A committed import raises no list invalidation of its own.
    _subscriptions.add(_catalogRescanService.catalogChanged.listen((_) => _onCatalogChanged()));

    // 1b. Immediate unseen (bold) updates (no API call).
    _subscriptions.add(
      _sessionUnseenTracker.projectUnseen.listen((_) => _onUnseenUpdated()),
    );
    _subscriptions.add(
      _sessionUnseenTracker.sessionUnseen.listen((_) => _onSessionListStateUpdated()),
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

  void reportNeedHelpMenuOpened({required OnboardingSurface surface}) {
    _reportProductEvent(event: ProductAnalyticsEvent.needHelpMenuOpened(surface: surface));
  }

  void reportSupportLinkOpened({required SupportChannel channel, required OnboardingSurface surface}) {
    _reportProductEvent(
      event: ProductAnalyticsEvent.supportLinkOpened(channel: channel, surface: surface),
    );
  }

  void reportWhyBridgeOpened({required OnboardingSurface surface}) {
    _reportProductEvent(event: ProductAnalyticsEvent.whyBridgeOpened(surface: surface));
  }

  void reportInstallCommandCopied({
    required BridgeInstallMethod method,
    required BridgeInstallOs os,
    required OnboardingSurface surface,
  }) {
    _reportProductEvent(
      event: ProductAnalyticsEvent.installCommandCopied(method: method, os: os, surface: surface),
    );
  }

  void reportInstallCommandShared({
    required BridgeInstallMethod method,
    required BridgeInstallOs os,
    required OnboardingSurface surface,
  }) {
    _reportProductEvent(
      event: ProductAnalyticsEvent.installCommandShared(method: method, os: os, surface: surface),
    );
  }

  void reportRunCommandCopied({required OnboardingSurface surface}) {
    _reportProductEvent(event: ProductAnalyticsEvent.runCommandCopied(surface: surface));
  }

  void reportRunCommandShared({required OnboardingSurface surface}) {
    _reportProductEvent(event: ProductAnalyticsEvent.runCommandShared(surface: surface));
  }

  void _reportProductEvent({required ProductAnalyticsEvent event}) {
    unawaited(
      _productAnalyticsService.logEvent(event: event, occurredAtUtc: DateTime.now().toUtc()).then<void>((result) {
        if (result == AnalyticsDeliveryResult.failed && _productAnalyticsService.state.isActive) {
          logw("Failed to deliver onboarding analytics event");
        }
      }),
    );
  }

  void _onUnseenUpdated() {
    if (isClosed) return;
    if (state case final ProjectListLoaded loaded) {
      emit(loaded.copyWith(unseenByProjectId: _unseenByProjectId(loaded.projects)));
    }
  }

  /// Merges the REST-loaded `Project.hasUnseenChanges` with the live tracker
  /// map (the tracker takes precedence once it has an entry).
  Map<String, bool> _unseenByProjectId(List<ProjectSummary> projects) {
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

  void _onSessionActivityUpdated(Map<String, Map<String, SessionActivityInfo>> activityByProjectId) {
    if (isClosed) return;
    if (state case final ProjectListLoaded loaded) {
      _emitOrdered(loaded: loaded, projects: loaded.projects, activityByProjectId: activityByProjectId);
    }
  }

  void _onSessionListStateUpdated() {
    if (isClosed) return;
    if (state case final ProjectListLoaded loaded) {
      _emitOrdered(
        loaded: loaded,
        projects: loaded.projects,
        activityByProjectId: _sseEventTracker.currentSessionActivity,
      );
    }
  }

  void _onProjectTimestampUpdated(Map<String, int> timestampByProjectId) {
    try {
      if (isClosed) return;
      if (state case final ProjectListLoaded loaded) {
        final merged = _projectListService.mergeTimestampUpdates(
          projects: loaded.projects,
          timestampByProjectId: timestampByProjectId,
        );
        if (!merged.changed) return;

        _emitOrdered(
          loaded: loaded,
          projects: merged.projects,
          activityByProjectId: _sseEventTracker.currentSessionActivity,
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
        unawaited(_emitBridgeDisconnected(fetchGeneration: null));
      case ConnectionBridgeOffline():
        // A non-empty loaded list stays browsable while the bridge is offline —
        // the top-nav connection banner owns the messaging. The full-screen
        // bridge-disconnected flow is reserved for when there is nothing to
        // show (launch before the bridge starts, or an empty list whose
        // onboarding checklist would contradict an offline banner).
        if (state case ProjectListLoaded(:final projects) when projects.isNotEmpty) break;
        unawaited(_emitBridgeDisconnected(fetchGeneration: null));
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
  ///
  /// Which machine the recovery view is trying to reach is resolved separately
  /// by `BridgeIdentityCubit`, so this state is never held back by that fetch.
  Future<void> _emitBridgeDisconnected({required int? fetchGeneration}) async {
    final hasRegisteredBridges = await _registeredBridgesService.hasRegisteredBridges();
    if (isClosed) return;
    if (fetchGeneration != null && fetchGeneration != _fetchGeneration) return;
    if (!_isBridgeUnavailable) return;
    _loadedStateAnalyticsReporter.clearCurrentOccurrence();
    emit(ProjectListState.bridgeDisconnected(hasRegisteredBridges: hasRegisteredBridges));
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
    _loadedStateAnalyticsReporter.clearCurrentOccurrence();
    emit(const ProjectListState.loading());
    await _fetchProjects(silent: false, catalogRefresh: false);
  }

  Future<void> _loadInitialProjects() async {
    await _prepareInitialConnection();
    if (isClosed) return;
    if (_isBridgeUnavailable) {
      await _emitBridgeDisconnected(fetchGeneration: null);
      return;
    }
    await _fetchProjects(silent: false, catalogRefresh: false);
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
    _loadedStateAnalyticsReporter.clearCurrentOccurrence();
    emit(const ProjectListState.loading());
    // Yield to the event loop so the loading indicator renders before
    // the reconnection / fetch attempt (which may resolve synchronously
    // when the relay is disconnected).
    await Future<void>.delayed(Duration.zero);
    if (isClosed) return;
    await _connectionService.reconnectAndAwaitOutcome(timeout: const Duration(seconds: 15));
    if (isClosed) return;
    await _fetchProjects(silent: false, catalogRefresh: false);
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
        await _connectionService.reconnectAndAwaitOutcome(timeout: const Duration(seconds: 15));
      }
      if (isClosed) return;
      if (_isBridgeUnavailable) {
        await _emitBridgeDisconnected(fetchGeneration: null);
        return;
      }
      await _fetchProjects(silent: false, catalogRefresh: false);
    } finally {
      _reconnectBridgeInFlight = false;
    }
  }

  /// In-flight silent refresh, used for coalescing.
  Future<_ProjectFetchOutcome>? _activeRefresh;

  /// Most recently started read. This is not a coalescing barrier: a refresh
  /// whose response was superseded uses it only to observe the winning result.
  Future<_ProjectFetchOutcome>? _latestFetch;

  /// Monotonically orders list reads so an older response cannot overwrite a
  /// snapshot requested after it.
  int _fetchGeneration = 0;

  /// Durable catalog commits observed by this cubit, and the newest commit a
  /// successfully applied list snapshot has covered.
  int _catalogChangeGeneration = 0;
  int _catalogChangeConsumedGeneration = 0;
  bool _catalogRefreshPausedAfterFailure = false;
  Future<void>? _catalogRefresh;

  /// Re-fetches projects without showing the full-screen loading indicator.
  /// Concurrent ordinary calls coalesce onto the current silent refresh.
  Future<bool> refreshProjects() {
    return _awaitRefreshResult(refresh: _refreshProjects(force: false, catalogRefresh: false));
  }

  /// A catalog refresh can supersede an explicit pull. Wait for the newer read
  /// so the caller reports that read's outcome rather than premature success.
  Future<bool> _awaitRefreshResult({required Future<_ProjectFetchOutcome> refresh}) async {
    var latest = refresh;
    while (true) {
      switch (await latest) {
        case _ProjectFetchOutcome.applied:
          return true;
        case _ProjectFetchOutcome.failed:
          return false;
        case _ProjectFetchOutcome.superseded:
          final winningFetch = _latestFetch;
          if (winningFetch == null || identical(winningFetch, latest)) return false;
          latest = winningFetch;
      }
    }
  }

  Future<_ProjectFetchOutcome> _refreshProjects({
    required bool force,
    required bool catalogRefresh,
  }) {
    final active = _activeRefresh;
    if (!force && active != null) return active;

    late final Future<_ProjectFetchOutcome> refresh;
    refresh = _fetchProjects(silent: true, catalogRefresh: catalogRefresh).whenComplete(() {
      if (identical(_activeRefresh, refresh)) _activeRefresh = null;
    });
    _activeRefresh = refresh;
    return refresh;
  }

  /// Calls the bridge API to hide the project, then removes it from the
  /// current state on success. Returns whether the bridge accepted the hide,
  /// so the UI can report a rejected hide instead of claiming success.
  Future<bool> hideProject(String projectId) async {
    final response = await _projectRepository.hideProject(projectId: projectId);
    if (isClosed) return false;
    if (response case ErrorResponse(:final error)) {
      loge("Failed to hide project: ${error.toString()}");
      return false;
    }
    if (state case final ProjectListLoaded loaded) {
      _emitOrdered(
        loaded: loaded,
        projects: _projectListService.removeProject(
          projects: loaded.projects,
          projectId: projectId,
        ),
        activityByProjectId: _sseEventTracker.currentSessionActivity,
      );
    }
    return true;
  }

  void _emitOrdered({
    required ProjectListLoaded loaded,
    required List<ProjectSummary> projects,
    required Map<String, Map<String, SessionActivityInfo>> activityByProjectId,
  }) {
    final ordered = _projectListService.orderProjects(
      projects: projects,
      activityByProjectId: activityByProjectId,
      listStateByProjectId: _sessionUnseenTracker.currentSessionUnseen,
    );
    emit(
      loaded.copyWith(
        projects: ordered,
        unseenByProjectId: _unseenByProjectId(ordered),
      ),
    );
  }

  /// Creates a new project named [name] below [parentPath].
  ///
  /// On success the project list is refreshed. A permission denial from the
  /// bridge is reported distinctly so the UI can show an actionable message.
  Future<AddProjectOutcome> createProject({
    required String parentPath,
    required String name,
  }) async {
    final response = await _projectRepository.createProject(
      parentPath: parentPath,
      name: name,
    );
    if (isClosed) return AddProjectOutcome.otherError;
    switch (response) {
      case SuccessResponse():
        await refreshProjects();
        return AddProjectOutcome.success;
      case ErrorResponse(:final error):
        return _addProjectFailureOutcome(error);
    }
  }

  /// Creates a plain folder named [name] below [parentPath] on the bridge host.
  ///
  /// The project list is untouched — this only makes the directory, so the
  /// browser can move into it and let the user decide whether to add it.
  Future<CreateDirectoryOutcome> createDirectory({
    required String parentPath,
    required String name,
  }) async {
    final response = await _projectRepository.createDirectory(
      parentPath: parentPath,
      name: name,
    );
    switch (response) {
      case SuccessResponse(:final data):
        return CreateDirectorySuccess(directory: data);
      case ErrorResponse(:final error):
        if (_isPermissionDenied(error)) return const CreateDirectoryPermissionDenied();
        if (error is NonSuccessCodeError && error.errorCode == 409) {
          return const CreateDirectoryAlreadyExists();
        }
        // A bridge that predates this endpoint has no route to answer with.
        if (error is NonSuccessCodeError && error.errorCode == 404) {
          return const CreateDirectoryUnsupported();
        }
        return const CreateDirectoryError();
    }
  }

  String? parentHostPath({required String path}) {
    return _projectRepository.parentHostPath(path: path);
  }

  /// Renames a project optimistically. Returns `false` after restoring the
  /// prior name when the bridge rejects the rename.
  Future<bool> renameProject({required String projectId, required String name}) async {
    final currentState = state;
    if (currentState is! ProjectListLoaded) return false;

    final index = currentState.projects.indexWhere((project) => project.id == projectId);
    if (index < 0) return false;

    final previousName = currentState.projects[index].name;
    final projects = [...currentState.projects];
    projects[index] = projects[index].copyWith(name: name);
    _emitOrdered(
      loaded: currentState,
      projects: projects,
      activityByProjectId: _sseEventTracker.currentSessionActivity,
    );

    final ApiResponse<Project> response;
    try {
      response = await _projectRepository.renameProject(projectId: projectId, name: name);
    } on Object catch (error, stackTrace) {
      loge("Failed to rename project", error, stackTrace);
      _restoreProjectName(
        projectId: projectId,
        optimisticName: name,
        previousName: previousName,
      );
      return false;
    }

    switch (response) {
      case SuccessResponse():
        if (!isClosed) unawaited(refreshProjects());
        return true;
      case ErrorResponse(:final error):
        loge("Failed to rename project", error);
        _restoreProjectName(
          projectId: projectId,
          optimisticName: name,
          previousName: previousName,
        );
        return false;
    }
  }

  void _restoreProjectName({
    required String projectId,
    required String optimisticName,
    required String? previousName,
  }) {
    final currentState = state;
    if (isClosed || currentState is! ProjectListLoaded) return;

    final index = currentState.projects.indexWhere((project) => project.id == projectId);
    if (index < 0 || currentState.projects[index].name != optimisticName) return;

    final projects = [...currentState.projects];
    projects[index] = projects[index].copyWith(name: previousName);
    _emitOrdered(
      loaded: currentState,
      projects: projects,
      activityByProjectId: _sseEventTracker.currentSessionActivity,
    );
  }

  /// Discovers an existing project at [path].
  ///
  /// On success the project list is refreshed. A permission denial from the
  /// bridge is reported distinctly so the UI can show an actionable message.
  Future<OpenProjectOutcome> discoverProject({
    required String path,
    required OpenProjectGitAction gitAction,
  }) async {
    final response = await _projectRepository.discoverProject(
      path: path,
      gitAction: gitAction,
    );
    if (isClosed) return OpenProjectOutcome.otherError;
    switch (response) {
      case SuccessResponse(:final data):
        await refreshProjects();
        if (gitAction == OpenProjectGitAction.initializeGit && !data.supportsDedicatedWorktrees) {
          return OpenProjectOutcome.gitSetupIncomplete;
        }
        return OpenProjectOutcome.success;
      case ErrorResponse(:final error):
        if (error is NonSuccessCodeError && error.errorCode == 428) {
          return OpenProjectOutcome.gitChoiceRequired;
        }
        if (_isPermissionDenied(error)) {
          return OpenProjectOutcome.permissionDenied;
        }
        return OpenProjectOutcome.otherError;
    }
  }

  /// Fetches child directories of [prefix] for the directory browser.
  ///
  /// A permission denial from the bridge is reported distinctly so the browser
  /// can show an actionable macOS Full Disk Access message.
  Future<FilesystemSuggestionsOutcome> fetchFilesystemSuggestions({required String? prefix}) async {
    final response = await _projectRepository.getFilesystemSuggestions(prefix: prefix);
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

  Future<_ProjectFetchOutcome> _fetchProjects({
    required bool silent,
    required bool catalogRefresh,
  }) {
    final requestGeneration = ++_fetchGeneration;
    final catalogChangeGeneration = _catalogChangeGeneration;
    final fetch = _runFetchProjects(
      silent: silent,
      catalogRefresh: catalogRefresh,
      requestGeneration: requestGeneration,
      catalogChangeGeneration: catalogChangeGeneration,
    );
    _latestFetch = fetch;
    return fetch;
  }

  Future<_ProjectFetchOutcome> _runFetchProjects({
    required bool silent,
    required bool catalogRefresh,
    required int requestGeneration,
    required int catalogChangeGeneration,
  }) async {
    var didApplySnapshot = false;
    try {
      // Captured BEFORE the fetch so the seed can't overwrite a live update
      // that arrives while the request is in flight.
      final unseenTick = _sessionUnseenTracker.tick;
      final projectResponse = await _projectListService.listProjects();
      if (isClosed) return _ProjectFetchOutcome.superseded;
      if (requestGeneration != _fetchGeneration) {
        if (projectResponse case ErrorResponse(:final error)) {
          logw(
            "Discarded superseded project list response "
            "(request generation $requestGeneration, current $_fetchGeneration)",
            error,
          );
        }
        return _ProjectFetchOutcome.superseded;
      }

      switch (projectResponse) {
        case SuccessResponse(data: Projects(data: final projects)):
          final mergedProjects = _projectListService
              .mergeTimestampUpdates(
                projects: projects,
                timestampByProjectId: _sseEventTracker.currentProjectTimestampUpdates,
              )
              .projects;
          final sortedProjects = _projectListService.orderProjects(
            projects: mergedProjects,
            activityByProjectId: _sseEventTracker.currentSessionActivity,
            listStateByProjectId: _sessionUnseenTracker.currentSessionUnseen,
          );
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
              catalogScan: _catalogRescanService.state.value,
            ),
          );
          _loadedStateAnalyticsReporter.reportLoaded(
            isEmpty: sortedProjects.isEmpty,
            occurredAtUtc: DateTime.now().toUtc(),
          );
          _consumeCatalogChangesThrough(generation: catalogChangeGeneration);
          didApplySnapshot = true;
          return _ProjectFetchOutcome.applied;

        case ErrorResponse(:final error):
          if (silent && state is! ProjectListLoading) {
            logw("Failed to refresh projects: ${error.toString()}");
          } else if (_isBridgeUnavailable) {
            // The fetch failed because the bridge isn't connected — show the
            // bridge-disconnected flow rather than a generic error.
            await _emitBridgeDisconnected(fetchGeneration: requestGeneration);
            if (isClosed || requestGeneration != _fetchGeneration) {
              return _ProjectFetchOutcome.superseded;
            }
          } else {
            loge("Project list load failed", error);
            _loadedStateAnalyticsReporter.clearCurrentOccurrence();
            emit(ProjectListState.failed(reason: error.remoteFailureReason));
          }
          return _ProjectFetchOutcome.failed;
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
      late final _ProjectFetchOutcome outcome;
      try {
        outcome = await _refreshProjects(force: true, catalogRefresh: true);
      } on Object catch (error, stackTrace) {
        loge("Catalog-change project refresh failed unexpectedly", error, stackTrace);
        _catalogRefreshPausedAfterFailure = true;
        return;
      }

      if (_catalogChangeConsumedGeneration >= _catalogChangeGeneration) return;
      switch (outcome) {
        case _ProjectFetchOutcome.applied:
        case _ProjectFetchOutcome.superseded:
          continue;
        case _ProjectFetchOutcome.failed:
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
    if (state case final ProjectListLoaded loaded) {
      emit(loaded.copyWith(catalogScan: scan));
    }
  }

  @override
  Future<void> close() async {
    await _subscriptions.dispose();
    await _loadedStateAnalyticsReporter.close();
    return await super.close();
  }
}
