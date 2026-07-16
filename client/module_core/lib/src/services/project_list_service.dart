import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/project_repository.dart";

@lazySingleton
class ProjectListService {
  final ProjectRepository _repository;

  ProjectListService({required ProjectRepository repository}) : _repository = repository;

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
