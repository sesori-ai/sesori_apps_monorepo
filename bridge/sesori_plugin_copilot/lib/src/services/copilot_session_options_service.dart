import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../copilot_identity.dart";
import "../models/copilot_session_options.dart";
import "../repositories/copilot_catalog_repository.dart";

class CopilotSessionOptionsService({
  required final AcpCommandTracker _commandTracker,
  required final AcpSessionConfigurationTracker _configurationTracker,
  required final CopilotCatalogRepository _repository,
  required final String _launchDirectory,
  required final Duration _discoveryTimeout,
}) {
  static const String _providerId = CopilotPluginIdentity.id;

  CopilotSessionConfigSnapshot? _snapshot;
  String? _defaultModelValue;
  String? _defaultModeValue;
  Future<PluginSessionOptionsDiscoveryResult>? _inFlight;
  ({PluginOperationException error, StackTrace stack})? _lastDiscoveryFailure;

  ({PluginOperationException error, StackTrace stack})? get lastDiscoveryFailure => _lastDiscoveryFailure;

  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) {
    if (discoveryMode == PluginSessionOptionsDiscoveryMode.reuse && _snapshot != null) {
      return Future.value(PluginSessionOptionsDiscoveryResult.observed(options: _options()));
    }
    final pending = _inFlight;
    if (pending != null) return pending;
    late final Future<PluginSessionOptionsDiscoveryResult> operation;
    operation = _discover().whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
    _inFlight = operation;
    return operation;
  }

  Future<PluginSessionOptionsDiscoveryResult> _discover() async {
    _lastDiscoveryFailure = null;
    final stopwatch = Stopwatch()..start();
    final expectedCommandRevision = _commandTracker.revision;
    String? sessionId;
    var observed = false;
    try {
      await _repository.open(timeout: _remaining(stopwatch: stopwatch));
      final result = await _repository.createSession(
        cwd: _launchDirectory,
        timeout: _remaining(stopwatch: stopwatch),
      );
      sessionId = result.sessionId;
      captureSessionConfig(result, sessionId: null, fromNewSession: true);
      try {
        await _repository.waitForCommandSnapshot(timeout: _remaining(stopwatch: stopwatch));
      } on TimeoutException {
        // Commands are optional; the coherent config catalog remains usable.
      }
      if (_commandTracker.revision == expectedCommandRevision) {
        if (_repository.hasCommandSnapshot) _commandTracker.replaceSnapshot(commands: _repository.commands);
        if (!_repository.hasCommandSnapshot) _commandTracker.clear();
      }
      observed = true;
    } on Object catch (error, stack) {
      _lastDiscoveryFailure = (
        error: PluginOperationException(
          "session/options",
          message: "GitHub Copilot session options could not be discovered",
          cause: error,
        ),
        stack: stack,
      );
      Log.w("[${CopilotPluginIdentity.id}] session option discovery failed", error, stack);
    } finally {
      if (sessionId != null) {
        try {
          await _repository.closeSession(
            sessionId: sessionId,
            timeout: _remainingOrMinimum(stopwatch: stopwatch),
          );
        } on Object catch (error, stack) {
          Log.w("[${CopilotPluginIdentity.id}] failed to close the option discovery session", error, stack);
        }
      }
      try {
        await _repository.settle();
      } on Object catch (error, stack) {
        Log.w("[${CopilotPluginIdentity.id}] failed to settle option discovery", error, stack);
      }
    }
    return observed
        ? PluginSessionOptionsDiscoveryResult.observed(options: _options())
        : const PluginSessionOptionsDiscoveryResult.failed();
  }

  void captureSessionConfig(
    AcpNewSessionResult result, {
    required String? sessionId,
    required bool fromNewSession,
  }) {
    final snapshot = CopilotCatalogRepository.mapSessionResult(result: result);
    _snapshot = snapshot;
    final modelValue = snapshot.currentModelValue;
    if (fromNewSession) {
      _defaultModelValue = modelValue;
      _defaultModeValue = snapshot.currentModeValue;
      _configurationTracker.setProcessDefaults(
        modelId: modelValue,
        providerId: modelValue == null ? null : _providerId,
      );
    }
    if (sessionId != null && modelValue != null) {
      _configurationTracker.setSessionOverride(
        sessionId: sessionId,
        modelId: modelValue,
        providerId: _providerId,
      );
    }
  }

  void validateTurnSelection({
    required String operation,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) {
    final snapshot = _snapshot;
    final requestedModel = model?.modelID;
    final modes = snapshot?.modes ?? const [];
    final fallbackAgent = modes.isEmpty && agent == CopilotPluginIdentity.displayName;
    if (requestedModel != null &&
        requestedModel.isNotEmpty &&
        (model?.providerID != _providerId ||
            snapshot?.modelConfigId == null ||
            !(snapshot?.models.any((option) => option.value == requestedModel) ?? false))) {
      throw PluginStaleOptionsException(operation, message: "GitHub Copilot no longer offers the selected model");
    }
    if (agent != null &&
        agent.isNotEmpty &&
        !fallbackAgent &&
        (snapshot?.modeConfigId == null || _resolveOption(valueOrName: agent, options: modes) == null)) {
      throw PluginStaleOptionsException(operation, message: "GitHub Copilot no longer offers the selected mode");
    }
    final requestedVariant = variant?.id;
    if (requestedVariant != null &&
        requestedVariant.isNotEmpty &&
        (snapshot?.thoughtLevelConfigId == null ||
            !(snapshot?.thoughtLevels.any((option) => option.value == requestedVariant) ?? false))) {
      throw PluginStaleOptionsException(
        operation,
        message: "GitHub Copilot no longer offers the selected reasoning level",
      );
    }
  }

  Future<void> applyTurnSelection({
    required AcpSessionConfigRepository configRepository,
    required String sessionId,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
    required String? agent,
  }) async {
    validateTurnSelection(
      operation: "session/set_config_option",
      model: model,
      variant: variant,
      agent: agent,
    );
    final snapshot = _snapshot;
    final requestedMode = agent == null
        ? null
        : _resolveOption(valueOrName: agent, options: snapshot?.modes ?? const []);
    final selections = [
      (configId: snapshot?.modelConfigId, value: model?.modelID, kind: CopilotConfigOptionKind.model),
      (configId: snapshot?.modeConfigId, value: requestedMode, kind: CopilotConfigOptionKind.mode),
      (
        configId: snapshot?.thoughtLevelConfigId,
        value: variant?.id,
        kind: CopilotConfigOptionKind.thoughtLevel,
      ),
    ];
    for (final selection in selections) {
      final configId = selection.configId;
      final value = selection.value;
      if (configId == null || value == null || value.isEmpty) continue;
      await _writeAndVerify(
        configRepository: configRepository,
        sessionId: sessionId,
        configId: configId,
        value: value,
        kind: selection.kind,
      );
    }
  }

  List<PluginCommand> get commands => _commandTracker.commands;

  List<PluginAgent> get agents => _agents();

  PluginProvidersResult get providers => _providers();

  void resetConnection() {
    _snapshot = null;
    _defaultModelValue = null;
    _defaultModeValue = null;
    _configurationTracker.clear();
    _lastDiscoveryFailure = null;
  }

  Future<void> dispose() => _repository.dispose();

  Future<void> _writeAndVerify({
    required AcpSessionConfigRepository configRepository,
    required String sessionId,
    required String configId,
    required String value,
    required CopilotConfigOptionKind kind,
  }) async {
    try {
      final result = await configRepository.setConfigOption(
        sessionId: sessionId,
        configId: configId,
        value: value,
      );
      if (result == null) throw StateError("GitHub Copilot returned no session configuration");
      final updated = CopilotCatalogRepository.mapSessionResult(result: result);
      final applied = switch (kind) {
        CopilotConfigOptionKind.model => updated.currentModelValue,
        CopilotConfigOptionKind.mode => updated.currentModeValue,
        CopilotConfigOptionKind.thoughtLevel => updated.currentThoughtLevelValue,
      };
      if (applied != value) throw StateError("GitHub Copilot returned a different session option value");
      _snapshot = updated;
      final modelValue = updated.currentModelValue;
      if (modelValue != null) {
        _configurationTracker.setSessionOverride(
          sessionId: sessionId,
          modelId: modelValue,
          providerId: _providerId,
        );
      }
    } on Object catch (error, stack) {
      Error.throwWithStackTrace(
        PluginOperationException(
          "session/set_config_option",
          message: "GitHub Copilot rejected the requested session option",
          cause: error,
        ),
        stack,
      );
    }
  }

  PluginSessionOptions _options() => PluginSessionOptions(
    agents: _agents(),
    providers: _providers(),
    commands: commands,
    completeness: _snapshot != null && _commandTracker.hasSnapshot
        ? PluginSessionOptionsCompleteness.complete
        : PluginSessionOptionsCompleteness.partial,
  );

  List<PluginAgent> _agents() {
    final modes = _snapshot?.modes ?? const [];
    if (modes.isEmpty) {
      return const [
        PluginAgent(
          name: CopilotPluginIdentity.displayName,
          description: "GitHub Copilot CLI session",
          model: null,
          mode: PluginAgentMode.primary,
          hidden: false,
        ),
      ];
    }
    final ordered = modes.toList(growable: true);
    final defaultMode = _defaultModeValue;
    if (defaultMode != null) {
      final defaultIndex = ordered.indexWhere((mode) => mode.value == defaultMode);
      if (defaultIndex > 0) ordered.insert(0, ordered.removeAt(defaultIndex));
    }
    return [
      for (final mode in ordered)
        PluginAgent(
          name: mode.name,
          description: mode.description,
          model: null,
          mode: PluginAgentMode.primary,
          hidden: false,
        ),
    ];
  }

  PluginProvidersResult _providers() {
    final models = _snapshot?.models ?? const [];
    if (models.isEmpty) return const PluginProvidersResult(providers: []);
    final thoughtLevels = _snapshot?.thoughtLevels ?? const [];
    final defaultModel = models.any((model) => model.value == _defaultModelValue)
        ? _defaultModelValue
        : models.first.value;
    return PluginProvidersResult(
      providers: [
        PluginProvider(
          id: _providerId,
          name: CopilotPluginIdentity.displayName,
          authType: PluginProviderAuthType.unknown,
          models: [
            for (final model in models)
              PluginModel(
                id: model.value,
                name: model.name,
                variants: model.value == _snapshot?.currentModelValue
                    ? [for (final thoughtLevel in thoughtLevels) thoughtLevel.value]
                    : const [],
                family: null,
                isAvailable: true,
                releaseDate: null,
              ),
          ],
          defaultModelID: defaultModel,
        ),
      ],
    );
  }

  Duration _remaining({required Stopwatch stopwatch}) {
    final remaining = _discoveryTimeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) throw TimeoutException("GitHub Copilot option discovery exceeded its deadline");
    return remaining;
  }

  Duration _remainingOrMinimum({required Stopwatch stopwatch}) {
    final remaining = _discoveryTimeout - stopwatch.elapsed;
    return remaining > Duration.zero ? remaining : const Duration(seconds: 1);
  }

  static String? _resolveOption({
    required String valueOrName,
    required List<CopilotCatalogOption> options,
  }) {
    for (final option in options) {
      if (option.value == valueOrName || option.name == valueOrName) return option.value;
    }
    return null;
  }
}
