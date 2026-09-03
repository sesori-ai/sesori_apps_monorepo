import "dart:io" show Directory, FileSystemEntity, FileSystemEntityType, Platform;

import "package:args/args.dart" show ArgParserException, ArgResults;
import "package:path/path.dart" as path;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show resolveUserHomeDirectory;

import "../foundation/auth_backend_url.dart";

class const BridgeCliOptions({
  required final List<String> cliArgs,
  required final String relayUrl,
  required final String authBackendUrl,
  required final String dataDirectory,
  required final int? debugPort,
  required final String logLevelName,

  /// Loopback control-channel URL supplied by a GUI supervisor via
  /// `--control-url`. `null` in standalone mode. See [isSupervised].
  required final String? controlUrl,
}) {
  /// Whether the bridge runs under a GUI supervisor (the desktop app). True
  /// exactly when `--control-url` was supplied; in that mode the bridge
  /// connects the loopback control channel and the GUI is its token authority
  /// and lifecycle owner. Absent ⇒ unchanged standalone CLI behaviour.
  bool get isSupervised => controlUrl != null;

  factory fromArgResults({
    required List<String> cliArgs,
    required ArgResults results,
    required Map<String, String> environment,
    required String defaultAuthUrl,
    required String defaultDataDirectory,
  }) {
    final authBackendFlag = results["auth-backend"] as String;
    final authBackendUrl = resolveAuthBackendUrl(
      authBackendFlag: authBackendFlag,
      environment: environment,
      defaultAuthUrl: defaultAuthUrl,
    );
    final debugPortRaw = results["debug-port"] as String;
    final dataDirectory = resolveDataDirectory(
      dataDirectoryFlag: results["data-dir"] as String?,
      defaultDataDirectory: defaultDataDirectory,
      environment: environment,
    );

    // Supervised-only option: trim and treat blank as absent. Do NOT validate
    // it here (no URI parse) — strict parse-time validation would risk failing
    // a standalone invocation; it is parsed only when supervised mode is active.
    final controlUrlRaw = (results["control-url"] as String?)?.trim();
    final controlUrl = (controlUrlRaw != null && controlUrlRaw.isNotEmpty) ? controlUrlRaw : null;

    return BridgeCliOptions(
      cliArgs: cliArgs,
      relayUrl: results["relay"] as String,
      authBackendUrl: authBackendUrl,
      dataDirectory: dataDirectory,
      debugPort: debugPortRaw.isNotEmpty ? int.tryParse(debugPortRaw) : null,
      logLevelName: results["log-level"] as String,
      controlUrl: controlUrl,
    );
  }

  static String resolveDataDirectory({
    required String? dataDirectoryFlag,
    required String defaultDataDirectory,
    required Map<String, String> environment,
  }) {
    if (dataDirectoryFlag == null) return defaultDataDirectory;
    if (dataDirectoryFlag.trim().isEmpty) {
      throw ArgParserException("--data-dir must not be empty.");
    }
    final expandedDataDirectory = _expandHomeDirectory(
      dataDirectory: dataDirectoryFlag,
      environment: environment,
    );
    return path.normalize(path.absolute(expandedDataDirectory));
  }

  static String _expandHomeDirectory({
    required String dataDirectory,
    required Map<String, String> environment,
  }) {
    if (dataDirectory != "~" &&
        !dataDirectory.startsWith("~/") &&
        !dataDirectory.startsWith("~${Platform.pathSeparator}")) {
      return dataDirectory;
    }

    final homeDirectory = resolveUserHomeDirectory(environment: environment);
    if (homeDirectory == null) {
      throw ArgParserException("Cannot expand --data-dir: home directory is not set.");
    }
    if (dataDirectory == "~") return homeDirectory;
    return path.join(homeDirectory, dataDirectory.substring(2));
  }

  static bool isDefaultDataDirectory({
    required String dataDirectory,
    required String defaultDataDirectory,
  }) {
    return path.equals(
      _dataDirectoryIdentity(dataDirectory),
      _dataDirectoryIdentity(defaultDataDirectory),
    );
  }

  static String _dataDirectoryIdentity(String dataDirectory) {
    final normalized = path.normalize(path.absolute(dataDirectory));
    if (FileSystemEntity.typeSync(normalized, followLinks: true) == FileSystemEntityType.notFound) {
      return normalized;
    }
    return Directory(normalized).resolveSymbolicLinksSync();
  }

  /// Resolves the auth backend URL from the CLI flag, the
  /// `AUTH_BACKEND_URL` environment variable, or the default, in that order.
  static String resolveAuthBackendUrl({
    required String authBackendFlag,
    required Map<String, String> environment,
    required String defaultAuthUrl,
  }) {
    final String rawUrl;
    if (authBackendFlag.isNotEmpty) {
      rawUrl = authBackendFlag;
    } else if (environment["AUTH_BACKEND_URL"] case final envValue? when envValue.isNotEmpty) {
      rawUrl = envValue;
    } else {
      rawUrl = defaultAuthUrl;
    }
    return normalizeAuthBackendUrl(url: rawUrl);
  }
}
