import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:deepseek_plugin/deepseek_testing.dart";

DeepSeekPlugin buildDeepSeekTestPlugin({required FakeAcpProcess fake}) {
  final configurationTracker = AcpSessionConfigurationTracker();
  final commandTracker = AcpCommandTracker();
  final childSessionTracker = AcpChildSessionTracker();
  const api = DeepSeekAcpApi(pluginId: DeepSeekIdentity.id);
  final mapper = DeepSeekEventMapper(
    launchDirectory: "/repo",
    pluginId: DeepSeekIdentity.id,
    configurationTracker: configurationTracker,
    childSessions: childSessionTracker,
    api: api,
    messageTimeParser: const DeepSeekMessageTimeParser(),
    subagentMapper: const DeepSeekSubagentMapper(agentId: DeepSeekIdentity.id),
    delegationTracker: DeepSeekDelegationTracker(),
  );
  return DeepSeekPlugin(
    launchSpec: const AcpLaunchSpec(
      includeParentEnvironment: true,
      command: "deepseek",
      args: [],
      cwd: "/repo",
      environment: {},
    ),
    launchDirectory: "/repo",
    childSessionTracker: childSessionTracker,
    mapper: mapper,
    api: api,
    historyRepository: DeepSeekHistoryRepository(
      api: api,
      eventMapper: mapper,
      pluginId: DeepSeekIdentity.id,
      messageTimeParser: const DeepSeekMessageTimeParser(),
      subagentMapper: const DeepSeekSubagentMapper(agentId: DeepSeekIdentity.id),
    ),
    deepSeekSessionService: DeepSeekSessionService(
      repository: const DeepSeekSessionRepository(api: api),
      childSessions: childSessionTracker,
    ),
    deepSeekSessionOptionsService: DeepSeekSessionOptionsService(
      repository: const DeepSeekCatalogRepository(api: api, mapper: DeepSeekCatalogMapper()),
      configurationTracker: configurationTracker,
      pluginId: DeepSeekIdentity.id,
      discoveryTimeout: const Duration(seconds: 30),
    ),
    commandTracker: commandTracker,
    sessionOptionsService: AcpSessionOptionsService(
      configurationTracker: configurationTracker,
      commandTracker: commandTracker,
      pluginId: DeepSeekIdentity.id,
      agentDisplayName: DeepSeekIdentity.displayName,
    ),
    processFactory: (_) async => fake,
  );
}
