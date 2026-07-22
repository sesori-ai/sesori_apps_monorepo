import "dart:io" show Platform;

/// Resolves the current user's home directory from platform environment values.
String? resolveUserHomeDirectory({required Map<String, String> environment}) {
  final home = environment["HOME"];
  if (home != null && home.isNotEmpty) return home;
  final userProfile = environment["USERPROFILE"];
  return userProfile == null || userProfile.isEmpty ? null : userProfile;
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
