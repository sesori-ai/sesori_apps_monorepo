import "package:sesori_shared/sesori_shared.dart";

import "../services/project_glossary_service.dart";
import "request_handler.dart";

/// Handles the explicit client signal that hosted voice transcription is being
/// used for this project. Population remains detached and best effort.
class PopulateProjectGlossaryHandler({required final ProjectGlossaryService _projectGlossaryService})
    extends BodyRequestHandler<ProjectIdRequest, PopulateProjectVoiceGlossaryResponse> {
  this : super(HttpMethod.post, "/project/voice-glossary/populate", fromJson: ProjectIdRequest.fromJson);

  @override
  Future<PopulateProjectVoiceGlossaryResponse> handle(
    RelayRequest request, {
    required ProjectIdRequest body,
  }) {
    final projectId = requireNonEmpty(request: request, value: body.projectId, label: "project id");
    final projectKey = _projectGlossaryService.schedule(projectId: projectId);
    if (projectKey == null) {
      throw buildErrorResponse(request, 503, "project voice glossary is unavailable");
    }
    return Future.value(PopulateProjectVoiceGlossaryResponse(projectKey: projectKey));
  }
}
