import "dart:async";

import "package:bloc/bloc.dart";
import "package:meta/meta.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/project/project_service.dart";
import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/sse/sse_event_repository.dart";
import "../../logging/logging.dart";
import "../../platform/route_source.dart";
import "../../routing/app_routes.dart";
import "project_list_state.dart";

/// How long to wait after the first activity event before refreshing project
/// data. Additional events during this window are coalesced into a single
/// refresh, avoiding excessive API calls during active sessions.
@visibleForTesting
const refreshThrottleDuration = Duration(seconds: 30);

class ProjectListCubit extends Cubit<ProjectListState> {
  final ProjectService _projectService;
  final ConnectionService _connectionService;
  final SseEventRepository _sseEventRepository;
  final RouteSource _routeSource;
  final CompositeSubscription _subscriptions = CompositeSubscription();

  Timer? _refreshTimer;
  bool _refreshPending = false;

  ProjectListCubit(
    ProjectService projectService,
    ConnectionService connectionService,
    SseEventRepository sseEventRepository,
    RouteSource routeSource,
  ) : _projectService = projectService,
      _connectionService = connectionService,
      _sseEventRepository = sseEventRepository,
      _routeSource = routeSource,
      super(const ProjectListState.loading()) {
    loadProjects();
    _subscriptions.add(
      _sseEventRepository.projectActivity.listen(_onActivityUpdated),
    );
    _subscriptions.add(
      _routeSource.currentRouteStream.listen(_onRouteChanged),
    );
  }

  void setActiveProject(Project project) {
    _connectionService.setActiveDirectory(project.id);
  }

  void _onActivityUpdated(Map<String, int> activityById) {
    if (state is! ProjectListLoaded) return;
    if (isClosed) return;

    // Always update activity badges immediately — this is cheap (no API call).
    emit(
      ProjectListState.loaded(
        projects: (state as ProjectListLoaded).projects,
        activityById: activityById,
      ),
    );

    // Schedule a throttled project data refresh so that timestamps update too.
    _scheduleRefresh();
  }

  /// Schedules a throttled [refreshProjects] call.
  ///
  /// When the projects page is visible, the first event starts a 30-second
  /// timer. Additional events during that window are coalesced. If another
  /// route is visible, the refresh is deferred until projects becomes active.
  void _scheduleRefresh() {
    if (_routeSource.currentRoute != AppRoute.projects) {
      _refreshPending = true;
      return;
    }

    if (_refreshTimer != null) return;

    _refreshTimer = Timer(refreshThrottleDuration, () {
      unawaited(_runScheduledRefresh());
    });
  }

  Future<void> _runScheduledRefresh() async {
    if (isClosed) return;

    try {
      if (_routeSource.currentRoute != AppRoute.projects) {
        _refreshPending = true;
        return;
      }
      _refreshPending = false;
      await refreshProjects();
    } finally {
      _refreshTimer = null;
    }
  }

  void _onRouteChanged(AppRoute? currentRoute) {
    if (isClosed) return;
    if (currentRoute == AppRoute.projects && _refreshPending) {
      _refreshPending = false;
      unawaited(refreshProjects());
    }
  }

  Future<void> loadProjects() async {
    emit(const ProjectListState.loading());
    await _fetchProjects();
  }

  /// Re-fetches projects without showing the full-screen loading indicator.
  /// Returns `false` when the refresh fails so the UI can show feedback.
  Future<bool> refreshProjects() async {
    return _fetchProjects(silent: true);
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
    _refreshTimer?.cancel();
    _subscriptions.dispose();
    return super.close();
  }
}
