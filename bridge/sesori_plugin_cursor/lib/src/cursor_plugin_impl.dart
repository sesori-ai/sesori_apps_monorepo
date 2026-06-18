import "dart:io" show Directory;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "cursor_approval_registry.dart";
import "cursor_binary.dart";
import "cursor_event_mapper.dart";
import "cursor_model_probe.dart";

/// Cursor backend: drives `cursor-agent acp` over the generic ACP machinery,
/// layering on Cursor's `cursor/*` extensions and its `configOptions` picker
/// (model + mode + fast).
///
/// Selection model:
///  - **Model** maps onto the `model` config option (`session/set_config_option
///    {configId, value}`).
///  - **Mode** (`agent`/`plan`/`ask`) is the sesori "variant": Cursor has no
///    reasoning-effort knob, and the mode is the per-session "how the agent
///    works" control, so it is exposed as each model's [PluginModel.variants]
///    and driven by the same `set_config_option` call.
///
/// Cursor's `set_config_option` is honoured per `session/prompt` and *persists*
/// across turns, but a model/mode set leaks to other sessions in the same
/// agent process (it tracks a process-wide "current" selection). So selection
/// is (re)applied before every turn and only when the requested value differs
/// from what was last pushed to the agent ([_appliedModelId]/[_appliedModeId]),
/// which both avoids redundant calls and self-corrects interleaved sessions.
class CursorPlugin extends AcpPlugin {
  factory CursorPlugin({
    String binaryPath = CursorBinary.defaultBinary,
    String? projectCwd,
    String? apiEndpoint,
    AcpProcessFactory? processFactory,
    HostJsonStore? projectStore,
  }) {
    final cwd = projectCwd ?? Directory.current.path;
    return CursorPlugin._(
      launchSpec: CursorBinary.launchSpec(
        binary: binaryPath,
        cwd: cwd,
        apiEndpoint: apiEndpoint,
      ),
      projectCwd: cwd,
      mapper: CursorEventMapper(projectCwd: cwd),
      processFactory: processFactory,
      projectStore: projectStore,
    );
  }

  CursorPlugin._({
    required super.launchSpec,
    required super.projectCwd,
    required CursorEventMapper mapper,
    super.processFactory,
    super.projectStore,
  }) : super(id: "cursor", agentDisplayName: "Cursor", eventMapper: mapper);

  static const String _providerId = "cursor";

  /// Cached model config: the option id and its `{value, name}` entries.
  String? _modelConfigId;
  List<Map<String, dynamic>> _models = const [];

  /// Cached mode config (Cursor's `agent`/`plan`/`ask`).
  String? _modeConfigId;
  List<Map<String, dynamic>> _modes = const [];
  String? _defaultModeId;

  /// The model a freshly created session defaults to (used for `defaultModelID`
  /// and as the fallback stamp when no model is explicitly selected).
  String? _currentModelId;

  /// Last model/mode actually pushed to the agent process (process-global, see
  /// the class doc) — guards against redundant `set_config_option` calls.
  String? _appliedModelId;
  String? _appliedModeId;

  @override
  String? get authMethodId => "cursor_login";

  @override
  Map<String, dynamic>? get initializeCapabilityMeta =>
      const {"parameterizedModelPicker": true};

  @override
  AcpApprovalRegistry buildApprovalRegistry(AcpStdioClient client) {
    return CursorApprovalRegistry(client: client, emit: emitEvent);
  }

  @override
  void captureSessionConfig(Map<String, dynamic> result, {String? sessionId}) {
    final session = AcpNewSessionResult.fromJson(result);

    final modelConfig = CursorModelProbe.findConfig(session, "model");
    if (modelConfig != null) {
      _modelConfigId = modelConfig["id"] as String? ?? _modelConfigId;
      final models = CursorModelProbe.options(modelConfig);
      if (models.isNotEmpty) _models = models;
      _currentModelId = CursorModelProbe.currentValue(modelConfig) ?? _currentModelId;
    }

    final modeConfig = CursorModelProbe.findConfig(session, "mode");
    if (modeConfig != null) {
      _modeConfigId = modeConfig["id"] as String? ?? _modeConfigId;
      final modes = CursorModelProbe.options(modeConfig);
      if (modes.isNotEmpty) _modes = modes;
      _defaultModeId = CursorModelProbe.currentValue(modeConfig) ?? _defaultModeId;
    }

    eventMapper.currentProviderId = _providerId;
    eventMapper.currentModelId = _currentModelId;
    if (sessionId != null) {
      eventMapper.setSessionModel(sessionId, _currentModelId, providerId: _providerId);
    }
  }

