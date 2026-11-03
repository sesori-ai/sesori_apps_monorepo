import "package:sesori_shared/sesori_shared.dart";

import "../repositories/agent_repository.dart";
import "request_handler.dart";

/// Handles `POST /agent` — returns the agents available for the project.
class PostAgentsHandler({required final AgentRepository _repository})
    extends BodyRequestHandler<PluginProjectIdRequest, Agents> {
  this
    : super(
        HttpMethod.post,
        // COMPATIBILITY 2026-11-03 (v1.12.0): Apps older than v1.7.1 load agents here; later apps call it only on
        // bridges without /session/options. Remove once public apps older than v1.7.1 are unsupported.
        "/agent",
        fromJson: PluginProjectIdRequest.fromJson,
      );

  @override
  Future<Agents> handle(
    RelayRequest request, {
    required PluginProjectIdRequest body,
  }) {
    return _repository.getAgents(
      projectId: body.projectId,
      pluginId: body.pluginId,
    );
  }
}
