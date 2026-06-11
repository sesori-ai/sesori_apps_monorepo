import "package:args/args.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show PluginConfig, PluginFlagOption, PluginOption, PluginValueOption;

/// Registers a plugin's declared [options] into the bridge's CLI [parser].
///
/// Pure declaration: no validation runs here. The bridge registers only the
/// *selected* plugin's options, so flag names cannot collide across plugins.
void registerPluginOptions({required ArgParser parser, required List<PluginOption> options}) {
  for (final option in options) {
    switch (option) {
      case PluginFlagOption():
        parser.addFlag(
          option.name,
          help: option.help,
          defaultsTo: option.defaultsTo,
          negatable: option.negatable,
        );
      case PluginValueOption():
        parser.addOption(
          option.name,
          help: option.help,
          defaultsTo: option.defaultsTo,
          allowed: option.allowedValues,
          valueHelp: option.valueHelp,
        );
    }
  }
}

/// Builds the [PluginConfig] for [options] from parsed [results], running
/// each value option's `validate` hook on present, non-empty values.
///
/// This is the argument-parse-time half of the plugin config contract: it
/// runs strictly before the startup mutex, so a typed value the user got
/// wrong (e.g. a non-numeric `--port`) surfaces as a usage error
/// (`PluginConfigException`) before any irreversible step.
PluginConfig parsePluginConfig({required List<PluginOption> options, required ArgResults results}) {
  final values = <String, Object?>{};
  for (final option in options) {
    switch (option) {
      case PluginFlagOption():
        values[option.name] = results[option.name] as bool;
      case PluginValueOption():
        final raw = results[option.name] as String?;
        values[option.name] = raw;
        final validate = option.validate;
        if (validate != null && raw != null && raw.isNotEmpty) {
          validate(option.name, raw);
        }
    }
  }
  return PluginConfig(values: values);
}
