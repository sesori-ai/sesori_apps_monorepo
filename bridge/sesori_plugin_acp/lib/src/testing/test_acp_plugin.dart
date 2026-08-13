import "../acp_plugin.dart";

/// Neutral ACP adapter for testing the reusable base behavior.
class TestAcpPlugin({
    required super.id,
    required super.agentDisplayName,
    required super.launchSpec,
    required super.launchDirectory,
    required super.eventMapper,
    required super.contentMapper,
    required super.commandTracker,
    required super.sessionOptionsService,
    super.processFactory,
  }) extends AcpPlugin {
  @override
  String get clientName => "sesori-bridge";

  @override
  String get clientVersion => "0.0.0";

  @override
  String? get authMethodId => null;

  @override
  Map<String, dynamic>? get initializeCapabilityMeta => null;

  @override
  bool get supportsFormElicitation => false;

  @override
  bool get serializesPromptsProcessWide => false;

  @override
  bool get failsTurnOnSelectionError => false;

  @override
  Duration get sessionCloseSettlementTimeout => const Duration(seconds: 5);
}
