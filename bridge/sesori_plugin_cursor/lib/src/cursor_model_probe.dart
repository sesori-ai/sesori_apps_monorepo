import "package:acp_plugin/acp_plugin.dart";

/// Helpers for Cursor's `configOptions` model picker returned by `session/new`.
///
/// Cursor does not take a model in `session/new`; instead it returns a config
/// option whose `category` is `"model"` (the option id is NOT hardcoded to
/// "model"). Selecting a model is a `session/set_config_option` call echoing a
/// value from that option's `options[]`. See T3 Code's mismatch probe for the
/// finicky details this guards against.
abstract final class CursorModelProbe {
  /// The configOption whose category is `model`, or null if absent.
  static Map<String, dynamic>? findModelConfig(AcpNewSessionResult session) {
    for (final option in session.configOptions) {
      if (option["category"] == "model") return option;
    }
    return null;
  }

  /// The selectable `{value, name}` model entries for a model config option.
  static List<Map<String, dynamic>> models(Map<String, dynamic> config) {
    final raw = config["options"];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((m) => m.cast<String, dynamic>())
        .toList(growable: false);
  }

  /// The currently selected model value, if any.
  static String? currentValue(Map<String, dynamic> config) {
    final value = config["currentValue"] ?? config["value"];
    return value is String ? value : null;
  }

  /// Whether [models] contains an entry with the given `value`.
  static bool hasModel(List<Map<String, dynamic>> models, String value) {
    for (final model in models) {
      if (model["value"] == value) return true;
    }
    return false;
  }
}
