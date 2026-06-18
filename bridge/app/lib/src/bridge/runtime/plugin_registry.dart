import "package:cursor_plugin/cursor_plugin.dart" show CursorPluginDescriptor;
import "package:opencode_plugin/opencode_plugin.dart" show OpenCodePluginDescriptor;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginDescriptor;

import "../../server/host/plugin_state_directory.dart" show openCodePluginId;

/// Every plugin this bridge build knows how to run.
///
/// Descriptors are const and side-effect free — registered is *not* started.
/// `bin/bridge.dart` reads the parse-time surface (`id`, `options`,
/// `validateConfig`) straight off the selected descriptor, and the runner
/// later calls its `start(host)` under the startup mutex.
const List<BridgePluginDescriptor> knownPlugins = [
  OpenCodePluginDescriptor(),
  CursorPluginDescriptor(),
];

/// The plugin used when neither `--plugin` nor `enabledPlugins` selects one,
/// so existing installs see zero change.
const String defaultPluginId = openCodePluginId;

/// Selection cannot be resolved from the bridge settings — the user must fix
/// `enabledPlugins`. Command-line problems are never reported through this:
/// they surface as the parser's own usage errors on the full parse.
class PluginSelectionException implements Exception {
  const PluginSelectionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resolves which plugin's CLI surface the bridge registers into its
/// argument parser — the first pass of the two-pass parse: `--plugin` is
/// scanned out of the raw argv, the full parser is then built from the
/// winning descriptor and parses everything (including `--plugin` itself,
/// whose `allowed:` list produces the usage error for unknown ids).
///
/// Precedence: `--plugin` on the command line, then `enabledPlugins` from
/// the bridge settings, then the injected default id.
class PluginSelector {
  const PluginSelector({
    required List<BridgePluginDescriptor> knownPlugins,
    required String defaultPluginId,
    required Future<List<String>?> Function() loadEnabledPlugins,
  }) : _knownPlugins = knownPlugins,
       _defaultPluginId = defaultPluginId,
       _loadEnabledPlugins = loadEnabledPlugins;

  final List<BridgePluginDescriptor> _knownPlugins;
  final String _defaultPluginId;

  /// Reads `enabledPlugins` from the bridge settings; null means unset.
  /// Only invoked when the command line selects nothing. Must not throw and
  /// must not create files — selection also runs for `--help` and `logout`.
  final Future<List<String>?> Function() _loadEnabledPlugins;

  /// Resolves the descriptor for raw process [args] (pre `run`-insertion;
  /// the scan is insensitive to the implicit-command rewrite, which only
  /// ever prepends a token).
  ///
  /// The scan itself never raises a user-facing error: an unknown or missing
  /// `--plugin` value resolves to a fallback descriptor so the parser still
  /// gets built, and the full parse then reports it (`allowed:` violation or
  /// missing argument).
  Future<BridgePluginDescriptor> resolve({required List<String> args}) async {
    final cliSelection = _scanPluginFlag(args);
    if (cliSelection != null) {
      return _descriptorById(cliSelection) ?? _fallback;
    }

    final enabledPlugins = await _loadEnabledPlugins();
    if (enabledPlugins == null || enabledPlugins.isEmpty) {
      return _fallback;
    }
    if (enabledPlugins.length > 1) {
      throw PluginSelectionException(
        "Bridge settings enable ${enabledPlugins.length} plugins "
        '(${enabledPlugins.join(", ")}), but the bridge supports exactly one '
        'active plugin. Set "enabledPlugins" to a single entry.',
      );
    }
    final enabled = enabledPlugins.single;
    final descriptor = _descriptorById(enabled);
    if (descriptor == null) {
      throw PluginSelectionException(
        'Bridge settings enable unknown plugin "$enabled". Known plugins: '
        '${_knownPlugins.map((plugin) => plugin.id).join(", ")}. Update '
        '"enabledPlugins" in the bridge config (sesori-bridge config).',
      );
    }
    return descriptor;
  }

  BridgePluginDescriptor get _fallback {
    final fallback = _descriptorById(_defaultPluginId);
    if (fallback == null) {
      // Only reachable by miswiring the selector itself — fail with a
      // diagnosis rather than a bare null-check error.
      throw StateError(
        'Default plugin "$_defaultPluginId" is not among the known plugins: '
        '${_knownPlugins.map((plugin) => plugin.id).join(", ")}.',
      );
    }
    return fallback;
  }

  BridgePluginDescriptor? _descriptorById(String id) {
    for (final plugin in _knownPlugins) {
      if (plugin.id == id) {
        return plugin;
      }
    }
    return null;
  }

  /// The value of the last `--plugin` occurrence before a standalone `--`
  /// terminator, or null when the command line selects nothing.
  ///
  /// Mirrors `package:args` long-option mechanics so both passes agree:
  /// `--plugin=<id>` and `--plugin <id>` forms, exact name match (args never
  /// abbreviates long names), last occurrence wins, and the space form
  /// consumes the next token unconditionally. Not mirrored: a `--plugin`
  /// token that the parser would swallow as a *preceding* value option's
  /// argument (e.g. `--password --plugin`) is read as a selection here —
  /// pathological input; the full parse still has the last word on errors.
  static String? _scanPluginFlag(List<String> args) {
    String? value;
    for (var i = 0; i < args.length; i++) {
      final token = args[i];
      if (token == "--") {
        break;
      }
      if (token == "--plugin") {
        if (i + 1 < args.length) {
          value = args[i + 1];
          i++;
        }
      } else if (token.startsWith("--plugin=")) {
        value = token.substring("--plugin=".length);
      }
    }
    return value;
  }
}
