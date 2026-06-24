import "dart:io" show Platform;

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
  final homeDir = Platform.environment["HOME"];
  if (homeDir == null || homeDir.isEmpty) {
    throw StateError("HOME environment variable not set");
  }
  return "$homeDir/.local/share/sesori";
}