  @override
  Future<void> applyTurnSelection({
    required AcpStdioClient client,
    required String sessionId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
  }) async {
    // Model selection. Cursor's selection is process-global, so even a turn that
    // uses the *default* model must push it when it differs from what was last
    // applied — otherwise the turn silently runs on whatever model another
    // session left selected while we stamp it as the default. A null/empty model
    // means "use the default" (_currentModelId); an explicit-but-unknown model
    // stays fail-soft (the agent keeps its current value, see [_setConfig]).
    final requestedModel = model?.modelID;
    final useDefault = requestedModel == null || requestedModel.isEmpty;
    final targetModel = useDefault ? _currentModelId : requestedModel;
    if (targetModel != null &&
        targetModel.isNotEmpty &&
        _modelConfigId != null &&
        CursorModelProbe.hasOption(_models, targetModel)) {
      if (targetModel != _appliedModelId) {
        if (await _setConfig(client, sessionId, _modelConfigId!, targetModel)) {
          _appliedModelId = targetModel;
        }
      }
      eventMapper.setSessionModel(sessionId, targetModel, providerId: _providerId);
    } else {
      // Unknown explicit model (fail-soft) or no default resolved yet — stamp
      // messages with the session's default.
      eventMapper.setSessionModel(sessionId, _currentModelId, providerId: _providerId);
    }

    // Mode selection (the sesori "variant"). A null/empty variant uses the
    // agent's default mode so "Default" is deterministic.
    final requestedMode = (variant != null && variant.id.isNotEmpty)
        ? variant.id
        : _defaultModeId;
    if (requestedMode != null &&
        _modeConfigId != null &&
        CursorModelProbe.hasOption(_modes, requestedMode) &&
        requestedMode != _appliedModeId) {
      if (await _setConfig(client, sessionId, _modeConfigId!, requestedMode)) {
        _appliedModeId = requestedMode;
      }
    }
  }

  /// Issues a `session/set_config_option`, returning whether it succeeded.
  /// Fail-soft: a rejected selection keeps the agent's current value rather
  /// than failing the turn.
  Future<bool> _setConfig(
    AcpStdioClient client,
    String sessionId,
    String configId,
    String value,
  ) async {
    try {
      await client.request(
        method: AcpMethods.sessionSetConfigOption,
        params: {"sessionId": sessionId, "configId": configId, "value": value},
      );
      return true;
    } catch (error, stack) {
      Log.w("[cursor] set_config_option($configId=$value) rejected", error, stack);
      return false;
    }
  }

  /// Loads the catalog from an existing session if it has not been captured yet
  /// this connection (so the new-session model picker is populated even before
  /// any session is created this run).
  Future<void> _ensureCatalog() async {
    if (_models.isNotEmpty) return;
    if (!await ensureConnected()) return;
    await probeCatalogFromExistingSession();
  }

  /// Eagerly populates the catalog right after the bridge connects, so the
  /// FIRST `getProviders`/`getAgents` the mobile issues already returns the full
  /// model list. The mobile caches that first providers result, so an initially
  /// empty list would otherwise leave the model/variant pickers blank until the
  /// app refetches. Best-effort and bounded; never throws. Call after the ACP
  /// connection is established (the descriptor does, post-`connect`).
  Future<void> warmCatalog() async {
    try {
      await _ensureCatalog();
    } on Object catch (error, stack) {
      Log.d("[cursor] warmCatalog failed (will populate lazily): $error\n$stack");
    }
  }

  /// The first model with a usable String `value`, or null. Used as the
  /// default-model fallback so a malformed agent payload (a non-string value on
  /// the first entry) cannot crash [getProviders].
  String? _firstModelValue() {
    for (final model in _models) {
      if (model["value"] case final String value when value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  /// Cursor's modes as sesori variant ids, default mode first (the mobile
  /// picker auto-selects the first on a model switch).
  List<String> _modeVariants() {
    final ids = <String>[
      for (final mode in _modes)
        if (mode["value"] case final String value when value.isNotEmpty) value,
    ];
    final defaultMode = _defaultModeId;
    if (defaultMode != null && ids.remove(defaultMode)) ids.insert(0, defaultMode);
    return ids;
  }

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async {
    await _ensureCatalog();
    final modelId = eventMapper.currentModelId ?? _currentModelId;
    return [
      PluginAgent(
        name: "cursor",
        description: "Cursor CLI session",
        model: modelId == null
            ? null
            : PluginAgentModel(
                modelID: modelId,
                providerID: _providerId,
                variant: null,
              ),
        mode: PluginAgentMode.primary,
        hidden: false,
      ),
    ];
  }

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async {
    await _ensureCatalog();
    if (_models.isEmpty) return const PluginProvidersResult(providers: []);
    final variants = _modeVariants();
    return PluginProvidersResult(
      providers: [
        PluginProvider.custom(
          id: _providerId,
          name: "Cursor",
          authType: PluginProviderAuthType.unknown,
          models: [
            // Parse defensively: a malformed/changed agent payload (a non-string
            // value/name) must not crash the whole provider listing. Skip an
            // entry without a usable value, mirroring [_modeVariants].
            for (final model in _models)
              if (model["value"] case final String value when value.isNotEmpty)
                PluginModel(
                  id: value,
                  name: model["name"] is String && (model["name"] as String).isNotEmpty
                      ? model["name"] as String
                      : value,
                  variants: variants,
                  family: null,
                  isAvailable: true,
                  releaseDate: null,
                ),
          ],
          defaultModelID: _currentModelId ?? _firstModelValue(),
        ),
      ],
    );
  }
}
