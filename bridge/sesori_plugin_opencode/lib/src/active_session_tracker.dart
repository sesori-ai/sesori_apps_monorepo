import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show ActiveSession, ProjectActivitySummary, wait3;

import "models/session_status.dart";
import "models/sse_event_data.dart";
import "opencode_repository.dart";

class ActiveSessionTracker {
  final OpenCodeRepository _repository;

  final Set<String> _projectWorktrees = {};
  final Map<String, String> _sessionWorktrees = {};
  final Map<String, String> _sessionDirectories = {}; // directory where the session is located
  final Map<String, SessionStatus> _sessionStatuses = {};

  /// Tracks parent IDs for all known sessions.
  /// `null` value = root session, non-null value = parent session ID.
  final Map<String, String?> _sessionParentIds = {};

  Map<String, int> _lastEmittedActiveSessions = {};

  ActiveSessionTracker(this._repository);

  Future<void> coldStart() async {
    final (projects, statuses, sessions) = await wait3(
      _repository.getProjects(),
      _repository.api.getSessionStatuses(),
      _repository.api.listSessions(),
    );

    _projectWorktrees
      ..clear()
      ..addAll(projects.map((p) => p.worktree));

    _sessionWorktrees.clear();
    _sessionDirectories.clear();
    _sessionParentIds.clear();

    // Build directory lookup and parent ID mapping from fetched sessions.
    final sessionDirectories = <String, String>{};
    for (final session in sessions) {
      sessionDirectories[session.id] = session.directory;
      _sessionParentIds[session.id] = session.parentID;
    }

    _sessionDirectories
      ..clear()
      ..addAll(sessionDirectories);

    _sessionStatuses
      ..clear()
      ..addAll(
        Map.fromEntries(
          statuses.entries.where(
            (e) => e.value is SessionStatusBusy || e.value is SessionStatusRetry,
          ),
        ),
      );

    for (final sessionId in _sessionStatuses.keys.toList()) {
      final directory = sessionDirectories[sessionId];
      if (directory == null) continue;
      final worktree = _resolveWorktree(directory);
      if (worktree != null) {
        _sessionWorktrees[sessionId] = worktree;
      }
    }

    _lastEmittedActiveSessions = _activeSessionCounts;
  }

  bool handleEvent(SseEventData event, String? directory) {
    var forceReemit = false;

    switch (event) {
      case SseSessionCreated():
        _sessionDirectories[event.info.id] = event.info.directory;
        _updateSessionWorktree(event.info.id, event.info.directory);
        final prevParentId = _sessionParentIds[event.info.id];
        _sessionParentIds[event.info.id] = event.info.parentID;
        // Parent metadata changed for an active session — grouping may differ
        // even though per-worktree counts haven't changed.
        if (_sessionStatuses.containsKey(event.info.id) && prevParentId != event.info.parentID) {
          forceReemit = true;
        }
      case SseSessionUpdated():
        _sessionDirectories[event.info.id] = event.info.directory;
        _updateSessionWorktree(event.info.id, event.info.directory);
        final prevParentId = _sessionParentIds[event.info.id];
        _sessionParentIds[event.info.id] = event.info.parentID;
        if (_sessionStatuses.containsKey(event.info.id) && prevParentId != event.info.parentID) {
          forceReemit = true;
        }
      case SseSessionDeleted():
        _sessionDirectories.remove(event.info.id);
        _sessionWorktrees.remove(event.info.id);
        _sessionStatuses.remove(event.info.id);
        _sessionParentIds.remove(event.info.id);
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

    final next = _activeSessionCounts;
    if (!forceReemit && _mapsEqual(_lastEmittedActiveSessions, next)) return false;
    _lastEmittedActiveSessions = next;
    return true;
  }

  void reset() {
    _projectWorktrees.clear();
    _sessionWorktrees.clear();
    _sessionDirectories.clear();
    _sessionStatuses.clear();
    _sessionParentIds.clear();
    _lastEmittedActiveSessions = {};
  }

  /// Register a known session -> directory mapping (e.g., after session creation).
  void registerSession({required String sessionId, required String directory}) {
    _sessionDirectories[sessionId] = directory;
  }

  /// Look up the directory for a session. Returns null if unknown.
  String? getSessionDirectory({required String sessionId}) {
    return _sessionDirectories[sessionId];
  }

  List<ProjectActivitySummary> buildSummary() {
    // Partition active (busy/retry) sessions into root vs child.
    final activeRoots = <String>{};
    final activeChildrenByParent = <String, List<String>>{};

    for (final sessionId in _sessionStatuses.keys) {
      final parentId = _sessionParentIds[sessionId];
      if (parentId == null) {
        // Root session (or unknown parent — treated as root).
        activeRoots.add(sessionId);
      } else {
        // Child session — only include if parent is a known root (direct descendant).
        // A "known root" is a session we've observed whose own parentId is null.
        // Use containsKey to distinguish "known root" from "never observed".
        if (_sessionParentIds.containsKey(parentId) && _sessionParentIds[parentId] == null) {
          activeChildrenByParent.putIfAbsent(parentId, () => []).add(sessionId);
        }
        // Parent not in _sessionParentIds → never observed → orphan → ignore.
        // Parent's parentId != null → deeper nesting → ignore.
      }
    }

    // Merge: roots that are directly active + idle roots with active children.
    final allActiveRoots = <String>{...activeRoots};
    activeChildrenByParent.keys.forEach(allActiveRoots.add);

    // Build ActiveSession per root, grouped by worktree.
    final byWorktree = <String, List<ActiveSession>>{};
    for (final rootId in allActiveRoots) {
      var worktree = _sessionWorktrees[rootId];
      // Parent may not have a worktree if we only observed its children
      // (e.g. bridge reconnected after the root session was created).
      // Fall back to any child's worktree — children share the same project.
      if (worktree == null) {
        final children = activeChildrenByParent[rootId];
        if (children != null) {
          for (final childId in children) {
            worktree = _sessionWorktrees[childId];
            if (worktree != null) break;
          }
        }
      }
      if (worktree == null) {
        Log.w("buildSummary: no worktree for session $rootId");
        continue;
      }
      byWorktree
          .putIfAbsent(worktree, () => [])
          .add(
            ActiveSession(
              id: rootId,
              mainAgentRunning: activeRoots.contains(rootId),
              childSessionIds: activeChildrenByParent[rootId] ?? [],
            ),
          );
    }

    return byWorktree.entries
        .map(
          (e) => ProjectActivitySummary(
            id: e.key,
            activeSessions: e.value,
          ),
        )
        .toList();
  }

  /// Raw count of all busy/retry sessions per worktree.
  ///
  /// Used for change detection only — counts both root and child sessions so
  /// that any status change triggers a summary rebuild.
  Map<String, int> get _activeSessionCounts {
    final counts = <String, int>{};
    for (final entry in _sessionStatuses.entries) {
      final worktree = _sessionWorktrees[entry.key];
      if (worktree == null) continue;
      counts[worktree] = (counts[worktree] ?? 0) + 1;
    }
    return counts;
  }

  /// Exposed for testing: raw count of all busy/retry sessions per worktree.
  Map<String, int> get activeSessions => _activeSessionCounts;

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
