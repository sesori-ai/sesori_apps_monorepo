import "package:args/args.dart";

class BridgeCliOptions {
  final List<String> cliArgs;
  final String relayUrl;

  /// Which coding-agent backend this bridge instance drives. One backend per
  /// process; validated against the backend registry's ids via the
  /// `--backend` allowed list at parse time.
  final String backendId;
  final int? port;
  final bool noAutoStart;
  final String password;
  final String opencodeBin;
  final String codexBin;
  final int codexPort;
  final String cursorBin;
  final String authBackendUrl;
  final bool forceLogin;
  final int? debugPort;
  final String logLevelName;

  const BridgeCliOptions({
    required this.cliArgs,
    required this.relayUrl,
    required this.backendId,
    required this.port,
    required this.noAutoStart,
    required this.password,
    required this.opencodeBin,
    required this.codexBin,
    required this.codexPort,
    required this.cursorBin,
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
      backendId: results["backend"] as String,
      port: portRaw == null || portRaw.isEmpty ? null : int.parse(portRaw),
      noAutoStart: noAutoStart,
      password: results["password"] as String,
      opencodeBin: results["opencode-bin"] as String,
      codexBin: results["codex-bin"] as String,
      codexPort: int.parse(results["codex-port"] as String),
      cursorBin: results["cursor-bin"] as String,
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
