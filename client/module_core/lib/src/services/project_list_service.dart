import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/project_repository.dart";
import "models/session_activity_info.dart";
import "models/session_list_item_state.dart";
import "session_activity_calculator.dart";

@lazySingleton
class ProjectListService({
  required final ProjectRepository _repository,
  required final SessionActivityCalculator _activityCalculator,
}) {
  final StreamController<List<ProjectSummary>> _listedProjects = StreamController.broadcast(sync: true);
  int _listGeneration = 0;

  /// Every winning successful authoritative project snapshot, without retaining a
  /// second project inventory alongside ProjectInventoryService.
  Stream<List<ProjectSummary>> get listedProjects => _listedProjects.stream;

  Future<ApiResponse<Projects>> listProjects() async {
    final generation = ++_listGeneration;
    final response = await _repository.listProjects();
    return switch (response) {
      SuccessResponse(:final data) => () {
        final projects = List<ProjectSummary>.unmodifiable(_sortProjects(data.data));
        if (generation == _listGeneration && !_listedProjects.isClosed) _listedProjects.add(projects);
        return ApiResponse.success(Projects(data: projects));
      }(),
      ErrorResponse(:final error) => ApiResponse.error(error),
    };
  }

  ({bool changed, List<ProjectSummary> projects}) mergeTimestampUpdates({
    required Iterable<ProjectSummary> projects,
    required Map<String, int> timestampByProjectId,
  }) {
    var changed = false;
    final mergedProjects = <ProjectSummary>[];
    for (final project in projects) {
      final updated = timestampByProjectId[project.id];
      final time = project.time;
      if (updated != null && time != null && updated > time.updated) {
        changed = true;
        mergedProjects.add(project.copyWith(time: time.copyWith(updated: updated)));
      } else {
        mergedProjects.add(project);
      }
    }
    return (changed: changed, projects: _sortProjects(mergedProjects));
  }

  /// Applies an accepted local hide and publishes the resulting inventory.
  /// Incrementing the generation prevents an older list response from
  /// republishing the hidden project.
  List<ProjectSummary> removeProjectAndPublish({
    required Iterable<ProjectSummary> projects,
    required String projectId,
  }) {
    _listGeneration++;
    final remaining = List<ProjectSummary>.unmodifiable(
      _sortProjects(projects.where((project) => project.id != projectId)),
    );
    if (!_listedProjects.isClosed) _listedProjects.add(remaining);
    return remaining;
  }

  /// Running projects first, and each one's running-session count. A session
  /// only waiting for input is not running.
  ({List<ProjectSummary> projects, Map<String, int> runningByProjectId}) orderProjects({
    required Iterable<ProjectSummary> projects,
    required Map<String, Map<String, SessionActivityInfo>> activityByProjectId,
    required Map<String, Map<String, SessionListItemState>> listStateByProjectId,
  }) {
    final running = <ProjectSummary>[];
    final remaining = <ProjectSummary>[];
    final runningActivityAtByProjectId = <String, int>{};
    final runningByProjectId = <String, int>{};
    for (final project in projects) {
      final activity = activityByProjectId[project.id];
      final runningSessions = activity?.entries
          .where((entry) => _activityCalculator.isRunning(activity: entry.value))
          .toList(growable: false);
      if (runningSessions != null && runningSessions.isNotEmpty) {
        running.add(project);
        runningByProjectId[project.id] = runningSessions.length;
        runningActivityAtByProjectId[project.id] = runningSessions
            .map(
              (entry) =>
                  latestUserActivityAt(
                    first: listStateByProjectId[project.id]?[entry.key]?.lastUserActivityAt,
                    second: entry.value.lastUserActivityAt,
                  ) ??
                  entry.value.updatedAt ??
                  project.time?.updated ??
                  0,
            )
            .reduce((latest, candidate) => candidate > latest ? candidate : latest);
      } else {
        remaining.add(project);
      }
    }
    running.sort((a, b) {
      final aActivityAt = runningActivityAtByProjectId[a.id] ?? 0;
      final bActivityAt = runningActivityAtByProjectId[b.id] ?? 0;
      final activityCompare = bActivityAt.compareTo(aActivityAt);
      return activityCompare != 0 ? activityCompare : a.id.compareTo(b.id);
    });
    return (projects: [...running, ..._sortProjects(remaining)], runningByProjectId: runningByProjectId);
  }

  List<ProjectSummary> _sortProjects(Iterable<ProjectSummary> projects) {
    return projects.toList()..sort((a, b) => _compareProjectsByTimestampAndName(a: a, b: b));
  }

  int _compareProjectsByTimestampAndName({required ProjectSummary a, required ProjectSummary b}) {
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

  String _effectiveName(ProjectSummary project) => project.name ?? project.path;

  @disposeMethod
  Future<void> dispose() => _listedProjects.close();
}
