import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart" show ErrorResponse, SuccessResponse;

import "../logging/logging.dart";
import "../repositories/project_repository.dart";

/// Owns the best-effort bridge request that prepares hosted voice glossary
/// context after a user explicitly starts recording for a project.
@lazySingleton
class ProjectVoiceGlossaryService({required final ProjectRepository _projectRepository}) {
  Future<void> requestPopulation({required String projectId}) async {
    try {
      switch (await _projectRepository.populateVoiceGlossary(projectId: projectId)) {
        case SuccessResponse():
          return;
        case ErrorResponse(:final error):
          logw("Could not request project voice glossary population", error);
      }
    } on Object catch (error, stackTrace) {
      logw("Could not request project voice glossary population", error, stackTrace);
    }
  }
}
