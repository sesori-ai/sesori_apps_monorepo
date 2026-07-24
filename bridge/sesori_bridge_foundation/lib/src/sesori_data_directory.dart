import "dart:io" show Platform;

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
