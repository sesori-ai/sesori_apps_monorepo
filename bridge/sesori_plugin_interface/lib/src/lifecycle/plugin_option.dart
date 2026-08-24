import "package:meta/meta.dart";

import "plugin_config.dart";

/// Validates the raw CLI value of [name] at argument-parse time.
///
/// Throw [PluginConfigException] to reject the value with a usage error.
/// Runs before the bridge's startup mutex, so a typed value the user got
/// wrong surfaces before any irreversible step.
typedef PluginOptionValueValidator = void Function(String name, String value);

/// A CLI option a plugin contributes to the bridge's argument parser.
///
/// Declared on `BridgePluginDescriptor.options`. The bridge registers only
/// the *selected* plugin's options into its parser, parses the command line,
/// and hands the values back through a `PluginConfig`. Declaring an option
/// has no side effects — descriptors stay inert until started.
@immutable
sealed class const PluginOption({
  /// The option's local name, without dashes or a plugin prefix
  /// (e.g. `"port"`). The bridge namespaces this to `--<pluginId>-<name>`
  /// when registering it, so plugins never spell their own prefix.
  required final String name,

  /// One-line help text shown in `--help` output.
  required final String help,
});

/// A boolean CLI flag (e.g. `--no-auto-start`).
final class const PluginFlagOption({
  required super.name,
  required super.help,

  /// Value when the flag is not passed.
  required final bool defaultsTo,

  /// Whether the parser also accepts a `--no-<name>` inversion.
  required final bool negatable,
}) extends PluginOption;

/// A CLI option that takes a string value (e.g. `--port 4096`).
final class const PluginValueOption({
  required super.name,
  required super.help,

  /// Value when the option is not passed; `null` means "absent".
  required final String? defaultsTo,

  /// When non-null, the parser rejects values outside this list.
  required final List<String>? allowedValues,

  /// Placeholder shown in `--help` output (e.g. `"path"`).
  required final String? valueHelp,

  /// Typed-parse hook the bridge runs at argument-parse time on a present,
  /// non-empty value — strictly before the startup mutex, so a typed value
  /// the user got wrong can never terminate a healthy resident bridge.
  required final PluginOptionValueValidator? validate,
}) extends PluginOption {
  /// An option whose value must parse as an integer (e.g. `--port`).
  ///
  /// The typed-parse hook so plugins don't re-implement the
  /// "`int.parse` + usage error" dance: the bridge rejects a non-numeric
  /// value at argument-parse time, and `PluginConfig.intValue` then never
  /// throws for this option.
  const new integer({
    required String name,
    required String help,
    required String? defaultsTo,
    required String? valueHelp,
  }) : this(
         name: name,
         help: help,
         defaultsTo: defaultsTo,
         allowedValues: null,
         valueHelp: valueHelp,
         validate: validateInteger,
       );

  /// Built-in [validate] hook requiring an integer value. Delegates to
  /// [PluginConfig.parseIntegerOption] so the parse rule and error message
  /// have a single source of truth.
  // ignore: no_slop_linter/prefer_required_named_parameters, validator callback signature
  static void validateInteger(String name, String value) {
    PluginConfig.parseIntegerOption(name, value);
  }
}
