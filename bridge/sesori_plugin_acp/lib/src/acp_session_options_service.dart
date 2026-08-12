import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "acp_command_tracker.dart";
import "acp_session_configuration_tracker.dart";

/// Builds the process-scoped session options exposed by an ACP plugin.
class AcpSessionOptionsService({
  required final AcpSessionConfigurationTracker _configurationTracker,
  required final AcpCommandTracker _commandTracker,
  required final String _pluginId,
  required final String _agentDisplayName,
}) {
  PluginSessionOptions getSessionOptions() {
    final defaults = _configurationTracker.processDefaults;
    final modelId = defaults.modelId;
    final providerId = defaults.providerId ?? _pluginId;
    return PluginSessionOptions(
      agents: [
        PluginAgent(
          name: _pluginId,
          description: "$_agentDisplayName session",
          model: modelId == null
              ? null
              : PluginAgentModel(
                  modelID: modelId,
                  providerID: providerId,
                  variant: null,
                ),
          mode: PluginAgentMode.primary,
          hidden: false,
        ),
      ],
      providers: PluginProvidersResult(
        providers: modelId == null
            ? const []
            : [
                PluginProvider.custom(
                  id: providerId,
                  name: _agentDisplayName,
                  authType: PluginProviderAuthType.unknown,
                  models: [
                    PluginModel(
                      id: modelId,
                      name: modelId,
                      variants: const [],
                      family: null,
                      isAvailable: true,
                      releaseDate: null,
                    ),
                  ],
                  defaultModelID: modelId,
                ),
              ],
      ),
      commands: _commandTracker.commands,
      completeness: _commandTracker.hasSnapshot
          ? PluginSessionOptionsCompleteness.complete
          : PluginSessionOptionsCompleteness.partial,
    );
  }

  void forgetSession({required String sessionId}) {
    _configurationTracker.forgetSession(sessionId: sessionId);
  }
}
