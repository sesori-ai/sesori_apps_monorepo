import "package:args/args.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show PluginConfig, PluginFlagOption, PluginOption, PluginValueOption;

/// Translates a plugin's declared [PluginOption]s to and from the bridge CLI's
/// `args` model, namespaced under one [pluginId].
///
/// Plugins declare bare local option names (e.g. `host`); this mapper
/// namespaces them to `--<pluginId>-<name>` (e.g. `--opencode-host`) so options
/// can't collide when multiple plugins are active.
final class const PluginCliOptionsMapper({
  /// The plugin id every option is namespaced under.
  required final String pluginId,
}) {
  /// Registers [options] into [parser] under their canonical
  /// `<pluginId>-<name>` flags.
  ///
  /// Pure declaration: no validation runs here.
  void register({required ArgParser parser, required List<PluginOption> options}) {
    for (final option in options) {
      final canonical = _flagName(optionName: option.name);
      switch (option) {
        case PluginFlagOption():
          parser.addFlag(
            canonical,
            help: option.help,
            defaultsTo: option.defaultsTo,
            negatable: option.negatable,
          );
        case PluginValueOption():
          parser.addOption(
            canonical,
            help: option.help,
            defaultsTo: option.defaultsTo,
            allowed: option.allowedValues,
            valueHelp: option.valueHelp,
          );
      }
    }
  }

  /// Builds the [PluginConfig] for [options] from parsed [results] and runs each
  /// value option's validate hook on present, non-empty values. Values are keyed
  /// by the bare option name, so plugin code stays unaware of namespacing.
  ///
  /// Runs at argument-parse time, strictly before the startup mutex, so a typed
  /// value the user got wrong (e.g. a non-numeric `--opencode-port`) surfaces
  /// as a usage error (`PluginConfigException`) before any irreversible step.
  PluginConfig parse({
    required ArgResults results,
    required List<PluginOption> options,
  }) {
    final values = <String, Object?>{};
    for (final option in options) {
      final canonical = _flagName(optionName: option.name);
      switch (option) {
        case PluginFlagOption():
          values[option.name] = results[canonical] as bool;
        case PluginValueOption():
          final raw = results[canonical] as String?;
          values[option.name] = raw;
          final validate = option.validate;
          if (validate != null && raw != null && raw.isNotEmpty) {
            validate(canonical, raw);
          }
      }
    }
    return PluginConfig(values: values);
  }

  /// The canonical `<pluginId>-<name>` flag for a bare [optionName].
  String _flagName({required String optionName}) => "$pluginId-$optionName";
}
