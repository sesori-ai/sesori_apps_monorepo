import "package:sesori_shared/sesori_shared.dart";

import "../repositories/agent_repository.dart";
import "request_handler.dart";

/// Handles `GET /agent` — returns all available agents from the plugin.
///
/// Carries no project context, so the repository falls back to the bridge
/// CWD as the active project.
@Deprecated("Use POST /agent with a ProjectIdRequest body (PostAgentsHandler)")
class GetAgentsHandler extends GetRequestHandler<Agents> {
  final AgentRepository _repository;

  @Deprecated("Use POST /agent with a ProjectIdRequest body (PostAgentsHandler)")
  GetAgentsHandler(this._repository) : super("/agent");

  @override
  Future<Agents> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    return _repository.getAgents(projectId: null, pluginId: _repository.pluginId);
  }
}
