import "dart:async";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/project/project_service.dart";
import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/sse/sse_event_repository.dart";
import "../../logging/logging.dart";
import "project_list_state.dart";

class ProjectListCubit extends Cubit<ProjectListState> {
  final ProjectService _projectService;
  final ConnectionService _connectionService;
  final SseEventRepository _sseEventRepository;
  final CompositeSubscription _subscriptions = CompositeSubscription();

  ProjectListCubit(
    ProjectService projectService,
    ConnectionService connectionService,
    SseEventRepository sseEventRepository,
  ) : _projectService = projectService,
      _connectionService = connectionService,
      _sseEventRepository = sseEventRepository,
      super(const ProjectListState.loading()) {
    loadProjects();
    _subscriptions.add(
      _sseEventRepository.projectActivity.listen(_onActivityUpdated),
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
    _subscriptions.dispose();
    return super.close();
  }
}
