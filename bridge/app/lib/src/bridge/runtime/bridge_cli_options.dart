import "package:args/args.dart" show ArgResults;

class BridgeCliOptions {
  final List<String> cliArgs;
  final String relayUrl;
  final String authBackendUrl;
  final int? debugPort;
  final String logLevelName;
  final List<String> enabledPluginIds;
  final List<String> importPluginIds;

  /// Loopback control-channel URL supplied by a GUI supervisor via
  /// `--control-url`. `null` in standalone mode. See [isSupervised].
  final String? controlUrl;

  const BridgeCliOptions({
    required this.cliArgs,
    required this.relayUrl,
    required this.authBackendUrl,
    required this.debugPort,
    required this.logLevelName,
    required this.enabledPluginIds,
    required this.importPluginIds,
    required this.controlUrl,
  });

  /// Whether the bridge runs under a GUI supervisor (the desktop app). True
  /// exactly when `--control-url` was supplied; in that mode the bridge
  /// connects the loopback control channel and the GUI is its token authority
  /// and lifecycle owner. Absent ⇒ unchanged standalone CLI behaviour.
  bool get isSupervised => controlUrl != null;

  factory BridgeCliOptions.fromArgResults({
    required List<String> cliArgs,
    required ArgResults results,
    required Map<String, String> environment,
    required String defaultAuthUrl,
    required List<String> enabledPluginIds,
  }) {
    final authBackendFlag = results["auth-backend"] as String;
    final authBackendUrl = resolveAuthBackendUrl(
      authBackendFlag: authBackendFlag,
      environment: environment,
      defaultAuthUrl: defaultAuthUrl,
    );
    final debugPortRaw = results["debug-port"] as String;

    // Supervised-only option: trim and treat blank as absent. Do NOT validate
    // it here (no URI parse) — strict parse-time validation would risk failing
    // a standalone invocation; it is parsed only when supervised mode is active.
    final controlUrlRaw = (results["control-url"] as String?)?.trim();
    final controlUrl = (controlUrlRaw != null && controlUrlRaw.isNotEmpty) ? controlUrlRaw : null;

    return BridgeCliOptions(
      cliArgs: cliArgs,
      relayUrl: results["relay"] as String,
      authBackendUrl: authBackendUrl,
      debugPort: debugPortRaw.isNotEmpty ? int.tryParse(debugPortRaw) : null,
      logLevelName: results["log-level"] as String,
      enabledPluginIds: List<String>.unmodifiable(enabledPluginIds),
      importPluginIds: List.unmodifiable(results["import-plugin"] as List<String>),
      controlUrl: controlUrl,
    );
  }

  /// Resolves the auth backend URL from the CLI flag, the
  /// `AUTH_BACKEND_URL` environment variable, or the default, in that order.
  static String resolveAuthBackendUrl({
    required String authBackendFlag,
    required Map<String, String> environment,
    required String defaultAuthUrl,
  }) {
    if (authBackendFlag.isNotEmpty) {
      return authBackendFlag;
    }

    final envValue = environment["AUTH_BACKEND_URL"];
    if (envValue != null && envValue.isNotEmpty) {
      return envValue;
    }

    return defaultAuthUrl;
  }
}
