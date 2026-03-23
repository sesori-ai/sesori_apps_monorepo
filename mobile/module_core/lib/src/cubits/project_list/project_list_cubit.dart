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
  final CompositeSubscription _subscriptions = CompositeSubscription();

  /// Manual load/refresh requests feed into this subject so that all state
  /// emission flows through the single merged stream pipeline.
  final PublishSubject<_RefreshRequest> _refreshRequests = PublishSubject();

  ProjectListCubit(
    ProjectService projectService,
    ConnectionService connectionService,
    SseEventRepository sseEventRepository,
    RouteSource routeSource,
  ) : _projectService = projectService,
      _connectionService = connectionService,
      _sseEventRepository = sseEventRepository,
      super(const ProjectListState.loading()) {
    _subscriptions.add(
      Rx.merge<ProjectListState?>([
        // Immediate activity badge updates (no API call).
        _sseEventRepository.projectActivity.map(_applyActivityBadge),

        // Auto-refresh: route-gated, throttled project data refresh.
        // When the projects page is visible, activity events trigger a
        // throttled fetch. On navigate-back, an immediate fetch fires.
        routeSource.currentRouteStream.switchMap((route) {
          if (route != AppRoute.projects) {
            return const Stream<ProjectListState?>.empty();
          }
          return Rx.merge<void>([
            // Immediate refresh when entering the page. switchMap cancels
            // this chain when the route leaves projects and re-enters it,
            // so we get one instant fetch per navigation.
            Stream<void>.value(null),
            // Throttled refresh from activity events while on the page.
            // skip(1) drops the BehaviorSubject replay (the immediate
            // fetch above already covers it).
            _sseEventRepository.projectActivity
                .skip(1)
                .throttleTime(refreshThrottleDuration, trailing: true, leading: false),
          ]).asyncMap((_) => _fetchProjectsQuietly());
        }),

        // Manual load/refresh requests (initial load, pull-to-refresh, retry).
        _refreshRequests.switchMap(_handleRefreshRequest),
      ]).whereType<ProjectListState>().listen((state) {
        if (isClosed) return;
        emit(state);
      }),
    );

    // Trigger initial load through the stream pipeline.
    loadProjects();
  }

  void setActiveProject(Project project) {
    _connectionService.setActiveDirectory(project.id);
  }

  /// Triggers a full load (shows loading indicator, emits error on failure).
  Future<void> loadProjects() async {
    final completer = Completer<bool>();
    _refreshRequests.add(_RefreshRequest(silent: false, completer: completer));
    await completer.future;
  }

  /// Re-fetches projects without showing the full-screen loading indicator.
  /// Returns `false` when the refresh fails so the UI can show feedback.
  Future<bool> refreshProjects() async {
    final completer = Completer<bool>();
    _refreshRequests.add(_RefreshRequest(silent: true, completer: completer));
    return completer.future;
  }

  // ---------------------------------------------------------------------------
  // Stream pipeline helpers
  // ---------------------------------------------------------------------------

  /// Maps an activity event to an updated loaded state, or null if the cubit
  /// is not yet loaded (the null is filtered by [whereType] in the merge).
  ProjectListState? _applyActivityBadge(Map<String, int> activityById) {
    final s = state;
    if (s is! ProjectListLoaded) return null;
    return ProjectListState.loaded(
      projects: s.projects,
      activityById: activityById,
    );
  }

  /// Fetches projects silently (no loading indicator, no error state).
  /// Returns null on failure so the merge pipeline can filter it out.
  Future<ProjectListState?> _fetchProjectsQuietly() async {
    final response = await _projectService.listProjects();
    if (isClosed) return null;
    if (response case SuccessResponse(:final data)) {
      final projects = data.toList();
      projects.sort(
        (a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0),
      );
      return ProjectListState.loaded(
        projects: projects,
        activityById: _sseEventRepository.currentProjectActivity,
      );
    }
    logw("Failed to auto-refresh projects: $response");
    return null;
  }

  /// Processes a manual load/refresh request as a stream of state updates.
  Stream<ProjectListState?> _handleRefreshRequest(_RefreshRequest request) async* {
    if (!request.silent) {
      yield const ProjectListState.loading();
    }

    final response = await _projectService.listProjects();
    if (isClosed) {
      request.completer?.complete(false);
      return;
    }

    switch (response) {
      case SuccessResponse(:final data):
        final projects = data.toList();
        projects.sort(
          (a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0),
        );
        request.completer?.complete(true);
        yield ProjectListState.loaded(
          projects: projects,
          activityById: _sseEventRepository.currentProjectActivity,
        );
      case ErrorResponse(:final error):
        request.completer?.complete(false);
        if (request.silent) {
          logw("Failed to refresh projects: $error");
        } else {
          yield ProjectListState.failed(error: error);
        }
    }
  }

  @override
  Future<void> close() {
    _refreshRequests.close();
    _subscriptions.dispose();
    return super.close();
  }
}

class _RefreshRequest {
  final bool silent;
  final Completer<bool>? completer;
  const _RefreshRequest({required this.silent, this.completer});
}
