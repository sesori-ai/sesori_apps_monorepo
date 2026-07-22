// Codex plugin for Sesori Bridge.
//
// Bridges OpenAI Codex CLI (`codex app-server`) to the Sesori BridgePluginApi
// contract, mirroring the OpenCode plugin topology: a request-surface api
// (CodexPlugin) plus a runtime-lifecycle descriptor the bridge registers in
// bin/bridge.dart.
export "src/api/codex_rollout_api.dart";
export "src/approval_registry.dart";
export "src/codex_app_server_client.dart";
export "src/codex_config_reader.dart";
export "src/codex_event_mapper.dart";
export "src/codex_metadata_repository.dart";
export "src/codex_plugin_impl.dart";
export "src/codex_skill_reader.dart";
// Runtime lifecycle: the descriptor is the public entry point the bridge
// registers in bin/bridge.dart.
export "src/runtime/codex_bridge_plugin.dart";
export "src/runtime/codex_managed_api.dart";
export "src/runtime/codex_plugin_descriptor.dart";
export "src/runtime/codex_runtime_manifest.dart";
