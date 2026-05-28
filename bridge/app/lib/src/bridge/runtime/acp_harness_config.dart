import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginApi;

import "bridge_cli_options.dart";

/// Builds the plugin for an ACP harness from its resolved binary + cwd.
typedef AcpPluginBuilder = BridgePluginApi Function({
  required String binaryPath,
  required String projectCwd,
});

/// Declarative description of an ACP (stdio JSON-RPC) coding-agent backend.
///
/// Adding a new ACP harness is a config row: declare its id, display name,
/// default binary, the CLI flag that overrides the binary, and a plugin
/// builder (for a vanilla harness this is just `AcpPlugin(...)`; quirky ones
/// like Cursor return their own subclass). The bridge resolves the binary and
/// the registry wires the rest.
class AcpHarnessConfig {
  const AcpHarnessConfig({
    required this.id,
    required this.displayName,
    required this.defaultBinary,
    required this.binaryFlag,
    required this.pluginBuilder,
  });

  final String id;
  final String displayName;
  final String defaultBinary;

  /// Reads the binary override for this harness from parsed CLI options
  /// (e.g. `--cursor-bin`).
  final String Function(BridgeCliOptions options) binaryFlag;

  final AcpPluginBuilder pluginBuilder;
}
