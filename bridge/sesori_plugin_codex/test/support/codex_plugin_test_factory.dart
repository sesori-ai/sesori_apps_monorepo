import "dart:async";

import "package:codex_plugin/codex_plugin.dart";
import "package:codex_plugin/src/api/codex_tool_outcome_storage.dart";
import "package:codex_plugin/src/api/parsers/codex_command_execution_parser.dart";
import "package:codex_plugin/src/api/parsers/codex_file_change_parser.dart";
import "package:codex_plugin/src/api/parsers/codex_image_bearing_item_parser.dart";
import "package:codex_plugin/src/api/parsers/codex_sub_agent_item_parser.dart";
import "package:codex_plugin/src/repositories/codex_catalog_repository.dart";
import "package:codex_plugin/src/repositories/codex_message_repository.dart";
import "package:codex_plugin/src/repositories/codex_sub_agent_tracker.dart";
import "package:codex_plugin/src/repositories/codex_tool_lifecycle_tracker.dart";
import "package:codex_plugin/src/repositories/codex_tool_outcome_repository.dart";
import "package:codex_plugin/src/repositories/mappers/codex_image_attachment_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_session_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_user_content_mapper.dart";
import "package:codex_plugin/src/services/codex_session_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

CodexPlugin createInjectedCodexPlugin({
  required String serverUrl,
  required Map<String, String> environment,
  required String projectCwd,
  required CodexAppServerClient Function()? clientFactory,
  required Duration keepaliveInterval,
  CodexToolOutcomeRepository? toolOutcomeRepository,
  Duration rolloutPollInterval = const Duration(milliseconds: 10),
}) {
  final rolloutApi = CodexRolloutApi(environment: environment);
  const imageAttachmentMapper = CodexImageAttachmentMapper();
  const rolloutToolMapper = CodexRolloutToolMapper(
    imageAttachmentMapper: imageAttachmentMapper,
  );
  const imageBearingItemParser = CodexImageBearingItemParser();
  const userContentMapper = CodexUserContentMapper();
  final catalogRepository = CodexCatalogRepository(rolloutApi: rolloutApi);
  final configReader = CodexConfigReader(environment: environment);
  final metadataRepository = CodexMetadataRepository(
    configReader: configReader,
  );
  final resolvedToolOutcomeRepository = toolOutcomeRepository ?? createMemoryCodexToolOutcomeRepository();
  return CodexPlugin.composed(
    serverUrl: serverUrl,
    capabilityToken: null,
    clientFactory: clientFactory,
    sessionService: CodexSessionService(
      catalogRepository: catalogRepository,
      messageRepository: CodexMessageRepository(
        rolloutApi: rolloutApi,
        rolloutToolMapper: rolloutToolMapper,
        userContentMapper: userContentMapper,
      ),
      metadataRepository: metadataRepository,
      toolOutcomeRepository: resolvedToolOutcomeRepository,
      subAgentTracker: CodexSubAgentTracker(),
      sessionMapper: const CodexSessionMapper(),
      launchDirectory: projectCwd,
    ),
    eventMapper: CodexEventMapper(
      pluginId: CodexPlugin.pluginId,
      projectCwd: projectCwd,
      imageAttachmentMapper: imageAttachmentMapper,
      imageBearingItemParser: imageBearingItemParser,
      rolloutToolMapper: rolloutToolMapper,
      userContentMapper: userContentMapper,
      config: configReader.readDefaults(),
    ),
    rolloutTailer: CodexRolloutTailer(
      rolloutApi: rolloutApi,
      catalogRepository: catalogRepository,
      pollInterval: rolloutPollInterval,
    ),
    toolLifecycleTracker: CodexToolLifecycleTracker(
      rolloutToolMapper: rolloutToolMapper,
    ),
    toolOutcomeRepository: resolvedToolOutcomeRepository,
    commandExecutionParser: const CodexCommandExecutionParser(),
    fileChangeParser: const CodexFileChangeParser(),
    imageBearingItemParser: imageBearingItemParser,
    subAgentItemParser: const CodexSubAgentItemParser(),
    projectCwd: projectCwd,
    onConnected: null,
    onDisconnected: null,
    keepaliveInterval: keepaliveInterval,
  );
}

CodexToolOutcomeRepository createMemoryCodexToolOutcomeRepository() {
  return CodexToolOutcomeRepository(
    storage: CodexToolOutcomeStorage(
      store: _MemoryHostJsonStore(),
      clock: const ServerClock(),
    ),
  );
}

class _MemoryHostJsonStore() implements HostJsonStore {
  final Map<String, String> _files = {};

  @override
  Future<String?> read({required String name}) async => _files[name];

  @override
  Future<void> write({required String name, required String contents}) async {
    _files[name] = contents;
  }

  @override
  Future<void> delete({required String name}) async {
    _files.remove(name);
  }

  @override
  Future<void> quarantine({
    required String name,
    required String quarantinedName,
  }) async {
    final contents = _files.remove(name);
    if (contents != null) _files[quarantinedName] = contents;
  }

  @override
  Future<String?> update({
    required String name,
    required FutureOr<String?> Function(String? current) transform,
  }) async {
    final contents = await transform(_files[name]);
    if (contents == null) {
      _files.remove(name);
    } else {
      _files[name] = contents;
    }
    return contents;
  }
}
