import "dart:async";

import "package:bloc/bloc.dart";
import "package:meta/meta.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/project/project_service.dart";
import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../capabilities/sse/sse_event_repository.dart";
import "../../logging/logging.dart";
import "../../platform/route_source.dart";
import "../../routing/app_routes.dart";
import "project_list_state.dart";

/// How long to wait after an activity event before auto-refreshing project
/// data. Events during this window are coalesced into a single refresh.
@visibleForTesting
const refreshThrottleDuration = Duration(seconds: 30);

class ProjectListCubit extends Cubit<ProjectListState> {
  final ProjectService _projectService;
  final ConnectionService _connectionService;
  final SseEventRepository _sseEventRepository;
  final FailureReporter _failureReporter;
  final CompositeSubscription _subscriptions = CompositeSubscription();

  // ignore: no_slop_linter/prefer_required_named_parameters, public cubit constructor API
  ProjectListCubit(
    ProjectService projectService,
    ConnectionService connectionService,
    SseEventRepository sseEventRepository,
    RouteSource routeSource, {
    required FailureReporter failureReporter,
  }) : _projectService = projectService,
       _connectionService = connectionService,
       _sseEventRepository = sseEventRepository,
       _failureReporter = failureReporter,
       super(const ProjectListState.loading()) {
    loadProjects();

    // 1. Immediate activity badge updates (no API call).
    _subscriptions.add(
      _sseEventRepository.projectActivity.listen(_onActivityUpdated),
    );

    // 2. Auto-refresh: throttled project data fetch, active only while the
    //    projects page is visible. switchMap cancels the inner subscription
    //    when the route leaves projects and restarts it when coming back.
    _subscriptions.add(
      routeSource.currentRouteStream
          .switchMap((route) {
            if (route != AppRouteDef.projects) return const Stream<void>.empty();
            return _sseEventRepository.projectActivity.throttleTime(
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

  void _onActivityUpdated(Map<String, int> activityById) {
    try {
      if (state case final ProjectListLoaded loaded) {
        if (isClosed) return;
        emit(
          ProjectListState.loaded(
            projects: loaded.projects,
            activityById: activityById,
          ),
        );
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
            .catchError((_) {}),
      );
    }
  }

  void _onConnectionStatusChanged(ConnectionStatus status) {
    logd("[ProjectList] connection status: ${status.runtimeType}");
    if (isClosed) return;
    if (status is ConnectionConnected) {
      switch (state) {
        case ProjectListLoaded():
          unawaited(refreshProjects());
        case ProjectListFailed():
          unawaited(loadProjects());
        case ProjectListLoading():
          break; // Load already in progress.
      }
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
      emit(
        ProjectListState.loaded(
          projects: loaded.projects.where((p) => p.id != projectId).toList(),
          activityById: loaded.activityById,
        ),
      );
    }
  }

  /// Creates a new project at [path].
  /// Returns `true` on success (and refreshes the project list), `false` on error.
  Future<bool> createProject({required String path}) async {
    final response = await _projectService.createProject(path: path);
    if (isClosed) return false;
    switch (response) {
      case SuccessResponse():
        await refreshProjects();
        return true;
      case ErrorResponse():
        return false;
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
  /// Returns `true` on success, `false` on error.
  Future<bool> discoverProject({required String path}) async {
    final response = await _projectService.discoverProject(path: path);
    if (isClosed) return false;
    switch (response) {
      case SuccessResponse():
        await refreshProjects();
        return true;
      case ErrorResponse():
        return false;
    }
  }

  Future<bool> _fetchProjects({bool silent = false}) async {
    final projectResponse = await _projectService.listProjects();
    if (isClosed) return false;

    switch (projectResponse) {
      case SuccessResponse(data: Projects(data: final projects)):
        emit(
          ProjectListState.loaded(
            projects: projects,
            activityById: _sseEventRepository.currentProjectActivity,
          ),
        );
        return true;

      case ErrorResponse(:final error):
        if (silent) {
          logw("Failed to refresh projects: ${error.toString()}");
        } else {
          emit(ProjectListState.failed(error: error));
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
