import "package:codex_plugin/codex_plugin.dart";

CodexPlugin createInjectedCodexPlugin({
  required String serverUrl,
  required Map<String, String> environment,
  required String projectCwd,
  required CodexAppServerClient Function() clientFactory,
  required Duration keepaliveInterval,
}) {
  final rolloutApi = CodexRolloutApi(environment: environment);
  final configReader = CodexConfigReader(environment: environment);
  final metadataRepository = CodexMetadataRepository(
    skillReader: CodexSkillReader(environment: environment),
    configReader: configReader,
    launchDirectory: projectCwd,
  );
  return CodexPlugin.injected(
    serverUrl: serverUrl,
    capabilityToken: null,
    clientFactory: clientFactory,
    sessionService: CodexSessionService(
      catalogRepository: CodexCatalogRepository(rolloutApi: rolloutApi),
      messageRepository: CodexMessageRepository(rolloutApi: rolloutApi),
      metadataRepository: metadataRepository,
      launchDirectory: projectCwd,
    ),
    eventMapper: CodexEventMapper(
      pluginId: CodexPlugin.pluginId,
      projectCwd: projectCwd,
      config: configReader.readDefaults(),
    ),
    projectCwd: projectCwd,
    onConnected: null,
    onDisconnected: null,
    keepaliveInterval: keepaliveInterval,
  );
}
