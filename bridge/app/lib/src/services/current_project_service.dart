import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show Project;

import "../repositories/project_repository.dart";
import "project_glossary_scope_service.dart";

/// Loads the current project for the route boundary and publishes successful
/// loads for independent background consumers.
class CurrentProjectService({
  required final ProjectRepository _projectRepository,
  required final ProjectGlossaryScopeService _projectGlossaryScopeService,
}) {
  final StreamController<String> _loadedProjectIds = StreamController<String>.broadcast(sync: true);
  bool _disposed = false;

  Stream<String> get loadedProjectIds => _loadedProjectIds.stream;

  Future<Project> getCurrentProject({required String projectId}) async {
    final project = await _projectRepository.getProject(projectId: projectId);
    Project enrichedProject;
    try {
      final scope = await _projectGlossaryScopeService.resolve(projectPath: project.path);
      enrichedProject = project.copyWith(voiceGlossaryKey: scope?.projectKey);
    } on Object catch (error, stackTrace) {
      Log.w("Failed to resolve the current project's voice glossary scope", error, stackTrace);
      enrichedProject = project;
    }
    if (!_disposed) {
      _loadedProjectIds.add(project.id);
    }
    return enrichedProject;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _loadedProjectIds.close();
  }
}
