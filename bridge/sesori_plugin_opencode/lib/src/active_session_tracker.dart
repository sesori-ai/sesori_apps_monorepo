import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show ActiveSession, ProjectActivitySummary;

import "models/pending_permission.dart";
import "models/pending_question.dart";
import "models/session_status.dart";
import "models/sse_event_data.dart";
import "opencode_repository.dart";

class ActiveSessionTracker {
  final OpenCodeRepository _repository;

  final Set<String> _projectWorktrees = {};
  final Map<String, String> _sessionWorktrees = {};
  final Map<String, String> _sessionDirectories = {}; // directory where the session is located
  final Map<String, SessionStatus> _sessionStatuses = {};
  final Map<String, Set<String>> _pendingQuestions = {};
  final Map<String, Set<String>> _pendingPermissions = {};

  /// Tracks parent IDs for all known sessions.
  /// `null` value = root session, non-null value = parent session ID.
  final Map<String, String?> _sessionParentIds = {};

  Map<String, int> _lastEmittedActiveSessions = {};
  Set<String> _lastEmittedPendingInputSessions = {};

  ActiveSessionTracker(this._repository);

  Future<void> coldStart() async {
    final (projects, sessions) = await (
      _repository.getProjects(),
      _repository.api.listSessions(roots: false),
    ).wait;

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

    // Fetch statuses per-project-directory so each call targets the correct
    // OpenCode Instance. Errors for individual directories are logged and
    // skipped so that one unavailable project doesn't block the rest.
    final allStatuses = <String, SessionStatus>{};
    final statusFutures = _projectWorktrees.map((worktree) async {
      try {
        final statuses = await _repository.api.getSessionStatuses(directory: worktree);
        for (final entry in statuses.entries) {
          allStatuses[entry.key] = entry.value;
          // Map session → worktree directly from the call context.
          _sessionWorktrees[entry.key] = worktree;
        }
      } catch (e) {
        Log.w("coldStart: failed to fetch session statuses for $worktree: $e");
      }
    });
    await Future.wait(statusFutures);

    _sessionStatuses
      ..clear()
      ..addAll(
        Map.fromEntries(
          allStatuses.entries.where(
            (e) => e.value is SessionStatusBusy || e.value is SessionStatusRetry,
          ),
        ),
      );

    // Also resolve worktrees for sessions whose directory is known but that
    // were not returned by the per-directory status calls (e.g. sessions in
    // subdirectories of a worktree).
    for (final sessionId in _sessionStatuses.keys.toList()) {
      if (_sessionWorktrees.containsKey(sessionId)) continue;
      final directory = sessionDirectories[sessionId];
      if (directory == null) continue;
      final worktree = _resolveWorktree(directory);
      if (worktree != null) {
        _sessionWorktrees[sessionId] = worktree;
      }
    }

    _lastEmittedActiveSessions = _activeSessionCounts;
    _lastEmittedPendingInputSessions = _pendingInputSessions;
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
        _clearPendingInputForSession(event.info.id);
      case SseSessionStatus():
        if (!_sessionWorktrees.containsKey(event.sessionID) && directory != null) {
          _updateSessionWorktree(event.sessionID, directory);
        }
        switch (event.status) {
          case SessionStatusIdle():
            _sessionStatuses.remove(event.sessionID);
            _clearPendingInputForSession(event.sessionID);
          case SessionStatusBusy():
          case SessionStatusRetry():
            _sessionStatuses[event.sessionID] = event.status;
        }
      case SseSessionIdle():
        _sessionStatuses.remove(event.sessionID);
        _clearPendingInputForSession(event.sessionID);
      case SseQuestionAsked():
        _pendingQuestions.putIfAbsent(event.sessionID, () => <String>{}).add(event.id);
      case SseQuestionReplied():
        _removePendingQuestion(sessionId: event.sessionID, requestId: event.requestID);
      case SseQuestionRejected():
        _removePendingQuestion(sessionId: event.sessionID, requestId: event.requestID);
      case SsePermissionAsked():
        _pendingPermissions.putIfAbsent(event.sessionID, () => <String>{}).add(event.requestID);
      case SsePermissionReplied():
        _removePendingPermission(sessionId: event.sessionID, requestId: event.requestID);
      default:
        return false;
    }

