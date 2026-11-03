import "package:codex_plugin/codex_plugin.dart";
import "package:codex_plugin/src/api/codex_tool_outcome_storage.dart";
import "package:codex_plugin/src/repositories/codex_tool_outcome_repository.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "memory_host_json_store.dart";

CodexPlugin createInjectedCodexPlugin({
  required String serverUrl,
  required Map<String, String> environment,
  required String projectCwd,
  required CodexAppServerClient Function()? clientFactory,
  required Duration keepaliveInterval,
  required CodexToolOutcomeRepository toolOutcomeRepository,
}) {
  return buildCodexPlugin(
    serverUrl: serverUrl,
    environment: environment,
    clock: const ServerClock(),
    toolOutcomeRepository: toolOutcomeRepository,
    launchDirectory: projectCwd,
    clientFactory: clientFactory,
    onConnected: null,
    onDisconnected: null,
    keepaliveInterval: keepaliveInterval,
    rolloutPollInterval: const Duration(milliseconds: 10),
  );
}

CodexToolOutcomeRepository createMemoryCodexToolOutcomeRepository() {
  return CodexToolOutcomeRepository(
    storage: CodexToolOutcomeStorage(
      store: MemoryHostJsonStore(),
      clock: const ServerClock(),
    ),
  );
}
