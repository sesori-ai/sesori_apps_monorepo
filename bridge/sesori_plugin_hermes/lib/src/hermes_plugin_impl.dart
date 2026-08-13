import "dart:io" show Directory;

import "package:acp_plugin/acp_plugin.dart";

import "hermes_binary.dart";
import "hermes_identity.dart";

/// Hermes Agent backend over ACP.
///
/// Hermes is a stock ACP v1 server: `hermes acp` advertises load/list/resume/
/// fork/prompt capabilities and streams turns via `session/update`
/// notifications, so the base [AcpPlugin] machinery applies unchanged — this
/// class only declares the harness's protocol policies. There are no
/// `hermes/*` extensions, no config-option model picker, and no managed
/// runtime (Hermes installs itself; the bridge resolves it on PATH).
class HermesPlugin._({
  required super.launchSpec,
  required super.launchDirectory,
  required super.contentMapper,
  required super.eventMapper,
  required super.commandTracker,
  required super.sessionOptionsService,
  super.processFactory,
}) extends AcpPlugin {
  factory({
    String binaryPath = HermesBinary.defaultBinary,
    String? launchDirectory,
    AcpProcessFactory? processFactory,
  }) {
    final cwd = launchDirectory ?? Directory.current.path;
    final launchSpec = HermesBinary.launchSpec(
      binary: binaryPath,
      cwd: cwd,
    );
    final commandTracker = AcpCommandTracker();
    final configurationTracker = AcpSessionConfigurationTracker();
    const contentMapper = AcpContentMapper();
    final sessionOptionsService = AcpSessionOptionsService(
      configurationTracker: configurationTracker,
      commandTracker: commandTracker,
      pluginId: HermesIdentity.pluginId,
      agentDisplayName: HermesIdentity.displayName,
    );
    final mapper = AcpEventMapper(
      launchDirectory: cwd,
      agentId: HermesIdentity.pluginId,
      pluginId: HermesIdentity.pluginId,
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
        id: HermesIdentity.pluginId,
        agentDisplayName: HermesIdentity.displayName,
      );

  @override
  String get clientName => HermesIdentity.clientName;

  @override
  String get clientVersion => HermesIdentity.clientVersion;

  /// Hermes advertises a provider auth method plus a terminal-setup method;
  /// the first advertised method is the configured provider, which is what we
  /// want to authenticate against. `null` picks it.
  @override
  String? get authMethodId => null;

  @override
  Map<String, dynamic>? get initializeCapabilityMeta => null;

  /// Hermes has no `elicitation/create` — permissions arrive as
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
