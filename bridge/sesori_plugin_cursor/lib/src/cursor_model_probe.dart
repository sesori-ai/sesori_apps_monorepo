import "package:acp_plugin/acp_plugin.dart";

/// Helpers for Cursor's `configOptions` selectors returned by `session/new`
/// and `session/load`.
///
/// Cursor does not take a model in `session/new`; instead it returns config
/// options whose `category` identifies the dimension (`"model"`, `"mode"`,
/// `"model_config"`). The option id is NOT hardcoded to the category. Selecting
/// a value is a `session/set_config_option` call echoing a value from that
/// option's `options[]`. See T3 Code's mismatch probe for the finicky details
/// this guards against.
abstract final class CursorModelProbe {
  /// The configOption with the given [category] (e.g. `"model"`, `"mode"`), or
  /// null if absent.
  static Map<String, dynamic>? findConfig(
    AcpNewSessionResult session,
    String category,
  ) {
    for (final option in session.configOptions) {
      if (option["category"] == category) return option;
    }
    return null;
  }

  /// The configOption whose category is `model`, or null if absent.
  static Map<String, dynamic>? findModelConfig(AcpNewSessionResult session) =>
      findConfig(session, "model");

  /// The selectable `{value, name}` entries for a config option.
  ///
  /// ACP allows the option list to be *grouped* (`{group, name, options: […]}`
  /// entries instead of flat `{value, name}` ones). Groups are flattened in
  /// order — a group entry carries no `value` of its own, so returning it
  /// as-is would drop every nested model/variant from the catalog and leave
  /// `applyTurnSelection` unable to find any selectable value.
  static List<Map<String, dynamic>> options(Map<String, dynamic> config) {
    final raw = config["options"];
    if (raw is! List) return const [];
    final flattened = <Map<String, dynamic>>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();
      final nested = map["options"];
      if (nested is List) {
        flattened.addAll(
          nested.whereType<Map<dynamic, dynamic>>().map((m) => m.cast<String, dynamic>()),
        );
      } else {
        flattened.add(map);
      }
    }
    return flattened;
  }

  /// Alias of [options] for the model config (reads more clearly at the model
  /// call site).
  static List<Map<String, dynamic>> models(Map<String, dynamic> config) =>
      options(config);

  /// The currently selected value, if any.
  static String? currentValue(Map<String, dynamic> config) {
    final value = config["currentValue"] ?? config["value"];
    return value is String ? value : null;
  }

  /// Whether [options] contains an entry with the given `value`.
  static bool hasOption(List<Map<String, dynamic>> options, String value) {
    for (final option in options) {
      if (option["value"] == value) return true;
    }
    return false;
  }

  /// Alias of [hasOption] for the model list.
  static bool hasModel(List<Map<String, dynamic>> models, String value) =>
      hasOption(models, value);
}
