import "package:meta/meta.dart";

/// Cheap, synchronous, side-effect-free facts about a live plugin instance.
///
/// Returned by `BridgePlugin.describe()`. The bridge uses this for its
/// startup "Target:" log line and for debugging output; it must never block
/// or touch the network.
@immutable
class PluginDiagnostics {
  const PluginDiagnostics({
    required this.pluginId,
    this.endpoint,
    this.details = const {},
  });

  /// The plugin's stable identifier (e.g. `"opencode"`).
  final String pluginId;

  /// Where the plugin's backend lives, when it has an address
  /// (e.g. `"http://127.0.0.1:4096"`). `null` for plugins without one.
  final String? endpoint;

  /// Free-form additional facts (version, mode, state directory).
  ///
  /// Held by reference (the constructor is const, so a defensive copy is
  /// impossible); pass a const or unshared map and do not mutate it after
  /// construction.
  final Map<String, String> details;

  @override
  String toString() {
    final target = endpoint == null ? pluginId : "$pluginId @ $endpoint";
    if (details.isEmpty) {
      return target;
    }
    final facts = details.entries.map((entry) => "${entry.key}: ${entry.value}").join(", ");
    return "$target ($facts)";
  }
}
