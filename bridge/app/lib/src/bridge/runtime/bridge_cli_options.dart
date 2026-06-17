import "package:args/args.dart" show ArgResults;

class BridgeCliOptions {
  final List<String> cliArgs;
  final String relayUrl;
  final int? port;
  final String password;
  final String authBackendUrl;
  final int? debugPort;
  final String logLevelName;

  const BridgeCliOptions({
    required this.cliArgs,
    required this.relayUrl,
    required this.port,
    required this.password,
    required this.authBackendUrl,
    required this.debugPort,
    required this.logLevelName,
  });

  factory BridgeCliOptions.fromArgResults({
    required List<String> cliArgs,
    required ArgResults results,
    required Map<String, String> environment,
    required String defaultAuthUrl,
  }) {
    final authBackendFlag = results["auth-backend"] as String;
    final authBackendUrl = resolveAuthBackendUrl(
      authBackendFlag: authBackendFlag,
      environment: environment,
      defaultAuthUrl: defaultAuthUrl,
    );
    final debugPortRaw = results["debug-port"] as String;

    // `port` and `password` are plugin-scoped options: the bridge registers
    // only the *selected* plugin's options, so they are present only when that
    // plugin declares them (OpenCode declares both; Codex declares only
    // `port`). Read them defensively so selecting a plugin without one does not
    // throw "Could not find an option named ...".
    final portRaw = results.options.contains("port") ? results["port"] as String? : null;
    final password = results.options.contains("password") ? results["password"] as String : "";

    return BridgeCliOptions(
      cliArgs: cliArgs,
      relayUrl: results["relay"] as String,
      port: portRaw == null || portRaw.isEmpty ? null : int.parse(portRaw),
      password: password,
      authBackendUrl: authBackendUrl,
      debugPort: debugPortRaw.isNotEmpty ? int.tryParse(debugPortRaw) : null,
      logLevelName: results["log-level"] as String,
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
