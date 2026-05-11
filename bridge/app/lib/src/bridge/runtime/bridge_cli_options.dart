import "package:args/args.dart";

/// Which coding-agent backend this bridge instance drives.
///
/// One backend per bridge process. The opencode plugin and codex plugin
/// ship side-by-side as compiled-in modules; this flag selects which one
/// `runBridgeApp` instantiates.
enum BridgeBackend {
  opencode,
  codex;

  static BridgeBackend parse(String raw) {
    return switch (raw) {
      "opencode" => BridgeBackend.opencode,
      "codex" => BridgeBackend.codex,
      _ => throw ArgumentError.value(raw, "backend", "unsupported backend"),
    };
  }
}

class BridgeCliOptions {
  final List<String> cliArgs;
  final String relayUrl;
  final BridgeBackend backend;
  final int port;
  final bool noAutoStart;
  final String password;
  final String opencodeBin;
  final String codexBin;
  final int codexPort;
  final String authBackendUrl;
  final bool forceLogin;
  final int? debugPort;
  final String logLevelName;

  const BridgeCliOptions({
    required this.cliArgs,
    required this.relayUrl,
    required this.backend,
    required this.port,
    required this.noAutoStart,
    required this.password,
    required this.opencodeBin,
    required this.codexBin,
    required this.codexPort,
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

    return BridgeCliOptions(
      cliArgs: cliArgs,
      relayUrl: results["relay"] as String,
      backend: BridgeBackend.parse(results["backend"] as String),
      port: int.parse(results["port"] as String),
      noAutoStart: results["no-auto-start"] as bool,
      password: results["password"] as String,
      opencodeBin: results["opencode-bin"] as String,
      codexBin: results["codex-bin"] as String,
      codexPort: int.parse(results["codex-port"] as String),
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
