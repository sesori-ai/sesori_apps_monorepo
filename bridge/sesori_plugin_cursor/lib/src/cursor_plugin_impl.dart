import "dart:io" show Directory;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "cursor_approval_registry.dart";
import "cursor_binary.dart";
import "cursor_event_mapper.dart";
import "cursor_model_probe.dart";

/// Cursor backend: drives `cursor-agent acp` over the generic ACP machinery,
/// layering on Cursor's `cursor/*` extensions and its `configOptions` picker.
///
/// With `parameterizedModelPicker: true` (sent at initialize), Cursor exposes:
///  - **mode** (`agent`/`plan`/`ask`) — surfaced as sesori *agents* (stable
///    ACP `value` ids, human label in [PluginAgent.description]; no embedded
///    model so mobile mode switches preserve the user's model/effort)
///  - **model** — surfaced as sesori provider models
///  - **thought_level** (`effort` or `reasoning`, per model) — surfaced as each
///    model's [PluginModel.variants]
///  - **model_config** (`context`, `fast`, …) — not surfaced in the mobile UI yet
///
/// Effort options are learned from real `session/new`/`session/load` captures and
/// from `set_config_option` echoes when the user switches models — never from a
/// throwaway `session/new` probe (ACP agents have no session-delete).
///
/// Selection is (re)applied before every turn via `session/set_config_option` and
/// only when the requested value differs from what was last pushed to the agent
/// process ([_appliedModelId]/[_appliedModeId]/[_appliedThoughtLevelId]).
class CursorPlugin extends AcpPlugin {
  static const String pluginId = "cursor";

  factory CursorPlugin({
    String binaryPath = CursorBinary.defaultBinary,
    String? launchDirectory,
    String? apiEndpoint,
    AcpProcessFactory? processFactory,
  }) {
    final cwd = launchDirectory ?? Directory.current.path;
    return CursorPlugin._(
      launchSpec: CursorBinary.launchSpec(
        binary: binaryPath,
        cwd: cwd,
        apiEndpoint: apiEndpoint,
      ),
      launchDirectory: cwd,
      mapper: CursorEventMapper(launchDirectory: cwd, pluginId: pluginId),
      processFactory: processFactory,
    );
  }

  CursorPlugin._({
    required super.launchSpec,
    required super.launchDirectory,
    required CursorEventMapper mapper,
    super.processFactory,
  }) : super(id: pluginId, agentDisplayName: "Cursor", eventMapper: mapper);

  static const String _providerId = "cursor";

  /// Cached model config: the option id and its `{value, name}` entries.
  String? _modelConfigId;
  List<Map<String, dynamic>> _models = const [];

  /// Cached mode config (Cursor's `agent`/`plan`/`ask`).
  String? _modeConfigId;
  List<Map<String, dynamic>> _modes = const [];
  String? _defaultModeId;

  /// Cached thought-level config (effort/reasoning — id varies per model).
  String? _thoughtLevelConfigId;
  String? _defaultThoughtLevelId;

  /// Per-model effort/reasoning variant lists. A key present with an empty list
  /// means "observed, this model has no thought_level picker".
  final Map<String, List<String>> _effortVariantsByModel = {};

  /// The model a freshly created session defaults to.
  String? _currentModelId;

  /// Last values actually pushed to the agent process (process-global).
  String? _appliedModelId;
  String? _appliedModeId;
  String? _appliedThoughtLevelId;

  @override
  String? get authMethodId => "cursor_login";

  @override
  Map<String, dynamic>? get initializeCapabilityMeta =>
      const {"parameterizedModelPicker": true};

  @override
  AcpApprovalRegistry buildApprovalRegistry(AcpStdioClient client) {
    return CursorApprovalRegistry(
      client: client,
      emit: emitEvent,
      // cursor/create_plan (and some ask_question) requests carry no sessionId;
      // resolve them to the session whose turn is currently in flight.
      activeSessionResolver: () => activeTurnSessionId,
    );
  }

