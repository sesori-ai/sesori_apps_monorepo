import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show normalizeProjectDirectory;

class AcpSessionDirectoryTracker {
  AcpSessionDirectoryTracker({required String launchDirectory})
    : launchDirectory = normalizeProjectDirectory(directory: launchDirectory);

  final String launchDirectory;
  final Map<String, String> _sessionDirectories = {};
  final Set<String> _hintedDirectories = {};

  bool containsSession(String sessionId) => _sessionDirectories.containsKey(sessionId);

  String directoryFor(String sessionId) => _sessionDirectories[sessionId] ?? launchDirectory;

  Set<String> get scanDirectories => {
    launchDirectory,
    ..._hintedDirectories,
    ..._sessionDirectories.values,
  };

  void addHints(Iterable<String> directories) {
    _hintedDirectories.addAll({
      for (final directory in directories)
        if (directory.trim().isNotEmpty) normalizeProjectDirectory(directory: directory),
    });
  }

  String recordAuthoritative({required String sessionId, required String directory}) {
    final canonical = normalizeProjectDirectory(directory: directory);
    _sessionDirectories[sessionId] = canonical;
    return canonical;
  }

  String prime({required String sessionId, required String directory}) {
    final canonical = normalizeProjectDirectory(directory: directory);
    _hintedDirectories.add(canonical);
    _sessionDirectories.putIfAbsent(sessionId, () => canonical);
    return _sessionDirectories[sessionId]!;
  }

  void forgetSession(String sessionId) => _sessionDirectories.remove(sessionId);
}
