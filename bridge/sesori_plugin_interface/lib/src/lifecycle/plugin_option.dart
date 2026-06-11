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
sealed class PluginOption {
  const PluginOption({required this.name, required this.help});

  /// The flag name as typed on the command line, without dashes
  /// (e.g. `"port"` for `--port`).
  final String name;

  /// One-line help text shown in `--help` output.
  final String help;
}

/// A boolean CLI flag (e.g. `--no-auto-start`).
final class PluginFlagOption extends PluginOption {
  const PluginFlagOption({
    required super.name,
    required super.help,
    this.defaultsTo = false,
    this.negatable = false,
  });

  /// Value when the flag is not passed.
  final bool defaultsTo;

  /// Whether the parser also accepts a `--no-<name>` inversion.
  final bool negatable;
}

/// A CLI option that takes a string value (e.g. `--port 4096`).
final class PluginValueOption extends PluginOption {
  const PluginValueOption({
    required super.name,
    required super.help,
    this.defaultsTo,
    this.allowedValues,
    this.valueHelp,
    this.validate,
  });

  /// An option whose value must parse as an integer (e.g. `--port`).
  ///
  /// The typed-parse hook so plugins don't re-implement the
  /// "`int.parse` + usage error" dance: the bridge rejects a non-numeric
  /// value at argument-parse time, and `PluginConfig.intValue` then never
  /// throws for this option.
  const PluginValueOption.integer({
    required String name,
    required String help,
    String? defaultsTo,
    String? valueHelp,
  }) : this(name: name, help: help, defaultsTo: defaultsTo, valueHelp: valueHelp, validate: validateInteger);

  /// Value when the option is not passed; `null` means "absent".
  final String? defaultsTo;

  /// When non-null, the parser rejects values outside this list.
  final List<String>? allowedValues;

  /// Placeholder shown in `--help` output (e.g. `"path"`).
  final String? valueHelp;

  /// Typed-parse hook the bridge runs at argument-parse time on a present,
  /// non-empty value — strictly before the startup mutex, so a typed value
  /// the user got wrong can never terminate a healthy resident bridge.
  final PluginOptionValueValidator? validate;

  /// Built-in [validate] hook requiring an integer value.
  static void validateInteger(String name, String value) {
    if (int.tryParse(value) == null) {
      throw PluginConfigException("The --$name option expects an integer, got '$value'.");
    }
  }
}
