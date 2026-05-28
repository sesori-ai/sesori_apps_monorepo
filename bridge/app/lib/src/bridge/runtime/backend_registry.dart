import "package:args/args.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginApi;

import "acp_harness_config.dart";
import "bridge_runtime_server.dart" show BridgeServerRuntime;

/// Builds a plugin from a resolved [BridgeServerRuntime].
typedef PluginFromRuntime = BridgePluginApi Function(BridgeServerRuntime runtime);

/// One coding-agent backend. Replaces the old hardcoded `BridgeBackend` enum +
/// factory switch: resolution is selected by [id], plugin construction goes
/// through [createPlugin], and the few backend-specific runtime behaviors are
/// carried as capability flags rather than `== BridgeBackend.x` checks.
class BackendDescriptor {
  const BackendDescriptor({
    required this.id,
    required this.createPlugin,
    this.optimizesOpenCodeDb = false,
    this.ownsProcessShutdown = false,
    this.acp,
  });

  final String id;

  /// Constructs the plugin once the server runtime is resolved.
  final PluginFromRuntime createPlugin;

  /// Whether to run the OpenCode SQLite maintenance pass at startup.
  final bool optimizesOpenCodeDb;

  /// Whether the bridge owns the spawned backend process and must signal it
  /// on shutdown (codex's app-server). ACP harnesses own their own subprocess
  /// inside the plugin, so this is false for them.
  final bool ownsProcessShutdown;

  /// Non-null for ACP stdio harnesses — drives generic binary resolution.
  final AcpHarnessConfig? acp;

  bool get isAcp => acp != null;
}

/// Registry of available backends, keyed by id. Built once at startup.
class BackendRegistry {
  BackendRegistry(List<BackendDescriptor> descriptors)
    : _byId = {for (final d in descriptors) d.id: d};

  final Map<String, BackendDescriptor> _byId;

  /// Backend ids, used for the `--backend` allowed list.
  List<String> get ids => _byId.keys.toList(growable: false);

  BackendDescriptor descriptor(String id) {
    final descriptor = _byId[id];
    if (descriptor == null) {
      throw ArgParserException("unsupported backend: $id");
    }
    return descriptor;
  }
}
