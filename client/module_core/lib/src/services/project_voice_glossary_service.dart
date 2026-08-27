import "package:injectable/injectable.dart";

import "../logging/logging.dart";
import "../repositories/models/project_voice_glossary_population_result.dart";
import "../repositories/project_repository.dart";

/// Owns the best-effort bridge request that prepares hosted voice glossary
/// context after a user explicitly starts recording for a project.
@lazySingleton
class ProjectVoiceGlossaryService({required final ProjectRepository _projectRepository}) {
  /// Returns the bridge-derived opaque key when the local capability responds.
  /// Failures remain best effort so neither recording nor transcription waits
  /// for glossary preparation.
  Future<String?> requestPopulation({required String projectId}) async {
    try {
      return switch (await _projectRepository.populateVoiceGlossary(projectId: projectId)) {
        ProjectVoiceGlossaryPopulationAvailable(:final projectKey) => projectKey,
        ProjectVoiceGlossaryPopulationUnavailable(:final error) => _logFailure(error: error),
      };
    } on Object catch (error, stackTrace) {
      logw("Could not request project voice glossary population", error, stackTrace);
      return null;
    }
  }

  String? _logFailure({required Object error}) {
    logw("Could not request project voice glossary population", error);
    return null;
  }
}
