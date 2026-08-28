import "dart:async";

import "package:sesori_shared/sesori_shared.dart" show Project;

import "../repositories/project_repository.dart";

/// Loads the current project for the route boundary and publishes successful
/// loads for independent background consumers.
class CurrentProjectService({required final ProjectRepository _projectRepository}) {
  final StreamController<String> _loadedProjectIds = StreamController<String>.broadcast(sync: true);
  bool _disposed = false;

  Stream<String> get loadedProjectIds => _loadedProjectIds.stream;

  Future<Project> getCurrentProject({required String projectId}) async {
    final project = await _projectRepository.getProject(projectId: projectId);
    if (!_disposed) {
      _loadedProjectIds.add(project.id);
    }
    return project;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _loadedProjectIds.close();
  }
}
