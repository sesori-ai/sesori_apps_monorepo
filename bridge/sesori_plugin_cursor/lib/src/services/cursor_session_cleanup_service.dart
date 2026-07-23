import "dart:io" show FileSystemException;

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

  Future<void> deletePersistedSession({required String backendSessionId}) async {
    if (backendSessionId.isEmpty ||
        p.isAbsolute(backendSessionId) ||
        p.basename(backendSessionId) != backendSessionId) {
      throw ArgumentError.value(
        backendSessionId,
        "backendSessionId",
        "must be one path segment",
      );
    }

    final sessionsRoot = p.normalize(
      p.absolute(p.join(_resolveConfigDirectory(), _sessionsDirectoryName)),
    );
    final sessionDirectory = p.normalize(
      p.join(sessionsRoot, backendSessionId),
    );
    if (!p.isWithin(sessionsRoot, sessionDirectory)) {
      throw ArgumentError.value(
        backendSessionId,
        "backendSessionId",
        "resolves outside Cursor session storage",
      );
    }

    switch (_repository.entryType(path: sessionDirectory)) {
      case CursorSessionStorageEntryType.missing:
        return;
      case CursorSessionStorageEntryType.directory:
        break;
      case CursorSessionStorageEntryType.nonDirectory:
        throw FileSystemException(
          "Cursor session storage is not a directory",
          sessionDirectory,
        );
    }

    try {
      await _repository.deleteDirectory(path: sessionDirectory);
    } on FileSystemException {
      if (_repository.entryType(path: sessionDirectory) == CursorSessionStorageEntryType.missing) {
        return;
      }
      rethrow;
    }
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
