import "package:sesori_shared/sesori_shared.dart";

import "../repositories/agent_repository.dart";
import "request_handler.dart";

/// Handles `POST /agent` — returns the agents available for the project.
class PostAgentsHandler extends BodyRequestHandler<ProjectIdRequest, Agents> {
  final AgentRepository _repository;

  PostAgentsHandler(this._repository)
    : super(
        HttpMethod.post,
        "/agent",
        fromJson: ProjectIdRequest.fromJson,
      );

  @override
  Future<Agents> handle(
    RelayRequest request, {
    required ProjectIdRequest body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) {
    return _repository.getAgents(projectId: body.projectId, pluginId: body.pluginId);
  }
}