    final next = _activeSessionCounts;
    final nextPendingInputSessions = _pendingInputSessions;
    if (!forceReemit &&
        _mapsEqual(_lastEmittedActiveSessions, next) &&
        _setsEqual(_lastEmittedPendingInputSessions, nextPendingInputSessions)) {
      return false;
    }
    _lastEmittedActiveSessions = next;
    _lastEmittedPendingInputSessions = nextPendingInputSessions;
    return true;
  }

  void reset() {
    _projectWorktrees.clear();
    _sessionWorktrees.clear();
    _sessionDirectories.clear();
    _sessionStatuses.clear();
    _sessionParentIds.clear();
    _pendingQuestions.clear();
    _pendingPermissions.clear();
    _lastEmittedActiveSessions = {};
    _lastEmittedPendingInputSessions = {};
  }

  void populatePendingQuestions({required List<PendingQuestion> questions}) {
    _pendingQuestions
      ..clear()
      ..addEntries(_groupBySessionId(questions.map((q) => (q.sessionID, q.id))).entries);
    _lastEmittedPendingInputSessions = _pendingInputSessions;
  }

  void populatePendingPermissions({required List<PendingPermission> permissions}) {
    _pendingPermissions
      ..clear()
      ..addEntries(_groupBySessionId(permissions.map((p) => (p.sessionID, p.id))).entries);
    _lastEmittedPendingInputSessions = _pendingInputSessions;
  }

  /// Replaces the set of known project worktrees and re-resolves worktree
  /// mappings for any active sessions that currently lack one.
  ///
  /// Called from [OpenCodePlugin.getProjects] to keep the tracker's worktree
  /// knowledge in sync with the latest project list. This is important because
  /// [coldStart] may run before all projects are known (e.g. fresh OpenCode
  /// install), and new projects discovered later would otherwise be invisible
  /// to the activity summary.
  bool updateProjectWorktrees({required Set<String> worktrees}) {
    _projectWorktrees
      ..clear()
      ..addAll(worktrees);

    // Re-resolve worktrees for active sessions that don't have one yet.
    for (final sessionId in _sessionStatuses.keys.toList()) {
      if (_sessionWorktrees.containsKey(sessionId)) continue;
      final directory = _sessionDirectories[sessionId];
      if (directory == null) continue;
      final worktree = _resolveWorktree(directory);
      if (worktree != null) {
        _sessionWorktrees[sessionId] = worktree;
      }
    }

    final nextActive = _activeSessionCounts;
    final nextPending = _pendingInputSessions;

    if (_mapsEqual(_lastEmittedActiveSessions, nextActive) &&
        _setsEqual(_lastEmittedPendingInputSessions, nextPending)) {
      return false;
    }

    _lastEmittedActiveSessions = nextActive;
    _lastEmittedPendingInputSessions = nextPending;
    return true;
  }

  /// Register a known session -> directory mapping (e.g., after session creation).
  void registerSession({required String sessionId, required String directory}) {
    _sessionDirectories[sessionId] = directory;
  }

  /// Look up the directory for a session. Returns null if unknown.
  String? getSessionDirectory({required String sessionId}) {
    return _sessionDirectories[sessionId];
  }

  /// Resolves the canonical worktree for a raw session directory.
  String? resolveProjectWorktree({required String directory}) {
    return _resolveWorktree(directory);
  }

  /// Returns the current status of every session the tracker considers
  /// active (busy or retry).
  ///
  /// This map is maintained in real time by SSE events and is the most
  /// accurate source of session status. Sessions that are idle are absent
  /// from the map.
  Map<String, SessionStatus> getActiveStatuses() {
    return Map.unmodifiable(_sessionStatuses);
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
      final children = activeChildrenByParent[rootId] ?? const <String>[];
      byWorktree
          .putIfAbsent(worktree, () => [])
          .add(
            ActiveSession(
              id: rootId,
              mainAgentRunning: activeRoots.contains(rootId),
              awaitingInput: _rootHasPendingInput(rootId, children),
              childSessionIds: children,
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

  bool _hasPendingInput(String sessionId) {
    return (_pendingQuestions[sessionId]?.isNotEmpty ?? false) || (_pendingPermissions[sessionId]?.isNotEmpty ?? false);
  }

  /// Returns true if the root session OR any of its direct child sessions
  /// has pending input (question or permission).
  ///
  /// Child sessions are included so that sub-agent questions/permissions
  /// surface on the root session row in the session list.
  bool _rootHasPendingInput(String rootId, List<String> childIds) {
    if (_hasPendingInput(rootId)) return true;
    return childIds.any(_hasPendingInput);
  }

  /// Raw set of session IDs (including children) that currently have any
  /// pending input. Used only for change detection — re-emit triggers when
  /// this set changes, even if active-session counts did not.
  Set<String> get _pendingInputSessions => {
    ..._pendingQuestions.keys,
    ..._pendingPermissions.keys,
  };

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

  Map<String, Set<String>> _groupBySessionId(Iterable<(String, String)> sessionIdAndEntryId) {
    final grouped = <String, Set<String>>{};
    for (final (sessionId, entryId) in sessionIdAndEntryId) {
      grouped.putIfAbsent(sessionId, () => <String>{}).add(entryId);
    }
    return grouped;
  }

  void _removePendingQuestion({required String sessionId, required String requestId}) {
    final questionIds = _pendingQuestions[sessionId];
    if (questionIds == null) return;
    questionIds.remove(requestId);
    if (questionIds.isEmpty) {
      _pendingQuestions.remove(sessionId);
    }
  }

  void _removePendingPermission({required String sessionId, required String requestId}) {
    final requestIds = _pendingPermissions[sessionId];
    if (requestIds == null) return;
    requestIds.remove(requestId);
    if (requestIds.isEmpty) {
      _pendingPermissions.remove(sessionId);
    }
  }

  void _clearPendingInputForSession(String sessionId) {
    _pendingQuestions.remove(sessionId);
    _pendingPermissions.remove(sessionId);
  }

  bool _mapsEqual(Map<String, int> a, Map<String, int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  bool _setsEqual(Set<String> a, Set<String> b) {
    if (identical(a, b)) return true;
    return a.length == b.length && a.containsAll(b);
  }
}
