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
    return (changed: changed, projects: mergedProjects);
  }

  List<Project> removeProject({required Iterable<Project> projects, required String projectId}) {
    return _sortProjects(projects.where((project) => project.id != projectId));
  }

  List<Project> _sortProjects(Iterable<Project> projects) {
    return projects.toList()..sort((a, b) => _compareProjectsByNameAndId(a: a, b: b));
  }

  int _compareProjectsByNameAndId({required Project a, required Project b}) {
    final nameCompare = _effectiveName(a).toLowerCase().compareTo(_effectiveName(b).toLowerCase());
    if (nameCompare != 0) return nameCompare;

    return a.id.compareTo(b.id);
  }

  String _effectiveName(Project project) {
    final name = project.name;
    if (name != null) return name;

    final path = project.path.isEmpty ? project.id : project.path;
    final segments = path.replaceAll(r"\", "/").split("/").where((segment) => segment.isNotEmpty);
    return segments.isEmpty ? path : segments.last;
  }
}
