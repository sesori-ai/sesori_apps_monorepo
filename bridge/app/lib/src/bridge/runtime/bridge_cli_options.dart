import "package:args/args.dart";

class BridgeCliOptions {
  final List<String> cliArgs;
  final String relayUrl;
  final int? port;
  final bool noAutoStart;
  final String password;
  final String opencodeBin;
  final String authBackendUrl;
  final bool forceLogin;
  final int? debugPort;
  final String logLevelName;

  const BridgeCliOptions({
    required this.cliArgs,
    required this.relayUrl,
    required this.port,
    required this.noAutoStart,
    required this.password,
    required this.opencodeBin,
    required this.authBackendUrl,
    required this.forceLogin,
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
    final authBackendUrl = _resolveAuthBackendUrl(
      authBackendFlag: authBackendFlag,
      environment: environment,
      defaultAuthUrl: defaultAuthUrl,
    );
    final debugPortRaw = results["debug-port"] as String;
    final portRaw = results["port"] as String?;
    final noAutoStart = results["no-auto-start"] as bool;

    if (noAutoStart && (portRaw == null || portRaw.isEmpty)) {
      throw ArgParserException(
        'The --no-auto-start flag requires --port to be set.',
      );
    }

    return BridgeCliOptions(
      cliArgs: cliArgs,
      relayUrl: results["relay"] as String,
      port: portRaw == null || portRaw.isEmpty ? null : int.parse(portRaw),
      noAutoStart: noAutoStart,
      password: results["password"] as String,
      opencodeBin: results["opencode-bin"] as String,
      authBackendUrl: authBackendUrl,
      forceLogin: results["login"] as bool,
      debugPort: debugPortRaw.isNotEmpty ? int.tryParse(debugPortRaw) : null,
      logLevelName: results["log-level"] as String,
    );
  }

  static String _resolveAuthBackendUrl({
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
