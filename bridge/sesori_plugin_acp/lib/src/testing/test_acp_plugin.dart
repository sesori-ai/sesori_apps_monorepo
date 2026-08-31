import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../acp_plugin.dart";

/// Neutral ACP adapter for testing the reusable base behavior: every policy
/// keeps the [AcpPlugin] stock default.
class TestAcpPlugin({
  required super.id,
  required super.agentDisplayName,
  required super.launchSpec,
  required super.launchDirectory,
  required super.eventMapper,
  required super.commandTracker,
  required super.sessionOptionsService,
  required super.processFactory,
  @override final bool permitsDeviceCanvasHttpMcp = false,
}) extends AcpPlugin {
  Future<void> Function()? validateTurnSelectionHandler;

  @override
  Future<void> validateTurnSelection({
    required String operation,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) async {
    await validateTurnSelectionHandler?.call();
  }
}
