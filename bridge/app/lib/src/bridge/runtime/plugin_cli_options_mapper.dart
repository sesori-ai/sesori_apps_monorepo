import "package:args/args.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart"
    show PluginConfig, PluginFlagOption, PluginOption, PluginValueOption;

/// Translates a plugin's declared [PluginOption]s to and from the bridge CLI's
/// `args` model, namespaced under one [pluginId].
///
/// Plugins declare bare local option names (e.g. `host`); this mapper
/// namespaces them to `--<pluginId>-<name>` (e.g. `--opencode-host`) so options
/// can't collide when multiple plugins are active. Pre-namespacing spellings
/// declared via [PluginOption.deprecatedAliases] are registered as hidden flags
/// and reported as deprecated when used, so existing invocations keep working.
final class PluginCliOptionsMapper {
  const PluginCliOptionsMapper({required this.pluginId});

  /// The plugin id every option is namespaced under.
  final String pluginId;

  /// Registers [options] into [parser] under their canonical
  /// `<pluginId>-<name>` flags, plus one hidden flag per deprecated alias.
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
          for (final alias in option.deprecatedAliases) {
            // Hidden, same negatability; defaultsTo false so wasParsed reflects
            // only an explicit legacy invocation.
            parser.addFlag(alias, hide: true, defaultsTo: false, negatable: option.negatable);
          }
        case PluginValueOption():
          parser.addOption(
            canonical,
            help: option.help,
            defaultsTo: option.defaultsTo,
            allowed: option.allowedValues,
            valueHelp: option.valueHelp,
          );
          for (final alias in option.deprecatedAliases) {
            // Hidden, same allowed-value enforcement; no default so wasParsed
            // distinguishes "user passed the legacy flag" from "default applied".
            parser.addOption(alias, hide: true, allowed: option.allowedValues);
          }
      }
    }
  }

  /// Builds the [PluginConfig] for [options] from parsed [results], resolving
  /// the canonical flag and any legacy [PluginOption.deprecatedAliases], and
  /// running each value option's validate hook on present, non-empty values.
  ///
  /// Returns the config plus one human-readable deprecation warning per used
  /// legacy alias (the caller logs them). Values are keyed by the bare option
  /// name, so plugin code stays unaware of namespacing.
  ///
  /// Precedence per option: the canonical flag if the user passed it, else the
  /// first deprecated alias they passed (which adds a deprecation warning),
  /// else the canonical default.
  ///
  /// Runs at argument-parse time, strictly before the startup mutex, so a typed
  /// value the user got wrong (e.g. a non-numeric `--opencode-port`) surfaces
  /// as a usage error (`PluginConfigException`) before any irreversible step.
  ({PluginConfig config, List<String> deprecations}) parse({
    required ArgResults results,
    required List<PluginOption> options,
  }) {
    final values = <String, Object?>{};
    final deprecations = <String>[];
    for (final option in options) {
      final canonical = _flagName(optionName: option.name);
      final usedAlias = _usedDeprecatedAlias(option: option, results: results);
      if (usedAlias != null) {
        deprecations.add("--$usedAlias is deprecated; use --$canonical instead.");
      }
      // The source flag the value is read from: canonical when set, else the
      // used alias, else canonical (so its declared default applies).
      final source = results.wasParsed(canonical) ? canonical : (usedAlias ?? canonical);
      switch (option) {
        case PluginFlagOption():
          values[option.name] = results[source] as bool;
        case PluginValueOption():
          final raw = results[source] as String?;
          values[option.name] = raw;
          final validate = option.validate;
          if (validate != null && raw != null && raw.isNotEmpty) {
            // Name the flag the user actually typed (canonical or the legacy
            // alias) so the usage error points at the right spelling.
            validate(source, raw);
          }
      }
    }
    return (config: PluginConfig(values: values), deprecations: deprecations);
  }

  /// The canonical `<pluginId>-<name>` flag for a bare [optionName].
  String _flagName({required String optionName}) => "$pluginId-$optionName";

  /// The first of [PluginOption.deprecatedAliases] the user actually passed, or
  /// `null` when none were used.
  String? _usedDeprecatedAlias({required PluginOption option, required ArgResults results}) {
    for (final alias in option.deprecatedAliases) {
      if (results.wasParsed(alias)) {
        return alias;
      }
    }
    return null;
  }
}
