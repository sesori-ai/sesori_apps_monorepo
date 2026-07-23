import "package:path/path.dart" as p;

import "../repositories/cursor_session_storage_repository.dart";

/// Resolves and safely removes Cursor's persisted storage for one session.
class CursorSessionCleanupService {
  CursorSessionCleanupService({
    required CursorSessionStorageRepository repository,
    required Map<String, String> environment,
    required bool isWindows,
  }) : _repository = repository,
       _environment = Map<String, String>.unmodifiable(environment),
       _isWindows = isWindows;

  static const String _sessionsDirectoryName = "acp-sessions";

  final CursorSessionStorageRepository _repository;
  final Map<String, String> _environment;
  final bool _isWindows;

  Future<void> deletePersistedSession({required String sessionId}) async {
    if (sessionId.isEmpty || p.isAbsolute(sessionId) || p.basename(sessionId) != sessionId) {
      throw ArgumentError.value(sessionId, "sessionId", "must be one path segment");
    }

    final sessionsRoot = p.normalize(
      p.absolute(p.join(_resolveConfigDirectory(), _sessionsDirectoryName)),
    );
    final sessionDirectory = p.normalize(p.join(sessionsRoot, sessionId));
    if (!p.isWithin(sessionsRoot, sessionDirectory)) {
      throw ArgumentError.value(sessionId, "sessionId", "resolves outside Cursor session storage");
    }

    if (!_repository.directoryExists(path: sessionDirectory)) return;
    await _repository.deleteDirectory(path: sessionDirectory);
  }

  String _resolveConfigDirectory() {
    final explicit = _configuredValue("CURSOR_CONFIG_DIR");
    if (explicit != null) return explicit;

    final xdg = _configuredValue("XDG_CONFIG_HOME");
    if (xdg != null) return p.join(xdg, "cursor");

    final home = _isWindows
        ? _configuredValue("USERPROFILE") ?? _configuredValue("HOME")
        : _configuredValue("HOME") ?? _configuredValue("USERPROFILE");
    if (home == null) {
      throw StateError("Cannot resolve Cursor config directory: no user home is configured");
    }
    return p.join(home, ".cursor");
  }

  String? _configuredValue(String name) {
    final value = _environment[name];
    return value == null || value.trim().isEmpty ? null : value;
  }
}