  @override
  void captureSessionConfig(
    Map<String, dynamic> result, {
    String? sessionId,
    bool fromNewSession = false,
  }) {
    _mergeConfigSnapshot(result, fromNewSession: fromNewSession, sessionId: sessionId);
  }

  void _mergeConfigSnapshot(
    Map<String, dynamic> result, {
    required bool fromNewSession,
    String? sessionId,
    String? modelIdForEffort,
  }) {
    final session = AcpNewSessionResult.fromJson(result);

    // The catalog LIST (available models/modes) is account-global, so it is
    // taken from any capture — new or load. But only a `session/new` response
    // ([fromNewSession]) defines the new-session DEFAULT model/mode; a
    // `session/load` (history / resume / catalog probe) replays whatever model
    // that old session used and must not redefine the default.
    final modelConfig = CursorModelProbe.findConfig(session, "model");
    String? loadedModelId;
    if (modelConfig != null) {
      if (modelConfig["id"] case final String id) _modelConfigId = id;
      final models = CursorModelProbe.options(modelConfig);
      if (models.isNotEmpty) _models = models;
      loadedModelId = CursorModelProbe.currentValue(modelConfig);
      if (fromNewSession && loadedModelId != null) _currentModelId = loadedModelId;
    }

    final modeConfig = CursorModelProbe.findConfig(session, "mode");
    if (modeConfig != null) {
      if (modeConfig["id"] case final String id) _modeConfigId = id;
      final modes = CursorModelProbe.options(modeConfig);
      if (modes.isNotEmpty) _modes = modes;
      if (fromNewSession) {
        _defaultModeId = CursorModelProbe.currentValue(modeConfig) ?? _defaultModeId;
      }
    }

    final effortModelId = modelIdForEffort ?? loadedModelId ?? _currentModelId;
    _captureThoughtLevel(session, forModelId: effortModelId, fromNewSession: fromNewSession);

    eventMapper.currentProviderId = _providerId;
    eventMapper.currentModelId = _currentModelId;
    if (sessionId != null && loadedModelId != null) {
      // Only stamp from a snapshot that actually carries a model selection.
      // Effort/mode-only `set_config_option` echoes must not clobber a session's
      // per-turn model with the global default.
      eventMapper.setSessionModel(sessionId, loadedModelId, providerId: _providerId);
    }
  }

  void _captureThoughtLevel(
    AcpNewSessionResult session, {
    required String? forModelId,
    required bool fromNewSession,
  }) {
    final thoughtConfig = CursorModelProbe.findThoughtLevelConfig(session);
    if (thoughtConfig == null) {
      return;
    }

    if (thoughtConfig["id"] case final String id) _thoughtLevelConfigId = id;
    final variants = _thoughtLevelVariants(thoughtConfig);
    if (fromNewSession) {
      _defaultThoughtLevelId =
          CursorModelProbe.currentValue(thoughtConfig) ?? _defaultThoughtLevelId;
    }
    if (forModelId != null && forModelId.isNotEmpty) {
      _effortVariantsByModel[forModelId] = variants;
    }
    // Provisionally fill sibling models so the first getProviders is effort-
    // complete before per-model set_config echoes refine option sets.
    // putIfAbsent keeps a real per-model result once written.
    for (final model in _models) {
      final value = model["value"];
      if (value is String && value.isNotEmpty) {
        _effortVariantsByModel.putIfAbsent(value, () => List<String>.of(variants));
      }
    }
  }

  List<String> _thoughtLevelVariants(Map<String, dynamic> thoughtConfig) {
    final ids = <String>[
      for (final option in CursorModelProbe.options(thoughtConfig))
        if (option["value"] case final String value when value.isNotEmpty) value,
    ];
    final defaultLevel = CursorModelProbe.currentValue(thoughtConfig);
    if (defaultLevel != null && ids.remove(defaultLevel)) {
      ids.insert(0, defaultLevel);
    }
    return ids;
  }

  List<String> _effortVariantsForModel(String modelId) =>
      _effortVariantsByModel[modelId] ?? const [];

