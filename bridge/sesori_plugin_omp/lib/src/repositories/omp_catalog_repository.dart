import "dart:async";

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginCommand;

import "../api/omp_acp_api.dart";
import "../models/omp_catalog_models.dart";
import "../omp_identity.dart";

/// Layer-2 mapping and access for OMP catalog discovery.
class OmpCatalogRepository({required final OmpAcpApi _api}) {
  AcpCommandTracker? _commandTracker;
  StreamSubscription<AcpNotification>? _commandSubscription;
  Completer<void>? _commandSnapshot;

  List<PluginCommand> get commands => _commandTracker?.commands ?? const [];
  bool get hasCommandSnapshot => _commandTracker?.hasSnapshot ?? false;

  Future<void> open({required String cwd, required Duration timeout}) async {
    final result = await _api.open(cwd: cwd, timeout: timeout);
    if (!result.agentCapabilities.closeSession) {
      throw StateError("OMP catalog probing requires session/close");
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

  Future<OmpCatalogSession> createSession({required String cwd, required Duration timeout}) async {
    final result = await _api.newSession(cwd: cwd, timeout: timeout);
    return OmpCatalogSession(
      sessionId: result.sessionId,
      snapshot: mapSessionResult(result: result),
    );
  }

  Future<OmpSessionConfigSnapshot> selectModel({
    required String sessionId,
    required String configId,
    required String modelValue,
    required Duration timeout,
  }) async {
    final result = await _api.setConfigOption(
      sessionId: sessionId,
      configId: configId,
      value: modelValue,
      timeout: timeout,
    );
    return mapSessionResult(result: result);
  }

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
      Log.w("[${OmpPluginIdentity.id}] failed to stop catalog command listener", error, stack);
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

  OmpSessionConfigSnapshot mapSessionResult({required AcpNewSessionResult result}) {
    final modelConfig = _findConfig(result: result, category: "model", id: "model");
    final modeConfig = _findConfig(result: result, category: "mode", id: "mode");
    final thinkingConfig = _findConfig(result: result, category: "thought_level", id: "thinking");
    return OmpSessionConfigSnapshot(
      modelConfigId: _configId(modelConfig),
      models: _models(modelConfig),
      currentModelValue: _currentValue(modelConfig),
      modeConfigId: _configId(modeConfig),
      modes: _options(modeConfig),
      currentModeValue: _currentValue(modeConfig),
      thinking: thinkingConfig == null
          ? null
          : OmpThinkingOptions(
              configId: _configId(thinkingConfig) ?? "thinking",
              variants: [for (final option in _options(thinkingConfig)) option.value],
              currentValue: _currentValue(thinkingConfig),
            ),
    );
  }

  static Map<String, dynamic>? _findConfig({
    required AcpNewSessionResult result,
    required String category,
    required String id,
  }) {
    Map<String, dynamic>? categoryFallback;
    for (final config in result.configOptions) {
      if (config["id"] == id) return config;
      if (categoryFallback == null && config["category"] == category) {
        categoryFallback = config;
      }
    }
    return categoryFallback;
  }

  static String? _configId(Map<String, dynamic>? config) {
    final id = config?["id"];
    return id is String && id.isNotEmpty ? id : null;
  }

  static String? _currentValue(Map<String, dynamic>? config) {
    final value = config?["currentValue"] ?? config?["value"];
    return value is String && value.isNotEmpty ? value : null;
  }

  static List<OmpCatalogModel> _models(Map<String, dynamic>? config) {
    return [
      for (final option in _options(config))
        if (_splitModelValue(option.value) case (final providerId, final modelId))
          OmpCatalogModel(
            value: option.value,
            providerId: providerId,
            modelId: modelId,
            name: option.name,
          ),
    ];
  }

  static (String, String)? _splitModelValue(String value) {
    final separator = value.indexOf("/");
    if (separator <= 0 || separator == value.length - 1) return null;
    return (value.substring(0, separator), value.substring(separator + 1));
  }

  static List<OmpCatalogOption> _options(Map<String, dynamic>? config) {
    return [
      for (final option in _flattenedOptions(config))
        if (_optionValue(option) case final String value when value.isNotEmpty)
          OmpCatalogOption(
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

  static Object? _optionValue(Map<String, dynamic> option) => option["value"];

  static List<Map<String, dynamic>> _flattenedOptions(Map<String, dynamic>? config) {
    final raw = config?["options"];
    if (raw is! List) return const [];
    final options = <Map<String, dynamic>>[];
    for (final entry in raw.whereType<Map<dynamic, dynamic>>()) {
      final option = entry.cast<String, dynamic>();
      final nested = option["options"];
      if (nested is List) {
        options.addAll(
          nested.whereType<Map<dynamic, dynamic>>().map((item) => item.cast<String, dynamic>()),
        );
      } else {
        options.add(option);
      }
    }
    return options;
  }
}
