import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../acp_plugin.dart";

/// Neutral ACP adapter for testing the reusable base behavior: every policy
/// keeps the [AcpPlugin] stock default, and the option catalog is empty.
class TestAcpPlugin({
  required super.id,
  required super.agentDisplayName,
  required super.launchSpec,
  required super.launchDirectory,
  required super.eventMapper,
  required super.childSessionTracker,
  required super.commandTracker,
  required super.processFactory,
}) extends AcpPlugin {
  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) async => PluginSessionOptionsDiscoveryResult.observed(
    options: PluginSessionOptions(
      agents: await getAgents(projectId: projectId),
      providers: await getProviders(projectId: projectId),
      commands: await getCommands(projectId: projectId),
      completeness: PluginSessionOptionsCompleteness.complete,
    ),
  );

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async => const [];

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async =>
      const PluginProvidersResult(providers: []);
}
