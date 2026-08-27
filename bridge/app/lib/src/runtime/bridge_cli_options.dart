import "dart:io" show Directory, FileSystemEntity, FileSystemEntityType, InternetAddress, InternetAddressType, Platform;

import "package:args/args.dart" show ArgParserException, ArgResults;
import "package:path/path.dart" as path;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show resolveUserHomeDirectory;
import "package:sesori_shared/sesori_shared.dart" show canonicalizeDeviceCanvasTurnUrl, maxDeviceCanvasTurnUrls;

import "../foundation/auth_backend_url.dart";

class const BridgeCliOptions({
  required final List<String> cliArgs,
  required final String relayUrl,
  required final String authBackendUrl,
  required final String dataDirectory,
  required final int? debugPort,
  required final String logLevelName,
  required final List<String> importPluginIds,
  final List<String> deviceCanvasLocalTurnUrls = const <String>[],
  final String? deviceCanvasLocalTurnSecretFile,

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
    final turnOptions = _resolveDeviceCanvasLocalTurnOptions(
      urls: List<String>.from(results["device-canvas-local-turn-url"] as List<String>),
      secretFile: results["device-canvas-local-turn-secret-file"] as String?,
      environment: environment,
    );

    return BridgeCliOptions(
      cliArgs: cliArgs,
      relayUrl: results["relay"] as String,
      authBackendUrl: authBackendUrl,
      dataDirectory: dataDirectory,
      debugPort: debugPortRaw.isNotEmpty ? int.tryParse(debugPortRaw) : null,
      logLevelName: results["log-level"] as String,
      importPluginIds: List.unmodifiable(results["import-plugin"] as List<String>),
      deviceCanvasLocalTurnUrls: turnOptions.urls,
      deviceCanvasLocalTurnSecretFile: turnOptions.secretFile,
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

  static ({List<String> urls, String? secretFile}) _resolveDeviceCanvasLocalTurnOptions({
    required List<String> urls,
    required String? secretFile,
    required Map<String, String> environment,
  }) {
    final secretFileValue = secretFile?.trim();
    final hasUrls = urls.isNotEmpty;
    final hasSecretFile = secretFileValue != null && secretFileValue.isNotEmpty;
    if (hasUrls != hasSecretFile) {
      throw ArgParserException(
        "--device-canvas-local-turn-url and --device-canvas-local-turn-secret-file must be supplied together.",
      );
    }
    if (!hasUrls) return (urls: const <String>[], secretFile: null);
    if (secretFileValue == null) throw StateError("unreachable local TURN option state");
    if (urls.length > maxDeviceCanvasTurnUrls) {
      throw ArgParserException("At most $maxDeviceCanvasTurnUrls --device-canvas-local-turn-url values are allowed.");
    }

    final canonicalUrls = <String>[];
    String? localEndpoint;
    for (final rawUrl in urls) {
      final canonical = canonicalizeDeviceCanvasTurnUrl(rawUrl);
      if (canonical == null) {
        throw ArgParserException("--device-canvas-local-turn-url must be a valid TURN URL.");
      }
      if (canonicalUrls.contains(canonical)) {
        throw ArgParserException("--device-canvas-local-turn-url values must be semantically distinct.");
      }
      final endpoint = _privateDeviceCanvasTurnEndpoint(canonical);
      if (endpoint == null || (localEndpoint != null && localEndpoint != endpoint)) {
        throw ArgParserException(
          "--device-canvas-local-turn-url values must use one private or link-local IP endpoint.",
        );
      }
      localEndpoint = endpoint;
      canonicalUrls.add(canonical);
    }
    final expandedSecretFile = _expandHomeDirectory(
      dataDirectory: secretFileValue,
      environment: environment,
    );
    return (
      urls: List<String>.unmodifiable(canonicalUrls),
      secretFile: path.normalize(path.absolute(expandedSecretFile)),
    );
  }

  static String? _privateDeviceCanvasTurnEndpoint(String canonicalUrl) {
    if (!canonicalUrl.startsWith("turn:")) return null;
    final queryStart = canonicalUrl.indexOf("?");
    if (queryStart < 0) return null;
    final endpoint = canonicalUrl.substring("turn:".length, queryStart);
    final String host;
    if (endpoint.startsWith("[")) {
      final closingBracket = endpoint.indexOf("]");
      if (closingBracket <= 1) return null;
      host = endpoint.substring(1, closingBracket);
    } else {
      final portSeparator = endpoint.lastIndexOf(":");
      if (portSeparator <= 0) return null;
      host = endpoint.substring(0, portSeparator);
    }
    final address = InternetAddress.tryParse(host);
    if (address == null) return null;
    final bytes = address.rawAddress;
    final isPrivate = switch (address.type) {
      InternetAddressType.IPv4 =>
        bytes[0] == 10 ||
            (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
            (bytes[0] == 192 && bytes[1] == 168) ||
            (bytes[0] == 169 && bytes[1] == 254),
      InternetAddressType.IPv6 => bytes[0] & 0xfe == 0xfc || (bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80),
      _ => false,
    };
    return isPrivate ? endpoint : null;
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
