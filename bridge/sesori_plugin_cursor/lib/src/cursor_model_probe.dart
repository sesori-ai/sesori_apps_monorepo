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

  /// Cursor's per-model effort/reasoning knob under `thought_level` (id varies:
  /// `effort` on Claude, `reasoning` on GPT, etc.). Skips binary on/off knobs
  /// like `thinking` that are not effort-level pickers.
  static Map<String, dynamic>? findThoughtLevelConfig(AcpNewSessionResult session) {
    Map<String, dynamic>? effort;
    Map<String, dynamic>? reasoning;
    for (final option in session.configOptions) {
      if (option["category"] != "thought_level") continue;
      final id = option["id"];
      if (id == "effort") effort = option;
      if (id == "reasoning") reasoning = option;
    }
    if (reasoning != null && _hasMultiLevelOptions(reasoning)) return reasoning;
    if (effort != null && _hasMultiLevelOptions(effort)) return effort;
    return null;
  }

  /// Resolves a mode id from either the ACP `value` or the human `name`.
  static String? resolveModeId(
    List<Map<String, dynamic>> modes,
    String? agent,
  ) {
    if (agent == null || agent.isEmpty) return null;
    if (hasOption(modes, agent)) return agent;
    for (final mode in modes) {
      if (mode["name"] == agent && mode["value"] is String) {
        return mode["value"] as String;
      }
    }
    return null;
  }

  static bool _hasMultiLevelOptions(Map<String, dynamic> config) {
    final opts = options(config);
    if (opts.length <= 1) return false;
    if (opts.length == 2) {
      final values = opts.map((o) => o["value"]).whereType<String>().toSet();
      if (values.containsAll({"true", "false"}) || values.containsAll({"on", "off"})) {
        return false;
      }
    }
    return true;
  }
}
