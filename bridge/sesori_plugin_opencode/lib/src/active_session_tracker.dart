import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show ActiveSession, ProjectActivitySummary, wait2;

import "models/session_status.dart";
import "models/sse_event_data.dart";
import "opencode_repository.dart";

class ActiveSessionTracker {
  final OpenCodeRepository _repository;

  final Set<String> _projectWorktrees = {};
  final Map<String, String> _sessionWorktrees = {};
  final Map<String, SessionStatus> _sessionStatuses = {};

  /// Tracks parent IDs for all known sessions.
  /// `null` value = root session, non-null value = parent session ID.
  final Map<String, String?> _sessionParentIds = {};

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
    _sessionParentIds.clear();

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

    _lastEmittedActiveSessions = _activeSessionCounts;
  }

  bool handleEvent(SseEventData event, String? directory) {
    switch (event) {
      case SseSessionCreated():
        _updateSessionWorktree(event.info.id, event.info.directory);
        _sessionParentIds[event.info.id] = event.info.parentID;
      case SseSessionUpdated():
        _updateSessionWorktree(event.info.id, event.info.directory);
        _sessionParentIds[event.info.id] = event.info.parentID;
      case SseSessionDeleted():
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
    if (_mapsEqual(_lastEmittedActiveSessions, next)) return false;
    _lastEmittedActiveSessions = next;
    return true;
  }

  void reset() {
    _projectWorktrees.clear();
    _sessionWorktrees.clear();
    _sessionStatuses.clear();
    _sessionParentIds.clear();
    _lastEmittedActiveSessions = {};
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
        // A "known root" is a session whose own parentId is null.
        final grandparentId = _sessionParentIds[parentId];
        if (grandparentId == null) {
          activeChildrenByParent.putIfAbsent(parentId, () => []).add(sessionId);
        }
        // grandparentId != null → deeper nesting → ignore per spec.
        // parentId not in _sessionParentIds → unknown lineage → ignore per spec.
      }
    }

    // Merge: roots that are directly active + idle roots with active children.
    final allActiveRoots = <String>{...activeRoots};
    activeChildrenByParent.keys.forEach(allActiveRoots.add);

    // Build ActiveSession per root, grouped by worktree.
    final byWorktree = <String, List<ActiveSession>>{};
    for (final rootId in allActiveRoots) {
      final worktree = _sessionWorktrees[rootId];
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
