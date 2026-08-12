import "dart:io" show Platform;

import "package:path/path.dart" as path;

import "platform_target.dart";

/// Resolves the current user's home directory from platform environment values.
///
/// Prefers `USERPROFILE` on Windows and `HOME` elsewhere, then falls back to
/// the other value. Missing and whitespace-only values are ignored.
String? resolveUserHomeDirectory({required Map<String, String> environment}) {
  final keys = Platform.isWindows ? const ["USERPROFILE", "HOME"] : const ["HOME", "USERPROFILE"];
  for (final key in keys) {
    final value = environment[key];
    if (value != null && value.trim().isNotEmpty) return value;
  }
  return null;
}

/// The single canonical Sesori application data directory for the host bridge.
///
/// `<LOCALAPPDATA>/sesori` on Windows, `<HOME>/.local/share/sesori` elsewhere.
/// One resolution shared by every consumer (the auth token store, the SQLite
/// database, …) so the bridge never disagrees with itself about where its files
/// live. Throws [StateError] when the platform's home environment variable is
/// unset.
String sesoriDataDirectory() {
  if (Platform.isWindows) {
    final localAppData = Platform.environment["LOCALAPPDATA"];
    if (localAppData == null || localAppData.isEmpty) {
      throw StateError("LOCALAPPDATA environment variable not set");
    }
    return "$localAppData/sesori";
  }
  final homeDir = resolveUserHomeDirectory(environment: Platform.environment);
  if (homeDir == null) {
    throw StateError("HOME environment variable not set");
  }
  return "$homeDir/.local/share/sesori";
}

/// Resolves the persistent attachment root shared by every bridge data directory
/// for the current OS user.
String sesoriAttachmentsDirectory() => resolveSesoriAttachmentsDirectory(
  environment: Platform.environment,
  operatingSystem: PlatformOs.fromOperatingSystem(
    operatingSystem: Platform.operatingSystem,
  ),
);

/// Resolves the shared attachment root for an explicit environment and OS.
///
/// Linux intentionally honors an absolute `XDG_DATA_HOME` even though the older
/// [sesoriDataDirectory] convention predates that support. Attachments are a
/// new platform-native store rather than another account-bound data directory.
String resolveSesoriAttachmentsDirectory({
  required Map<String, String> environment,
  required PlatformOs operatingSystem,
}) {
  final pathContext = operatingSystem == PlatformOs.windows
      ? path.Context(style: path.Style.windows)
      : path.Context(style: path.Style.posix);
  final xdgDataHome = _nonBlank(environment["XDG_DATA_HOME"]);
  return switch (operatingSystem) {
    PlatformOs.macos => pathContext.join(
      _requireUserHome(environment: environment),
      "Library",
      "Application Support",
      "Sesori Attachments",
    ),
    PlatformOs.linux => pathContext.join(
      xdgDataHome != null && pathContext.isAbsolute(xdgDataHome)
          ? xdgDataHome
          : pathContext.join(
              _requireUserHome(environment: environment),
              ".local",
              "share",
            ),
      "sesori-attachments",
    ),
    PlatformOs.windows => pathContext.join(
      _nonBlank(environment["LOCALAPPDATA"]) ?? (throw StateError("LOCALAPPDATA environment variable not set")),
      "Sesori Attachments",
    ),
  };
}

String _requireUserHome({required Map<String, String> environment}) =>
    resolveUserHomeDirectory(environment: environment) ?? (throw StateError("HOME environment variable not set"));

String? _nonBlank(String? value) => value == null || value.trim().isEmpty ? null : value;
