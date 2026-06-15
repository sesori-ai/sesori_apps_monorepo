import "package:meta/meta.dart";

/// Result of a plugin's pre-start availability check.
///
/// Reported by `BridgePluginDescriptor.checkAvailability` before the bridge
/// takes any irreversible startup step — strictly before the cross-instance
/// startup mutex and before `start()`, so a missing backend can never
/// terminate a healthy resident bridge. The bridge core treats
/// [PluginUnavailable] as a fatal, user-facing startup error: it prints
/// [PluginUnavailable.message] via `Console.error` and exits non-zero.
///
/// The check is plugin-owned because *how* a backend proves it is usable is
/// backend-specific (e.g. the OpenCode plugin runs `opencode --version`). The
/// remediation message is authored by the plugin too, so the plugin-agnostic
/// bridge core never needs to know how to install or repair a particular
/// backend.
@immutable
sealed class PluginAvailability {
  const PluginAvailability();
}

/// The plugin's backend is present and usable; startup may proceed.
///
/// This is the default for descriptors that need no local backend (e.g.
/// remote-server plugins), and the result the OpenCode plugin returns in
/// attach mode (`--no-auto-start`), where the user runs the server themselves.
final class PluginAvailable extends PluginAvailability {
  const PluginAvailable();

  @override
  bool operator ==(Object other) => other is PluginAvailable;

  @override
  int get hashCode => (PluginAvailable).hashCode;

  @override
  String toString() => "PluginAvailable";
}

/// The plugin's backend is missing or not usable; startup must abort.
///
/// [message] is a user-facing explanation (shown via `Console.error`, which is
/// never gated by `--log-level`) that tells the user how to make the backend
/// available — e.g. install instructions and a verification command. It is
/// authored by the plugin, never by the bridge core.
final class PluginUnavailable extends PluginAvailability {
  PluginUnavailable({required String message})
    : assert(message.isNotEmpty, "PluginUnavailable.message must not be empty"),
      message = message;

  /// User-facing guidance printed to the user immediately before the bridge
  /// exits non-zero.
  final String message;

  @override
  bool operator ==(Object other) => other is PluginUnavailable && other.message == message;

  @override
  int get hashCode => message.hashCode;

  @override
  String toString() => "PluginUnavailable(message: $message)";
}
