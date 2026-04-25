import "package:sesori_shared/sesori_shared.dart";

import "../repositories/agent_repository.dart";
import "request_handler.dart";

/// Handles `GET /agent` — returns all available agents from the plugin.
class GetAgentsHandler extends GetRequestHandler<Agents> {
  final AgentRepository _repository;

  GetAgentsHandler(this._repository) : super("/agent");

  @override
  Future<Agents> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    return _repository.getAgents();
  }
}
