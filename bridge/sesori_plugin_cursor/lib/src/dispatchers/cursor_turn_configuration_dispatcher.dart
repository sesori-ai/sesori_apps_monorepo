import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../cursor_event_mapper.dart";
import "../models/cursor_catalog_models.dart";
import "../services/cursor_catalog_service.dart";
import "../trackers/cursor_catalog_tracker.dart";

/// Owns Cursor's process-global config selection cache and session captures.
class CursorTurnConfigurationDispatcher extends AcpTurnConfigurationDispatcher {
  CursorTurnConfigurationDispatcher({
    required CursorCatalogService catalogService,
    required CursorCatalogTracker catalogTracker,
    required CursorEventMapper eventMapper,
    required String providerId,
  }) : _catalogService = catalogService,
       _catalogTracker = catalogTracker,
       _eventMapper = eventMapper,
       _providerId = providerId;

  final CursorCatalogService _catalogService;
  final CursorCatalogTracker _catalogTracker;
  final CursorEventMapper _eventMapper;
  final String _providerId;

  String? _appliedModelId;
  String? _appliedModeId;
  String? _appliedThoughtLevelId;

  @override
  void captureSessionConfig(
    AcpNewSessionResult result, {
    required String? sessionId,
    required bool fromNewSession,
  }) {
    final capture = _catalogService.captureSessionConfig(
      result: result,
      fromNewSession: fromNewSession,
      thoughtLevelModelId: null,
      captureThoughtLevelDefault: fromNewSession,
    );
    _applyCaptureToEventMapper(capture: capture, sessionId: sessionId);
  }

  @override
  Future<void> apply({
    required AcpSessionRepository repository,
    required String sessionId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
    required bool failOnError,
  }) async {
    final requestedModel = model?.modelID;
    final useDefault = requestedModel == null || requestedModel.isEmpty;
    final targetModel = useDefault ? _eventMapper.modelForSession(sessionId) : requestedModel;
    final modelConfigId = _catalogTracker.modelConfigId;
    if (targetModel != null &&
        targetModel.isNotEmpty &&
        modelConfigId != null &&
        _catalogTracker.hasModel(modelId: targetModel)) {
      var applied = true;
      if (targetModel != _appliedModelId) {
        applied = await _setConfig(
          repository: repository,
          sessionId: sessionId,
          configId: modelConfigId,
          value: targetModel,
          failOnError: failOnError,
        );
        if (applied) {
          _appliedModelId = targetModel;
          _appliedThoughtLevelId = null;
        }
      }
      if (applied) {
        _eventMapper.setSessionModel(
          sessionId,
          targetModel,
          providerId: _providerId,
        );
      }
    }

    final requestedMode = _catalogTracker.resolveModeId(agent: agent) ?? _catalogTracker.defaultModeId;
    final modeConfigId = _catalogTracker.modeConfigId;
    if (requestedMode != null &&
        modeConfigId != null &&
        _catalogTracker.hasModeOption(modeId: requestedMode) &&
        requestedMode != _appliedModeId) {
      if (await _setConfig(
        repository: repository,
        sessionId: sessionId,
        configId: modeConfigId,
        value: requestedMode,
        failOnError: failOnError,
      )) {
        _appliedModeId = requestedMode;
      }
    }

    final thoughtLevelModelId = _eventMapper.modelForSession(sessionId) ?? _catalogTracker.currentModelId ?? "";
    final thoughtLevel = _catalogTracker.thoughtLevelForModel(
      modelId: thoughtLevelModelId,
    );
    final requestedThoughtLevel = variant != null && variant.id.isNotEmpty ? variant.id : thoughtLevel?.defaultValue;
    if (requestedThoughtLevel != null &&
        thoughtLevel != null &&
        requestedThoughtLevel != _appliedThoughtLevelId &&
        thoughtLevel.variants.contains(requestedThoughtLevel)) {
      if (await _setConfig(
        repository: repository,
        sessionId: sessionId,
        configId: thoughtLevel.configId,
        value: requestedThoughtLevel,
        failOnError: failOnError,
      )) {
        _appliedThoughtLevelId = requestedThoughtLevel;
      }
    }
  }

  Future<bool> _setConfig({
    required AcpSessionRepository repository,
    required String sessionId,
    required String configId,
    required String value,
    required bool failOnError,
  }) async {
    try {
      final result = await repository.setConfigOption(
        sessionId: sessionId,
        configId: configId,
        value: value,
      );
      final capture = _catalogService.captureSessionConfig(
        result: result,
        fromNewSession: false,
        thoughtLevelModelId: configId == _catalogTracker.modelConfigId ? value : null,
        captureThoughtLevelDefault: configId == _catalogTracker.modelConfigId,
      );
      _applyCaptureToEventMapper(capture: capture, sessionId: sessionId);
      return true;
    } on Object catch (error, stackTrace) {
      if (failOnError) Error.throwWithStackTrace(error, stackTrace);
      Log.w(
        "[cursor] set_config_option($configId=$value) rejected",
        error,
        stackTrace,
      );
      return false;
    }
  }

  void _applyCaptureToEventMapper({
    required CursorCatalogCaptureResult capture,
    required String? sessionId,
  }) {
    _eventMapper.currentProviderId = _providerId;
    _eventMapper.currentModelId = _catalogTracker.currentModelId;
    final loadedModelId = capture.loadedModelId;
    if (sessionId != null && loadedModelId != null) {
      _eventMapper.setSessionModel(
        sessionId,
        loadedModelId,
        providerId: _providerId,
      );
    }
  }

  @override
  void reset() {
    _appliedModelId = null;
    _appliedModeId = null;
    _appliedThoughtLevelId = null;
  }
}
