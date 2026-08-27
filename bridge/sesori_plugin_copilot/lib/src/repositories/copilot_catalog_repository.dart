import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginCommand;

import "../api/copilot_catalog_probe_api.dart";
import "../copilot_identity.dart";
import "../models/copilot_session_options.dart";

enum CopilotConfigOptionKind({required final String category}) {
  model(category: "model"),
  mode(category: "mode"),
  thoughtLevel(category: "thought_level");
}

class CopilotCatalogRepository({required final CopilotCatalogProbeApi _api}) {
  AcpCommandTracker? _commandTracker;
  StreamSubscription<AcpNotification>? _commandSubscription;
  Completer<void>? _commandSnapshot;

  List<PluginCommand> get commands => _commandTracker?.commands ?? const [];
  bool get hasCommandSnapshot => _commandTracker?.hasSnapshot ?? false;

  Future<void> open({required Duration timeout}) async {
    final initialized = await _api.open(timeout: timeout);
    if (!initialized.agentCapabilities.closeSession) {
      throw StateError("GitHub Copilot option discovery requires session/close");
    }
    final tracker = AcpCommandTracker();
    _commandTracker = tracker;
    final snapshot = Completer<void>();
    _commandSnapshot = snapshot;
    _commandSubscription = _api.notifications.listen((notification) {
      tracker.consume(notification);
      if (tracker.hasSnapshot && !snapshot.isCompleted) snapshot.complete();
    });
  }

  Future<AcpNewSessionResult> createSession({required String cwd, required Duration timeout}) =>
      _api.newSession(cwd: cwd, timeout: timeout);

  Future<void> closeSession({required String sessionId, required Duration timeout}) =>
      _api.closeSession(sessionId: sessionId, timeout: timeout);

  Future<void> waitForCommandSnapshot({required Duration timeout}) async {
    if (hasCommandSnapshot) return;
    await _commandSnapshot?.future.timeout(timeout);
  }

  Future<void> settle() async {
    try {
      await _commandSubscription?.cancel();
    } on Object catch (error, stack) {
      Log.w("[${CopilotPluginIdentity.id}] failed to stop the catalog command listener", error, stack);
    }
    _commandSubscription = null;
    _commandSnapshot = null;
    _commandTracker = null;
    await _api.settle();
  }

  Future<void> dispose() async {
    await settle();
    await _api.dispose();
  }

  static CopilotSessionConfigSnapshot mapSessionResult({required AcpNewSessionResult result}) {
    final model = _findConfig(result: result, kind: CopilotConfigOptionKind.model);
    final mode = _findConfig(result: result, kind: CopilotConfigOptionKind.mode);
    final thoughtLevel = _findConfig(result: result, kind: CopilotConfigOptionKind.thoughtLevel);
    return CopilotSessionConfigSnapshot(
      modelConfigId: AcpConfigOptionParser.id(config: model),
      models: _options(config: model),
      currentModelValue: AcpConfigOptionParser.currentValue(config: model),
      modeConfigId: AcpConfigOptionParser.id(config: mode),
      modes: _options(config: mode),
      currentModeValue: AcpConfigOptionParser.currentValue(config: mode),
      thoughtLevelConfigId: AcpConfigOptionParser.id(config: thoughtLevel),
      thoughtLevels: _options(config: thoughtLevel),
      currentThoughtLevelValue: AcpConfigOptionParser.currentValue(config: thoughtLevel),
    );
  }

  // ignore: no_slop_linter/prefer_specific_type, standard ACP config options are heterogeneous JSON objects
  static Map<String, dynamic>? _findConfig({
    required AcpNewSessionResult result,
    required CopilotConfigOptionKind kind,
  }) => AcpConfigOptionParser.find(
    configs: result.configOptions,
    category: kind.category,
    id: null,
  );

  // ignore: no_slop_linter/prefer_specific_type, standard ACP config options are heterogeneous JSON objects
  static List<CopilotCatalogOption> _options({required Map<String, dynamic>? config}) {
    return [
      for (final option in AcpConfigOptionParser.flattenedOptions(config: config))
        if (_optionValue(option: option) case final String value when value.isNotEmpty)
          CopilotCatalogOption(
            value: value,
            name: switch (option["name"]) {
              final String name when name.isNotEmpty => name,
              _ => value,
            },
            description: switch (option["description"]) {
              final String description when description.isNotEmpty => description,
              _ => null,
            },
          ),
    ];
  }

  // ignore: no_slop_linter/prefer_specific_type, the value comes from a heterogeneous ACP JSON object
  static Object? _optionValue({required Map<String, dynamic> option}) => option["value"];
}
