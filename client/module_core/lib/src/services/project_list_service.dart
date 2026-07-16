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
      SuccessResponse(:final data) => ApiResponse.success(data),
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

  List<Project> removeProject({
    required Iterable<Project> projects,
    required String projectId,
  }) {
    return projects.where((project) => project.id != projectId).toList();
  }

  List<Project> sortProjects({
    required Iterable<Project> projects,
    required Set<String> activeProjectIds,
    required Map<String, int?> lastUserInteractionAtByProjectId,
  }) {
    return projects.toList()..sort(
      (a, b) => _compareProjects(
        a: a,
        b: b,
        activeProjectIds: activeProjectIds,
        lastUserInteractionAtByProjectId: lastUserInteractionAtByProjectId,
      ),
    );
  }

  int _compareProjects({
    required Project a,
    required Project b,
    required Set<String> activeProjectIds,
    required Map<String, int?> lastUserInteractionAtByProjectId,
  }) {
    final aActive = activeProjectIds.contains(a.id);
    final bActive = activeProjectIds.contains(b.id);
    if (aActive != bActive) return aActive ? -1 : 1;

    final timestampCompare = aActive
        ? _compareNullableDescending(
            a: _lastUserInteractionAt(
              project: a,
              lastUserInteractionAtByProjectId: lastUserInteractionAtByProjectId,
            ),
            b: _lastUserInteractionAt(
              project: b,
              lastUserInteractionAtByProjectId: lastUserInteractionAtByProjectId,
            ),
          )
        : _compareNullableDescending(a: a.time?.updated, b: b.time?.updated);
    if (timestampCompare != 0) return timestampCompare;

    final nameCompare = _effectiveName(a).toLowerCase().compareTo(_effectiveName(b).toLowerCase());
    if (nameCompare != 0) return nameCompare;

    return a.id.compareTo(b.id);
  }

  int? _lastUserInteractionAt({
    required Project project,
    required Map<String, int?> lastUserInteractionAtByProjectId,
  }) {
    return lastUserInteractionAtByProjectId.containsKey(project.id)
        ? lastUserInteractionAtByProjectId[project.id]
        : project.lastUserInteractionAt;
  }

  int _compareNullableDescending({required int? a, required int? b}) {
    if (a == null) return b == null ? 0 : 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }

  String _effectiveName(Project project) {
    final name = project.name;
    if (name != null) return name;

    final path = project.path.isEmpty ? project.id : project.path;
    final segments = path.replaceAll(r"\", "/").split("/").where((segment) => segment.isNotEmpty);
    return segments.isEmpty ? path : segments.last;
  }
}
