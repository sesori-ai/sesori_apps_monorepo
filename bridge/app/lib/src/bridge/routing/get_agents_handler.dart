import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "request_handler.dart";

/// Handles `GET /agent` — returns all available agents from the plugin.
class GetAgentsHandler extends RequestHandler {
  final BridgePlugin _plugin;

  GetAgentsHandler(this._plugin) : super(HttpMethod.get, "/agent");

  @override
  Future<RelayResponse> handle(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    String? fragment,
  }) async {
    final pluginAgents = await _plugin.getAgents();
    final agents = pluginAgents
        .map(
          (a) => AgentInfo(
            name: a.name,
            description: a.description,
            model: switch (a.model) {
              PluginAgentModel(:final modelID, :final providerID) => AgentModel(
                modelID: modelID,
                providerID: providerID,
              ),
              null => null,
            },
            variant: a.variant,
            mode: switch (a.mode) {
              PluginAgentMode.all => AgentMode.all,
              PluginAgentMode.primary => AgentMode.primary,
              PluginAgentMode.subagent => AgentMode.subagent,
              PluginAgentMode.unknown => AgentMode.unknown,
            },
            hidden: a.hidden,
          ),
        )
        .toList();

    return buildOkJsonResponse(request, jsonEncode(agents.map((a) => a.toJson()).toList()));
  }
}