  @override
  Future<void> applyTurnSelection({
    required AcpStdioClient client,
    required String sessionId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) async {
    final requestedModel = model?.modelID;
    final useDefault = requestedModel == null || requestedModel.isEmpty;
    // A null/empty model falls back to the session's OWN last-known model, not
    // the process-global default, so interleaved sessions don't inherit each
    // other's implicit model.
    final targetModel =
        useDefault ? eventMapper.modelForSession(sessionId) : requestedModel;
    if (targetModel != null &&
        targetModel.isNotEmpty &&
        _modelConfigId != null &&
        CursorModelProbe.hasOption(_models, targetModel)) {
      var applied = true;
      if (targetModel != _appliedModelId) {
        applied = await _setConfig(client, sessionId, _modelConfigId!, targetModel);
        if (applied) {
          _appliedModelId = targetModel;
          // thought_level is per-model: the same "high" on a new model must be
          // re-pushed even when the variant string is unchanged.
          _appliedThoughtLevelId = null;
        }
      }
      if (applied) {
        eventMapper.setSessionModel(sessionId, targetModel, providerId: _providerId);
      }
      // On rejection leave this session's model untouched — don't stamp the
      // rejected value or inherit another session's applied model.
    } else {
      eventMapper.setSessionModel(sessionId, _currentModelId, providerId: _providerId);
    }

    final requestedMode = CursorModelProbe.resolveModeId(_modes, agent) ?? _defaultModeId;
    if (requestedMode != null &&
        _modeConfigId != null &&
        CursorModelProbe.hasOption(_modes, requestedMode) &&
        requestedMode != _appliedModeId) {
      if (await _setConfig(client, sessionId, _modeConfigId!, requestedMode)) {
        _appliedModeId = requestedMode;
      }
    }

    final requestedEffort = (variant != null && variant.id.isNotEmpty)
        ? variant.id
        : _defaultThoughtLevelId;
    // Effort options are per-model. Use the model actually stamped on this
    // session (after the model-selection block above), not a rejected/unknown
    // requested id that has no catalog entry.
    final effortModelId =
        eventMapper.modelForSession(sessionId) ?? _currentModelId ?? "";
    final effortOptions = _effortVariantsForModel(effortModelId);
    if (requestedEffort != null &&
        _thoughtLevelConfigId != null &&
        requestedEffort != _appliedThoughtLevelId &&
        effortOptions.isNotEmpty &&
        effortOptions.contains(requestedEffort)) {
      if (await _setConfig(client, sessionId, _thoughtLevelConfigId!, requestedEffort)) {
        _appliedThoughtLevelId = requestedEffort;
      }
    }
  }

  @override
  void onConnectionReset() {
    // Cursor's set_config_option is process-global; a freshly respawned agent
    // has applied neither model nor mode nor effort. Drop the applied-cache so
    // the next turn re-pushes the selection. The effort *catalog* is learned
    // from live captures and stays valid across process respawns (account
    // switches dispose the plugin entirely).
    _appliedModelId = null;
    _appliedModeId = null;
    _appliedThoughtLevelId = null;
  }

  /// Issues a `session/set_config_option`, returning whether it succeeded.
  /// Fail-soft: a rejected selection keeps the agent's current value rather
  /// than failing the turn. Successful responses refresh the catalog (effort
  /// options change when the model changes).
  Future<bool> _setConfig(
    AcpStdioClient client,
    String sessionId,
    String configId,
    String value,
  ) async {
    try {
      final raw = await client.request(
        method: AcpMethods.sessionSetConfigOption,
        params: {"sessionId": sessionId, "configId": configId, "value": value},
      );
      if (raw is Map) {
        _mergeConfigSnapshot(
          raw.cast<String, dynamic>(),
          fromNewSession: false,
          sessionId: sessionId,
          modelIdForEffort: configId == _modelConfigId ? value : null,
        );
      }
      return true;
    } catch (error, stack) {
      Log.w("[cursor] set_config_option($configId=$value) rejected", error, stack);
      return false;
    }
  }

  Future<void> _ensureCatalog({String? projectId}) async {
    // Both dimensions must be present before the catalog is "ready". A probe (or
    // an early capture) can populate models without modes — returning after
    // models alone would strand the agent picker empty while the model picker
    // works.
    if (_models.isNotEmpty && _modes.isNotEmpty) return;
    if (!await ensureConnected()) return;
    await probeCatalogFromExistingSession(
      extraDirectories: {if (projectId != null && projectId.trim().isNotEmpty) projectId},
    );
  }

  /// Ensures every known model has an effort-variant entry (possibly empty)
  /// without creating throwaway Cursor sessions. Uses provisional sibling
  /// copies from real captures; per-model sets refine via set_config echoes.
  void _ensureEffortCatalogEntries() {
    if (_models.isEmpty) return;
    if (_thoughtLevelConfigId == null) {
      for (final model in _models) {
        final value = model["value"];
        if (value is String && value.isNotEmpty) {
          _effortVariantsByModel.putIfAbsent(value, () => const []);
        }
      }
      return;
    }
    for (final model in _models) {
      final value = model["value"];
      if (value is String && value.isNotEmpty) {
        _effortVariantsByModel.putIfAbsent(value, () => const []);
      }
    }
  }

  /// Eagerly populates models/modes from an existing session so the first
  /// mobile providers fetch is complete. Does not create throwaway sessions.
  Future<void> warmCatalog() async {
    try {
      await _ensureCatalog();
      _ensureEffortCatalogEntries();
    } on Object catch (error, stack) {
      Log.d("[cursor] warmCatalog failed (will populate lazily): $error\n$stack");
    }
  }

  /// The first model with a usable String `value`, or null.
  String? _firstModelValue() {
    for (final model in _models) {
      if (model["value"] case final String value when value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  /// Cursor modes as sesori agents. Uses the stable ACP `value` as [PluginAgent.name]
  /// (what mobile persists/sends back) and the human `name` as description.
  /// [PluginAgent.model] is intentionally null so a mode switch does not wipe
  /// the user's selected model/effort on the client.
  List<PluginAgent> _modeAgents() {
    if (_modes.isEmpty) {
      return [
        const PluginAgent(
          name: "cursor",
          description: "Cursor CLI session",
          model: null,
          mode: PluginAgentMode.primary,
          hidden: false,
        ),
      ];
    }

    final ordered = <Map<String, dynamic>>[
      for (final mode in _modes)
        if (mode["value"] case final String value when value.isNotEmpty) mode,
    ];
    final defaultMode = _defaultModeId;
    if (defaultMode != null) {
      ordered.sort((a, b) {
        final av = a["value"];
        final bv = b["value"];
        if (av == defaultMode) return -1;
        if (bv == defaultMode) return 1;
        return 0;
      });
    }

    return [
      for (final mode in ordered)
        PluginAgent(
          name: mode["value"] as String,
          description: switch (mode["name"]) {
            final String name when name.isNotEmpty => name,
            _ => null,
          },
          model: null,
          mode: PluginAgentMode.primary,
          hidden: false,
        ),
    ];
  }

  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) async {
    await _ensureCatalog(projectId: projectId);
    return _modeAgents();
  }

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async {
    await _ensureCatalog(projectId: projectId);
    // Fill any missing effort entries from provisional sibling copies so the
    // mobile provider cache is effort-complete on first fetch.
    _ensureEffortCatalogEntries();
    if (_models.isEmpty) return const PluginProvidersResult(providers: []);
    return PluginProvidersResult(
      providers: [
        PluginProvider.custom(
          id: _providerId,
          name: "Cursor",
          authType: PluginProviderAuthType.unknown,
          models: [
            // Parse defensively: a malformed/changed agent payload (a non-string
            // value/name) must not crash the whole provider listing.
            for (final model in _models)
              if (model["value"] case final String value when value.isNotEmpty)
                PluginModel(
                  id: value,
                  name: switch (model["name"]) {
                    final String name when name.isNotEmpty => name,
                    _ => value,
                  },
                  variants: _effortVariantsForModel(value),
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
