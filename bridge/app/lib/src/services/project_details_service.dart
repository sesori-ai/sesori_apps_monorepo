import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show Project, ProjectGlossaryScope;

import "../repositories/project_repository.dart";
import "project_glossary_population_service.dart";
import "project_glossary_scope_service.dart";

/// Loads one project with the glossary key voice sends for it, and keeps that
/// glossary up to date in the background.
class ProjectDetailsService({
  required final ProjectRepository _projectRepository,
  required final ProjectGlossaryScopeService _projectGlossaryScopeService,
  required final ProjectGlossaryPopulationService _projectGlossaryPopulationService,
}) {
  Future<Project> getProject({required String projectId}) async {
    final project = await _projectRepository.getProject(projectId: projectId);
    final scope = await _resolveGlossaryScope(projectPath: project.path);
    if (scope != null) {
      unawaited(_projectGlossaryPopulationService.refreshIfDue(scope: scope, projectPath: project.path));
    }
    return project.copyWith(voiceGlossaryKey: scope?.projectKey);
  }

  Future<ProjectGlossaryScope?> _resolveGlossaryScope({required String projectPath}) async {
    try {
      return await _projectGlossaryScopeService.resolve(projectPath: projectPath);
    } on Object catch (error, stackTrace) {
      Log.w("Could not resolve the project glossary key; continuing without it", error, stackTrace);
      return null;
    }
  }
}
