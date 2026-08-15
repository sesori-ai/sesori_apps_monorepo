import "dart:io" show Directory;

import "package:acp_plugin/acp_plugin.dart";

import "hermes_binary.dart";
import "hermes_identity.dart";

/// Hermes Agent backend over ACP.
///
/// Hermes is a stock ACP v1 server: `hermes acp` advertises load/list/resume/
/// fork/prompt capabilities and streams turns via `session/update`
/// notifications, so the base [AcpPlugin] machinery owns sessions and turns.
/// This class declares Hermes-specific protocol policies, including excluding
/// interactive terminal setup from headless authentication. Version 1 uses
/// Hermes's configured model/mode rather than exposing a picker, and has no
/// managed runtime (Hermes installs itself; the bridge resolves it on PATH).
class HermesPlugin._({
  required super.launchSpec,
  required super.launchDirectory,
  required super.contentMapper,
  required super.eventMapper,
  required super.commandTracker,
  required super.sessionOptionsService,
  required super.processFactory,
}) extends AcpPlugin {
  factory({
    required String binaryPath,
    required String? launchDirectory,
    required AcpProcessFactory processFactory,
  }) {
    final cwd = launchDirectory ?? Directory.current.path;
    final launchSpec = HermesBinary.launchSpec(
      binary: binaryPath,
      cwd: cwd,
      environment: const {},
    );
    final commandTracker = AcpCommandTracker();
    final configurationTracker = AcpSessionConfigurationTracker();
    const contentMapper = AcpContentMapper();
    final sessionOptionsService = AcpSessionOptionsService(
      configurationTracker: configurationTracker,
      commandTracker: commandTracker,
      pluginId: HermesPluginIdentity.id,
      agentDisplayName: HermesPluginIdentity.displayName,
    );
    final mapper = AcpEventMapper(
      launchDirectory: cwd,
      agentId: HermesPluginIdentity.id,
      pluginId: HermesPluginIdentity.id,
      configurationTracker: configurationTracker,
      contentMapper: contentMapper,
    );
    return HermesPlugin._(
      launchSpec: launchSpec,
      launchDirectory: cwd,
      contentMapper: contentMapper,
      eventMapper: mapper,
      commandTracker: commandTracker,
      sessionOptionsService: sessionOptionsService,
      processFactory: processFactory,
    );
  }

  this
    : super(
        id: HermesPluginIdentity.id,
        agentDisplayName: HermesPluginIdentity.displayName,
      );

  @override
  String get clientName => "sesori-bridge";

  @override
  String get clientVersion => "0.0.0";

  /// Hermes provider method ids are dynamic, so there is no fixed preferred
  /// id. [selectAuthMethod] chooses Hermes's first non-terminal provider.
  @override
  String? get authMethodId => null;

  @override
  String? selectAuthMethod(AcpInitializeResult init) {
    for (final method in init.authMethods) {
      if (method.type != AcpAuthMethodType.terminal) return method.id;
    }
    return null;
  }

  @override
  Map<String, dynamic>? get initializeCapabilityMeta => null;

  /// Hermes has no `elicitation/create`; permissions arrive as
  /// `session/request_permission`, which the base approval registry handles.
  @override
  bool get supportsFormElicitation => false;

  /// Hermes serializes turns per session (one agent loop per session), so
  /// concurrent sessions may prompt in parallel.
  @override
  bool get serializesPromptsProcessWide => false;

  /// No harness-specific turn selection exists (base [applyTurnSelection] is
  /// a no-op), so a selection can never fail a turn.
  @override
  bool get failsTurnOnSelectionError => false;

  @override
  Duration get sessionCloseSettlementTimeout => const Duration(seconds: 5);
}
