import "package:codex_plugin/codex_plugin.dart";
import "package:codex_plugin/src/repositories/codex_catalog_repository.dart";
import "package:codex_plugin/src/repositories/codex_message_repository.dart";
import "package:codex_plugin/src/services/codex_session_service.dart";

CodexPlugin createInjectedCodexPlugin({
  required String serverUrl,
  required Map<String, String> environment,
  required String projectCwd,
  required CodexAppServerClient Function() clientFactory,
  required Duration keepaliveInterval,
  Duration rolloutPollInterval = const Duration(milliseconds: 10),
}) {
  final rolloutApi = CodexRolloutApi(environment: environment);
  final catalogRepository = CodexCatalogRepository(rolloutApi: rolloutApi);
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
      catalogRepository: catalogRepository,
      messageRepository: CodexMessageRepository(rolloutApi: rolloutApi),
      metadataRepository: metadataRepository,
      launchDirectory: projectCwd,
    ),
    eventMapper: CodexEventMapper(
      pluginId: CodexPlugin.pluginId,
      projectCwd: projectCwd,
      config: configReader.readDefaults(),
    ),
    rolloutTailer: CodexRolloutTailer(
      rolloutApi: rolloutApi,
      catalogRepository: catalogRepository,
      pollInterval: rolloutPollInterval,
    ),
    projectCwd: projectCwd,
    onConnected: null,
    onDisconnected: null,
    keepaliveInterval: keepaliveInterval,
  );
}
