import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show Project, ProjectGlossaryKey;

import "../repositories/project_repository.dart";
import "project_glossary_scope_service.dart";
import "project_glossary_scope_tracker.dart";

/// Loads the current project for the route boundary and publishes successful
/// loads for independent background consumers.
class CurrentProjectService({
  required final ProjectRepository _projectRepository,
  required final ProjectGlossaryScopeTracker _projectGlossaryScopeTracker,
  required final ProjectGlossaryScopeService _projectGlossaryScopeService,
}) {
  final StreamController<String> _loadedProjectIds = StreamController<String>.broadcast(sync: true);
  bool _disposed = false;

  Stream<String> get loadedProjectIds => _loadedProjectIds.stream;

  Future<Project> getCurrentProject({required String projectId}) async {
    final project = await _projectRepository.getProject(projectId: projectId);
    final response = project.copyWith(
      voiceGlossaryKey: await _voiceGlossaryKey(projectPath: project.path),
    );
    if (!_disposed) {
      _loadedProjectIds.add(response.id);
    }
    return response;
  }

  /// Resolves a key the tracker lacks, so the first load after a bridge start
  /// answers with it instead of leaving that composer without a glossary.
  Future<ProjectGlossaryKey?> _voiceGlossaryKey({required String projectPath}) async {
    final tracked = _projectGlossaryScopeTracker.projectKeyFor(projectPath: projectPath);
    if (tracked != null) return tracked;
    try {
      return (await _projectGlossaryScopeService.resolve(projectPath: projectPath))?.projectKey;
    } on Object catch (error, stackTrace) {
      Log.w("Could not resolve the project glossary key; continuing without it", error, stackTrace);
      return null;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _loadedProjectIds.close();
  }
}
