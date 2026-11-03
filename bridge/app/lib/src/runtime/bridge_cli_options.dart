import "dart:io" show Directory, FileSystemEntity, FileSystemEntityType, Platform;

import "package:args/args.dart" show ArgParserException, ArgResults;
import "package:path/path.dart" as path;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show resolveUserHomeDirectory;
import "package:sesori_shared/sesori_shared.dart" show BridgeKind;

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

  /// How this bridge reports its installation to clients: only Sesori Desktop
  /// supervises a bridge, so a supervised bridge is the one it bundles.
  BridgeKind get bridgeKind => isSupervised ? BridgeKind.desktop : BridgeKind.cli;

  factory fromArgResults({
    required List<String> cliArgs,
    required ArgResults results,
    required Map<String, String> environment,
    required String defaultAuthUrl,
    required String defaultDataDirectory,
  }) {
    final authBackendUrl = resolveAuthBackendUrl(
      authBackendFlag: results.option("auth-backend"),
      environment: environment,
      defaultAuthUrl: defaultAuthUrl,
    );
    final debugPortRaw = results.option("debug-port");
    final dataDirectory = resolveDataDirectory(
      dataDirectoryFlag: results.option("data-dir"),
      defaultDataDirectory: defaultDataDirectory,
      environment: environment,
    );

    // Supervised-only option: trim and treat blank as absent. Do NOT validate
    // it here (no URI parse) — strict parse-time validation would risk failing
    // a standalone invocation; it is parsed only when supervised mode is active.
    final controlUrlRaw = results.option("control-url")?.trim();
    final controlUrl = (controlUrlRaw != null && controlUrlRaw.isNotEmpty) ? controlUrlRaw : null;

    return BridgeCliOptions(
      cliArgs: cliArgs,
      relayUrl: _optionWithDefault(results: results, name: "relay"),
      authBackendUrl: authBackendUrl,
      dataDirectory: dataDirectory,
      debugPort: debugPortRaw == null ? null : int.tryParse(debugPortRaw),
      logLevelName: _optionWithDefault(results: results, name: "log-level"),
      controlUrl: controlUrl,
    );
  }

  /// The value of an option registered with `defaultsTo`, which the parser
  /// always fills in.
  static String _optionWithDefault({required ArgResults results, required String name}) =>
      results.option(name) ?? (throw StateError("--$name was registered without a default value."));

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
    required String? authBackendFlag,
    required Map<String, String> environment,
    required String defaultAuthUrl,
  }) {
    final String rawUrl;
    if (authBackendFlag case final flag? when flag.isNotEmpty) {
      rawUrl = flag;
    } else if (environment["AUTH_BACKEND_URL"] case final envValue? when envValue.isNotEmpty) {
      rawUrl = envValue;
    } else {
      rawUrl = defaultAuthUrl;
    }
    return normalizeAuthBackendUrl(url: rawUrl);
  }
}
