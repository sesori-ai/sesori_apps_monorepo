import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show ProjectActivitySummary, wait2;

import "models/session_status.dart";
import "models/sse_event_data.dart";
import "opencode_repository.dart";

class ActiveSessionTracker {
  final OpenCodeRepository _repository;

  final Set<String> _projectWorktrees = {};
  final Map<String, String> _sessionWorktrees = {};
  final Map<String, SessionStatus> _sessionStatuses = {};
  Map<String, int> _lastEmittedActiveSessions = {};

  ActiveSessionTracker(this._repository);

  Future<void> coldStart() async {
    final (projects, statuses) = await wait2(
      _repository.getProjects(),
      _repository.api.getSessionStatuses(),
    );

    _projectWorktrees
      ..clear()
      ..addAll(projects.map((p) => p.worktree));

    _sessionWorktrees.clear();

    _sessionStatuses
      ..clear()
      ..addAll(
        Map.fromEntries(
          statuses.entries.where(
            (e) => e.value is SessionStatusBusy || e.value is SessionStatusRetry,
          ),
        ),
      );

    for (final entry in _sessionStatuses.keys.toList()) {
      final worktree = _resolveWorktree(entry);
      if (worktree != null) {
        _sessionWorktrees[entry] = worktree;
      }
    }

    _lastEmittedActiveSessions = activeSessions;
  }

  bool handleEvent(SseEventData event, String? directory) {
    switch (event) {
      case SseSessionCreated():
        _updateSessionWorktree(event.info.id, event.info.directory);
      case SseSessionUpdated():
        _updateSessionWorktree(event.info.id, event.info.directory);
      case SseSessionDeleted():
        _sessionWorktrees.remove(event.info.id);
        _sessionStatuses.remove(event.info.id);
      case SseSessionStatus():
        if (!_sessionWorktrees.containsKey(event.sessionID) && directory != null) {
          _updateSessionWorktree(event.sessionID, directory);
        }
        switch (event.status) {
          case SessionStatusIdle():
            _sessionStatuses.remove(event.sessionID);
          case SessionStatusBusy():
          case SessionStatusRetry():
            _sessionStatuses[event.sessionID] = event.status;
        }
      case SseSessionIdle():
        _sessionStatuses.remove(event.sessionID);
      default:
        return false;
    }

    final next = activeSessions;
    if (_mapsEqual(_lastEmittedActiveSessions, next)) return false;
    _lastEmittedActiveSessions = next;
    return true;
  }

  void reset() {
    _projectWorktrees.clear();
    _sessionWorktrees.clear();
    _sessionStatuses.clear();
    _lastEmittedActiveSessions = {};
  }

  List<ProjectActivitySummary> buildSummary() {
    // Collect session IDs per worktree
    final sessionIdsByWorktree = <String, List<String>>{};
    for (final entry in _sessionStatuses.entries) {
      final worktree = _sessionWorktrees[entry.key];
      if (worktree == null) {
        Log.w("buildSummary: no worktree for session ${entry.key}");
        continue;
      }
      sessionIdsByWorktree.putIfAbsent(worktree, () => []).add(entry.key);
    }

    return activeSessions.entries
        .map(
          (e) => ProjectActivitySummary(
            worktree: e.key,
            activeSessions: e.value,
            activeSessionIds: sessionIdsByWorktree[e.key] ?? [],
          ),
        )
        .toList();
  }

  Map<String, int> get activeSessions {
    final counts = <String, int>{};
    for (final entry in _sessionStatuses.entries) {
      final worktree = _sessionWorktrees[entry.key];
      if (worktree == null) continue;
      counts[worktree] = (counts[worktree] ?? 0) + 1;
    }
    return counts;
  }

  String? _resolveWorktree(String directory) {
    final normalizedDirectory = _normalizePath(directory);
    String? bestMatch;
    for (final worktree in _projectWorktrees) {
      final normalizedWorktree = _normalizePath(worktree);
      if (normalizedDirectory == normalizedWorktree || normalizedDirectory.startsWith("$normalizedWorktree/")) {
        if (bestMatch == null || normalizedWorktree.length > _normalizePath(bestMatch).length) {
          bestMatch = worktree;
        }
      }
    }
    return bestMatch;
  }

  String _normalizePath(String path) => path.replaceAll(r"\", "/");

  void _updateSessionWorktree(String sessionID, String directory) {
    final worktree = _resolveWorktree(directory);
    if (worktree == null) {
      _sessionWorktrees.remove(sessionID);
      return;
    }
    _sessionWorktrees[sessionID] = worktree;
  }

  bool _mapsEqual(Map<String, int> a, Map<String, int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}
