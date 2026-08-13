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
  Future<ApiResponse<Projects>> listProjects() async {
    final response = await _repository.listProjects();
    return switch (response) {
      SuccessResponse(:final data) => ApiResponse.success(Projects(data: _sortProjects(data.data))),
      ErrorResponse(:final error) => ApiResponse.error(error),
    };
  }

  ({bool changed, List<Project> projects}) mergeTimestampUpdates({
    required Iterable<Project> projects,
    required Map<String, int> timestampByProjectId,
  }) {
    var changed = false;
    final mergedProjects = <Project>[];
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

  List<Project> removeProject({required Iterable<Project> projects, required String projectId}) {
    return _sortProjects(projects.where((project) => project.id != projectId));
  }

  List<Project> orderProjects({
    required Iterable<Project> projects,
    required Map<String, Map<String, SessionActivityInfo>> activityByProjectId,
    required Map<String, Map<String, SessionListItemState>> listStateByProjectId,
  }) {
    final running = <Project>[];
    final remaining = <Project>[];
    final runningActivityAtByProjectId = <String, int>{};
    for (final project in projects) {
      final activity = activityByProjectId[project.id];
      final runningSessions = activity?.entries
          .where((entry) => _activityCalculator.isRunning(activity: entry.value))
          .toList(growable: false);
      if (runningSessions != null && runningSessions.isNotEmpty) {
        running.add(project);
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
    return [...running, ..._sortProjects(remaining)];
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
}
