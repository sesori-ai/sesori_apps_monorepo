import "package:acp_plugin/acp_plugin.dart";

import "../../models/cursor_catalog_models.dart";

/// Maps Cursor's ACP config options into the internal catalog model.
abstract final class CursorCatalogMapper {
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
              configId: thoughtConfig.id!,
              variants: _orderedValues(config: thoughtConfig),
              defaultValue: _currentValue(config: thoughtConfig),
            ),
    );
  }

  static AcpConfigOption? _findConfig({
    required AcpNewSessionResult result,
    required String category,
  }) {
    for (final option in result.configOptions) {
      if (option.category == category) return option;
    }
    return null;
  }

  static AcpConfigOption? _findThoughtLevelConfig({
    required AcpNewSessionResult result,
  }) {
    AcpConfigOption? effort;
    AcpConfigOption? reasoning;
    for (final option in result.configOptions) {
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
    if (reasoning != null && _hasMultiLevelOptions(config: reasoning)) return reasoning;
    if (effort != null && _hasMultiLevelOptions(config: effort)) return effort;
    return null;
  }

  static String? _configId({required AcpConfigOption? config}) {
    final id = config?.id;
    return id == null || id.isEmpty ? null : id;
  }

  static String? _currentValue({required AcpConfigOption? config}) {
    final value = config?.currentValue ?? config?.value;
    return value == null || value.isEmpty ? null : value;
  }

  static List<CursorCatalogOption> _options({
    required AcpConfigOption? config,
  }) {
    return [
      for (final option in _flattenedOptions(config: config))
        if (option.value case final String value when value.isNotEmpty)
          CursorCatalogOption(
            value: value,
            name: switch (option.name) {
              final String name when name.isNotEmpty => name,
              _ => value,
            },
            description: switch (option.description) {
              final String description when description.isNotEmpty => description,
              _ => null,
            },
          ),
    ];
  }

  static List<String> _orderedValues({required AcpConfigOption config}) {
    final values = [for (final option in _options(config: config)) option.value];
    final currentValue = _currentValue(config: config);
    if (currentValue != null && values.remove(currentValue)) {
      values.insert(0, currentValue);
    }
    return values;
  }

  static List<AcpConfigOptionValue> _flattenedOptions({
    required AcpConfigOption? config,
  }) {
    final options = config?.options ?? const [];
    final flattened = <AcpConfigOptionValue>[];
    for (final option in options) {
      if (option.options.isNotEmpty) {
        flattened.addAll(option.options);
      } else {
        flattened.add(option);
      }
    }
    return flattened;
  }

  static bool _hasMultiLevelOptions({required AcpConfigOption config}) {
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
