/// A plugin configuration problem the user must fix (a usage error).
///
/// Thrown by `PluginOption` validate hooks, by
/// `BridgePluginDescriptor.validateConfig`, and by [PluginConfig]'s typed
/// accessors. The bridge surfaces [message] as a CLI usage error.
///
/// For the error to surface *before* the startup mutex is taken (and before
/// any resident bridge could be replaced), it must be thrown at
/// argument-parse time — from an option's validate hook (e.g.
/// `PluginValueOption.integer`) or from `validateConfig`. Exercise every
/// typed accessor in `validateConfig`; one thrown later, from `start()`,
/// still fails the start but only after irreversible steps may have run.
class PluginConfigException implements Exception {
  const PluginConfigException(this.message);

  /// Human-readable description of what is wrong and how to fix it.
  final String message;

  @override
  String toString() => "PluginConfigException: $message";
}

/// Parsed values for the options a plugin declared via `PluginOption`.
///
/// The bridge populates one entry per declared option — flags as [bool],
/// value options as [String?] (`null` when absent with no default). Asking
/// for an undeclared name is a programmer error and throws [ArgumentError];
/// a value the *user* got wrong (e.g. a non-numeric `--port`) throws
/// [PluginConfigException] instead, so plugins don't re-implement the
/// "`int.parse` + usage error" dance.
class PluginConfig {
  const PluginConfig({required Map<String, Object?> values}) : _values = values;

  /// A config with no options, for plugins that declare none.
  const PluginConfig.empty() : _values = const {};

  final Map<String, Object?> _values;

  /// The value of the flag [name].
  ///
  /// Throws [ArgumentError] when [name] was never declared (or is not a
  /// flag) — that is a wiring bug, not a user error.
  bool flag(String name) {
    final value = _require(name);
    if (value is! bool) {
      throw ArgumentError.value(value, "name", "Plugin option '$name' is not a flag");
    }
    return value;
  }

  /// The raw string value of the option [name], `null` when absent.
  ///
  /// Throws [ArgumentError] when [name] was never declared.
  String? value(String name) {
    final value = _require(name);
    if (value is! String?) {
      throw ArgumentError.value(value, "name", "Plugin option '$name' is not a value option");
    }
    return value;
  }

  /// The value of the option [name] parsed as an integer.
  ///
  /// Absent or empty values return `null`. A non-numeric value throws
  /// [PluginConfigException] with a usage-style message naming the flag —
  /// though for options declared with `PluginValueOption.integer` the bridge
  /// has already rejected such values at argument-parse time, so this never
  /// throws for them.
  int? intValue(String name) {
    final raw = value(name);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      throw PluginConfigException("The --$name option expects an integer, got '$raw'.");
    }
    return parsed;
  }

  Object? _require(String name) {
    if (!_values.containsKey(name)) {
      throw ArgumentError.value(name, "name", "Plugin option was never declared");
    }
    return _values[name];
  }
}
