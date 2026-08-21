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
  super.processFactory,
}) extends AcpPlugin;
