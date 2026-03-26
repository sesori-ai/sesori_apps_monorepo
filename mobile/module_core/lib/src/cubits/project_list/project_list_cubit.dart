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
  final CompositeSubscription _subscriptions = CompositeSubscription();

  ProjectListCubit(
    ProjectService projectService,
    ConnectionService connectionService,
    SseEventRepository sseEventRepository,
    RouteSource routeSource,
  ) : _projectService = projectService,
      _connectionService = connectionService,
      _sseEventRepository = sseEventRepository,
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
            if (route != AppRoute.projects) return const Stream<void>.empty();
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
          .where((pair) => pair.first != AppRoute.projects && pair.last == AppRoute.projects)
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
  }

  void setActiveProject(Project project) {
    _connectionService.setActiveDirectory(project.id);
  }

  void _onActivityUpdated(Map<String, int> activityById) {
    if (state is! ProjectListLoaded) return;
    if (isClosed) return;
    emit(
      ProjectListState.loaded(
        projects: (state as ProjectListLoaded).projects,
        activityById: activityById,
      ),
    );
  }

  void _onConnectionStatusChanged(ConnectionStatus status) {
    logd("[ProjectList] connection status: ${status.runtimeType}");
    if (isClosed) return;
    if (status is ConnectionConnected && state is ProjectListLoaded) {
      unawaited(refreshProjects());
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
    if (state is! ProjectListLoaded) return;
    final loaded = state as ProjectListLoaded;
    emit(
      ProjectListState.loaded(
        projects: loaded.projects.where((p) => p.id != projectId).toList(),
        activityById: loaded.activityById,
      ),
    );
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
      case SuccessResponse(:final data):
        final projects = data.toList();
        projects.sort(
          (a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0),
        );
        emit(
          ProjectListState.loaded(
            projects: projects,
            activityById: _sseEventRepository.currentProjectActivity,
          ),
        );
        return true;

      case ErrorResponse(:final error):
        if (silent) {
          logw("Failed to refresh projects: $error");
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
