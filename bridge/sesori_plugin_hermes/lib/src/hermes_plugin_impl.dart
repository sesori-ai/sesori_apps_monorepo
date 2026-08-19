import "dart:io" show Directory;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "hermes_binary.dart";
import "hermes_identity.dart";

/// Hermes Agent backend over ACP.
///
/// Hermes is a stock ACP v1 server: `hermes acp` advertises load/list/resume/
/// fork/prompt capabilities and streams turns via `session/update`
/// notifications, so the base [AcpPlugin] machinery owns sessions and turns.
/// This class declares Hermes-specific protocol policies, including excluding
/// interactive terminal setup from headless authentication. It surfaces
/// Hermes's configured model through the configuration tracker so the
/// new-session picker shows the active model and lets the user switch via
/// `session/set_model`; it has no managed runtime (Hermes installs itself;
/// the bridge resolves it on PATH).
class HermesPlugin._({
  required super.launchSpec,
  required super.launchDirectory,
  required super.contentMapper,
  required super.eventMapper,
  required super.commandTracker,
  required super.sessionOptionsService,
  required super.processFactory,
  required final AcpSessionConfigurationTracker _configurationTracker,
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
      configurationTracker: configurationTracker,
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
  String? selectAuthMethod({required AcpInitializeResult init}) {
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

  /// Seeds the configuration tracker with Hermes's advertised model catalog
  /// from a `session/new` / `session/load` / `session/fork` result. Hermes
  /// returns a standard ACP `SessionModelState` (`availableModels[]` +
  /// `currentModelId`), which the base parser already materializes into
  /// [AcpNewSessionResult.models]. The default (new-session) model is stored
  /// as the process fallback so [AcpSessionOptionsService] synthesizes a
  /// provider and the picker is no longer empty.
  @override
  void captureSessionConfig(
    AcpNewSessionResult result, {
    String? sessionId,
    bool fromNewSession = false,
  }) {
    final models = result.models;
    if (models == null) {
      return;
    }
    final available = models.availableModels;
    final currentModelId = _usable(models.currentModelId) ??
        (available.isNotEmpty ? available.first.modelId : null);
    if (currentModelId == null && available.isEmpty) {
      return;
    }
    if (fromNewSession) {
      _configurationTracker.setProcessDefaults(
        modelId: currentModelId,
        providerId: currentModelId == null ? null : _providerId(currentModelId),
        availableModels: available.isEmpty ? null : available,
      );
    }
    if (sessionId != null && currentModelId != null) {
      _configurationTracker.setSessionOverride(
        sessionId: sessionId,
        modelId: currentModelId,
        providerId: _providerId(currentModelId),
      );
    }
  }

  /// Applies a user-selected model via Hermes's standard ACP `session/set_model`
  /// before a turn. When no model is requested, uses the session's current
  /// model (a no-op) so the Hermes-configured default is preserved.
  @override
  Future<void> applyTurnSelection({
    required AcpSessionConfigRepository configRepository,
    required String sessionId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) async {
    final requestedModel = model?.modelID;
    final useDefault = requestedModel == null || requestedModel.isEmpty;
    final targetModel = useDefault
        ? _configurationTracker.snapshotForSession(sessionId: sessionId).modelId
        : requestedModel;
    if (targetModel == null || targetModel.isEmpty) {
      return;
    }
    final currentModelId =
        _configurationTracker.snapshotForSession(sessionId: sessionId).modelId;
    if (currentModelId != targetModel) {
      await configRepository.setModel(
        sessionId: sessionId,
        modelId: targetModel,
      );
    }
    _configurationTracker.setSessionOverride(
      sessionId: sessionId,
      modelId: targetModel,
      providerId: _providerId(targetModel),
    );
  }

  static String? _usable(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Splits Hermes's encoded `provider:model` id into its provider segment
  /// (defaulting to the plugin id when there is no separator).
  static String _providerId(String modelId) {
    final separator = modelId.indexOf(":");
    return separator > 0 ? modelId.substring(0, separator) : "hermes";
  }
}
