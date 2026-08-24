import "package:acp_plugin/acp_plugin.dart";

import "../../api/models/cursor_available_models_dto.dart";
import "../../models/cursor_catalog_models.dart";

/// Maps Cursor's raw ACP config options into the internal catalog model.
abstract final class CursorCatalogMapper() {
  static CursorCatalogBootstrapSnapshot mapAvailableModels({
    required CursorAvailableModelsDto result,
  }) {
    final models = <CursorCatalogOption>[];
    final thoughtLevelsByModel = <String, CursorThoughtLevelSnapshot>{};
    for (final model in result.models) {
      final modelId = model.value;
      if (modelId.isEmpty) continue;
      models.add(
        CursorCatalogOption(
          value: modelId,
          name: switch (model.name) {
            final name? when name.isNotEmpty => name,
            _ => modelId,
          },
          description: null,
        ),
      );
      final thoughtLevel = _mapAvailableThoughtLevel(model: model);
      if (thoughtLevel != null) {
        thoughtLevelsByModel[modelId] = thoughtLevel;
      }
    }

    return CursorCatalogBootstrapSnapshot(
      models: models,
      modes: [
        for (final mode in CursorMode.values)
          CursorCatalogOption(
            value: mode.id,
            name: mode.displayName,
            description: null,
          ),
      ],
      defaultModeId: CursorMode.agent.id,
      thoughtLevelsByModel: thoughtLevelsByModel,
    );
  }

  static CursorCatalogSnapshot mapSession({required AcpNewSessionResult result}) {
    final modelConfig = _findConfig(result: result, category: "model");
    final modeConfig = _findConfig(result: result, category: "mode");
    final thoughtConfig = _findThoughtLevelConfig(result: result);

    return CursorCatalogSnapshot(
      modelConfigId: _configId(config: modelConfig),
      models: _options(config: modelConfig),
      loadedModelId: _currentValue(config: modelConfig),
      modeConfigId: _configId(config: modeConfig),
      modes: _options(config: modeConfig),
      loadedModeId: _currentValue(config: modeConfig),
      thoughtLevel: thoughtConfig == null
          ? null
          : CursorThoughtLevelSnapshot(
              configId: thoughtConfig["id"] as String,
              variants: _orderedValues(config: thoughtConfig),
              defaultValue: _currentValue(config: thoughtConfig),
            ),
    );
  }

  static CursorThoughtLevelSnapshot? _mapAvailableThoughtLevel({
    required CursorAvailableModelDto model,
  }) {
    CursorModelConfigOptionDto? effort;
    CursorModelConfigOptionDto? reasoning;
    for (final option in model.configOptions) {
      if (option.category != "thought_level") continue;
      switch (option.id) {
        case "effort":
          effort = option;
        case "reasoning":
          reasoning = option;
        case _:
          break;
      }
    }
    final selected = switch ((reasoning, effort)) {
      (final reasoning?, _) when _hasMultiLevelAvailableOptions(config: reasoning) => reasoning,
      (_, final effort?) when _hasMultiLevelAvailableOptions(config: effort) => effort,
      _ => null,
    };
    if (selected == null) return null;
    final values = [
      for (final option in selected.options)
        if (option.value.isNotEmpty) option.value,
    ];
    final currentValue = selected.currentValue;
    if (currentValue != null && currentValue.isNotEmpty && values.remove(currentValue)) {
      values.insert(0, currentValue);
    }
    return CursorThoughtLevelSnapshot(
      configId: selected.id,
      variants: values,
      defaultValue: currentValue,
    );
  }

  static bool _hasMultiLevelAvailableOptions({
    required CursorModelConfigOptionDto config,
  }) {
    final values = config.options.map((option) => option.value).where((value) => value.isNotEmpty).toSet();
    if (values.length <= 1) return false;
    if (values.length == 2 && (values.containsAll({"true", "false"}) || values.containsAll({"on", "off"}))) {
      return false;
    }
    return true;
  }

  static Map<String, dynamic>? _findConfig({
    required AcpNewSessionResult result,
    required String category,
  }) => AcpConfigOptionParser.find(configs: result.configOptions, category: category);

  static Map<String, dynamic>? _findThoughtLevelConfig({
    required AcpNewSessionResult result,
  }) {
    Map<String, dynamic>? effort;
    Map<String, dynamic>? reasoning;
    for (final option in result.configOptions) {
      if (option["category"] != "thought_level") continue;
      switch (option["id"]) {
        case "effort":
          effort = option;
        case "reasoning":
          reasoning = option;
        case _:
          break;
      }
    }
    if (reasoning != null && _hasMultiLevelOptions(config: reasoning)) return reasoning;
    if (effort != null && _hasMultiLevelOptions(config: effort)) return effort;
    return null;
  }

  static String? _configId({required Map<String, dynamic>? config}) => AcpConfigOptionParser.id(config);

  static String? _currentValue({required Map<String, dynamic>? config}) => AcpConfigOptionParser.currentValue(config);

  static List<CursorCatalogOption> _options({
    required Map<String, dynamic>? config,
  }) {
    return [
      for (final option in _flattenedOptions(config: config))
        if (_optionValue(option) case final String value when value.isNotEmpty)
          CursorCatalogOption(
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

  static List<String> _orderedValues({required Map<String, dynamic> config}) {
    final values = [for (final option in _options(config: config)) option.value];
    final currentValue = _currentValue(config: config);
    if (currentValue != null && values.remove(currentValue)) {
      values.insert(0, currentValue);
    }
    return values;
  }

  static List<Map<String, dynamic>> _flattenedOptions({
    required Map<String, dynamic>? config,
  }) => AcpConfigOptionParser.flattenedOptions(config);

  static bool _hasMultiLevelOptions({required Map<String, dynamic> config}) {
    final options = _options(config: config);
    if (options.length <= 1) return false;
    if (options.length == 2) {
      final values = options.map((option) => option.value).toSet();
      if (values.containsAll({"true", "false"}) || values.containsAll({"on", "off"})) {
        return false;
      }
    }
    return true;
  }
}
