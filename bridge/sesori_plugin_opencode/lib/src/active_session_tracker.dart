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
  Set<String> _lastEmittedRetrySessions = {};
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
    _lastEmittedRetrySessions = _retryingSessionIds;
    _lastEmittedPendingInputSessions = _pendingInputSessions;
  }

  bool handleEvent(SseEventData event, String? directory) {
    var forceReemit = false;

    switch (event) {
      case SseSessionCreated():
        _sessionDirectories[event.info.id] = event.info.directory;
        _updateSessionWorktree(event.info.id, event.info.directory);
        final wasObserved = _sessionParentIds.containsKey(event.info.id);
        final prevParentId = _sessionParentIds[event.info.id];
        _sessionParentIds[event.info.id] = event.info.parentID;
        // Newly observing a session — even a root, whose parentID is null and so
        // would compare equal to the absent value — or changing its parent link
        // can re-home active descendants between roots without moving the
        // per-worktree counts. Re-emit when this session is itself active or is
        // an ancestor of an active session.
        if ((!wasObserved || prevParentId != event.info.parentID) && _participatesInActiveSubtree(event.info.id)) {
          forceReemit = true;
        }
      case SseSessionUpdated():
        _sessionDirectories[event.info.id] = event.info.directory;
        _updateSessionWorktree(event.info.id, event.info.directory);
        final wasObserved = _sessionParentIds.containsKey(event.info.id);
        final prevParentId = _sessionParentIds[event.info.id];
        _sessionParentIds[event.info.id] = event.info.parentID;
        if ((!wasObserved || prevParentId != event.info.parentID) && _participatesInActiveSubtree(event.info.id)) {
          forceReemit = true;
        }
      case SseSessionDeleted():
        // Deleting an ancestor can orphan an active descendant (changing its
        // root attribution) without moving the per-worktree counts, so capture
        // participation before dropping the metadata.
        final affectedActiveSubtree = _participatesInActiveSubtree(event.info.id);
        _sessionDirectories.remove(event.info.id);
        _sessionWorktrees.remove(event.info.id);
        _sessionStatuses.remove(event.info.id);
        _sessionParentIds.remove(event.info.id);
        _clearPendingInputForSession(event.info.id);
        if (affectedActiveSubtree) {
          forceReemit = true;
        }
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
    final nextRetry = _retryingSessionIds;
    final nextPendingInputSessions = _pendingInputSessions;
    if (!forceReemit &&
        _mapsEqual(_lastEmittedActiveSessions, next) &&
        _setsEqual(_lastEmittedRetrySessions, nextRetry) &&
        _setsEqual(_lastEmittedPendingInputSessions, nextPendingInputSessions)) {
      return false;
    }
    _lastEmittedActiveSessions = next;
    _lastEmittedRetrySessions = nextRetry;
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
    _lastEmittedRetrySessions = {};
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
    final nextRetry = _retryingSessionIds;
    final nextPending = _pendingInputSessions;

    if (_mapsEqual(_lastEmittedActiveSessions, nextActive) &&
        _setsEqual(_lastEmittedRetrySessions, nextRetry) &&
        _setsEqual(_lastEmittedPendingInputSessions, nextPending)) {
      return false;
    }

    _lastEmittedActiveSessions = nextActive;
    _lastEmittedRetrySessions = nextRetry;
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
    // Attribute every active (busy/retry) session to its root ancestor by
    // walking the parent chain. Any active descendant — a direct child or
    // deeper — surfaces on its root session's row, because the session list
    // only renders root sessions. Sessions whose chain cannot be resolved to a
    // known root (an ancestor was never observed, or a cycle is detected) are
    // ignored: there is no root row to attribute them to.
    final activeDescendantsByRoot = <String, List<String>>{};
    final directlyActiveRoots = <String>{};

    for (final sessionId in _sessionStatuses.keys) {
      final rootId = _resolveRootSession(sessionId);
      if (rootId == null) continue;
      if (rootId == sessionId) {
        directlyActiveRoots.add(sessionId);
      } else {
        activeDescendantsByRoot.putIfAbsent(rootId, () => []).add(sessionId);
      }
    }

    // Roots that are themselves active + roots that only have active descendants.
    final allActiveRoots = <String>{...directlyActiveRoots, ...activeDescendantsByRoot.keys};

    // Build ActiveSession per root, grouped by worktree.
    final byWorktree = <String, List<ActiveSession>>{};
    for (final rootId in allActiveRoots) {
      final descendants = activeDescendantsByRoot[rootId] ?? const <String>[];
      // childSessionIds carries DIRECT active children only. Consumers such as
      // PushSessionStateTracker treat these as parent→child links for hierarchy
      // repair, so listing deeper descendants here would flatten the tree.
      // Deeper active descendants still surface the root above; they are just
      // not reported as its direct children.
      final directChildren = descendants.where((id) => _sessionParentIds[id] == rootId).toList();
      var worktree = _sessionWorktrees[rootId];
      // The root may lack a worktree if we only observed its descendants
      // (e.g. bridge reconnected after the root session was created).
      // Fall back to any descendant's worktree — they share the same project.
      if (worktree == null) {
        for (final descendantId in descendants) {
          worktree = _sessionWorktrees[descendantId];
          if (worktree != null) break;
        }
      }
      if (worktree == null) {
        Log.w("buildSummary: no worktree for session $rootId");
        continue;
      }
      // Retry / awaiting-input are activity badge signals (not hierarchy), so
      // they reflect the whole active subtree, not just the direct children.
      final isRetrying = _sessionStatuses[rootId] is SessionStatusRetry ||
          descendants.any((id) => _sessionStatuses[id] is SessionStatusRetry);
      byWorktree
          .putIfAbsent(worktree, () => [])
          .add(
            ActiveSession(
              id: rootId,
              mainAgentRunning: directlyActiveRoots.contains(rootId),
              awaitingInput: _rootHasPendingInput(rootId, descendants),
              isRetrying: isRetrying,
              childSessionIds: directChildren,
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

  /// Walks the parent chain from [sessionId] up to its root ancestor — the
  /// first session whose `parentID` is null.
  ///
  /// If [sessionId] itself has no observed parent metadata, it is treated as its
  /// own root. This preserves the prior fallback for active sessions seen only
  /// via a status event (no `session.created`/cold-start metadata yet), which
  /// would otherwise be dropped from the summary entirely.
  ///
  /// Returns null only when an *ancestor* in the chain was never observed (an
  /// orphan child whose parent we have not seen) or a cycle is detected — such
  /// sessions cannot be attributed to a root row and are dropped.
  String? _resolveRootSession(String sessionId) {
    var current = sessionId;
    final visited = <String>{};
    while (visited.add(current)) {
      if (!_sessionParentIds.containsKey(current)) {
        return current == sessionId ? sessionId : null;
      }
      final parentId = _sessionParentIds[current];
      if (parentId == null) return current;
      current = parentId;
    }
    Log.w("buildSummary: cycle detected resolving root for $sessionId");
    return null;
  }

  /// Whether [sessionId] is itself active, or is an ancestor of any active
  /// session.
  ///
  /// A parent-link change on such a session can move an active session to a
  /// different root — or make a previously-orphaned active descendant
  /// resolvable — without changing the per-worktree active counts, so the
  /// summary must be re-emitted when this returns true.
  bool _participatesInActiveSubtree(String sessionId) {
    if (_sessionStatuses.containsKey(sessionId)) return true;
    for (final activeId in _sessionStatuses.keys) {
      var current = activeId;
      final visited = <String>{};
      while (visited.add(current)) {
        if (current == sessionId) return true;
        final parentId = _sessionParentIds[current];
        if (parentId == null) break;
        current = parentId;
      }
    }
    return false;
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

  /// Set of session IDs that are currently in retry state.
  ///
  /// Used for change detection so that a busy→retry transition (where the
  /// per-worktree active count does not change) still triggers a re-emit.
  /// Tracking individual IDs rather than counts ensures session-level swaps
  /// (A stops retrying while B starts) are also detected.
  Set<String> get _retryingSessionIds {
    return _sessionStatuses.entries
        .where((e) => e.value is SessionStatusRetry)
        .map((e) => e.key)
        .toSet();
  }

  /// Exposed for testing: raw count of all busy/retry sessions per worktree.
  Map<String, int> get activeSessions => _activeSessionCounts;

  bool _hasPendingInput(String sessionId) {
    return (_pendingQuestions[sessionId]?.isNotEmpty ?? false) || (_pendingPermissions[sessionId]?.isNotEmpty ?? false);
  }

  /// Returns true if the root session OR any of its active descendant sessions
  /// has pending input (question or permission).
  ///
  /// Descendants are included so that sub-agent questions/permissions surface
  /// on the root session row in the session list, at any nesting depth.
  bool _rootHasPendingInput(String rootId, List<String> descendantIds) {
    if (_hasPendingInput(rootId)) return true;
    return descendantIds.any(_hasPendingInput);
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
