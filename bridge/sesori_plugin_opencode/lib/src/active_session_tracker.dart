import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart" show ActiveSession, ProjectActivitySummary;

import "models/openapi/permission_request.g.dart";
import "models/openapi/question_request.g.dart";
import "models/openapi/session.g.dart";
import "models/openapi/session_status.g.dart";
import "models/sse_event_data.g.dart";
import "opencode_repository.dart";

class ActiveSessionTracker {
  final OpenCodeRepository _repository;

  final Set<String> _projectWorktrees = {};

  /// Directories the backend resolves to a project rooted elsewhere, keyed by
  /// normalized directory → canonical worktree. A moved folder re-opened at a
  /// new location keeps its original worktree as the backend's project root,
  /// so sessions running under the live location would otherwise never match
  /// a known worktree. Learned from project lookups by directory.
  final Map<String, String> _worktreeAliases = {};
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
    final projects = await _repository.getProjects();

    _projectWorktrees
      ..clear()
      ..addAll(projects.map((p) => p.project.id));

    // Each sandbox is a directory the backend has resolved to the project —
    // for a moved folder, its live location. Seeding the aliases up front
    // keeps sessions under those locations groupable from the first summary,
    // without waiting for a per-directory project lookup.
    _worktreeAliases.clear();
    for (final project in projects) {
      for (final sandbox in project.sandboxes) {
        _putWorktreeAlias(directory: sandbox, worktree: project.project.id);
      }
    }

    _sessionWorktrees.clear();
    _sessionDirectories.clear();
    _sessionParentIds.clear();

    // List sessions for the OpenCode server's cwd instance AND every directory
    // sessions may run under: project worktrees plus moved-location aliases
    // (sessions at a moved project's live location only surface from that
    // instance's query). An unscoped `listSessions(directory: null)` only
    // targets the cwd instance, while a per-directory query covers each
    // project — querying all (and de-duplicating by id below) ensures every
    // session and its parent attribution is hydrated regardless of whether the
    // cwd is itself a listed worktree. Without complete parent attribution a
    // child session's parent stays unknown, so its pending input never rolls
    // up to (or surfaces on) its root until the session is opened later.
    final sessionQueryDirectories = <String?>{null, ...sessionDiscoveryDirectories}.toList();
    final sessionLists = await Future.wait(
      sessionQueryDirectories.map((directory) async {
        try {
          return await _repository.listSessions(directory: directory, roots: false);
        } catch (e) {
          Log.w("coldStart: failed to list sessions for ${directory ?? "<cwd>"}: $e");
          return <Session>[];
        }
      }),
    );

    // Build directory lookup and parent ID mapping from fetched sessions.
    final sessionDirectories = <String, String>{};
    for (final session in sessionLists.expand((sessions) => sessions)) {
      sessionDirectories[session.id] = session.directory;
      _sessionParentIds[session.id] = session.parentID;
    }

    _sessionDirectories
      ..clear()
      ..addAll(sessionDirectories);

    // Fetch statuses per-directory so each call targets the correct OpenCode
    // Instance — including moved-location aliases, whose sessions only surface
    // from their own instance. Errors for individual directories are logged
    // and skipped so that one unavailable project doesn't block the rest.
    final allStatuses = <String, SessionStatus>{};
    final statusFutures = sessionDiscoveryDirectories.map((directory) async {
      try {
        final statuses = await _repository.api.getSessionStatuses(directory: directory);
        // Map session → worktree from the call context; an alias directory
        // groups under its canonical worktree.
        final worktree = _resolveWorktree(directory) ?? directory;
        for (final entry in statuses.entries) {
          allStatuses[entry.key] = entry.value;
          _sessionWorktrees[entry.key] = worktree;
        }
      } catch (e) {
        Log.w("coldStart: failed to fetch session statuses for $directory: $e");
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
          case SessionStatusUnknown():
            Log.w("Unknown session status for ${event.sessionID}; treating as inactive");
            _sessionStatuses.remove(event.sessionID);
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
        // The permission's `id` is what `permission.replied` later echoes as
        // its `requestID`, so it is the key we track pending permissions by.
        _pendingPermissions.putIfAbsent(event.sessionID, () => <String>{}).add(event.id);
      case SsePermissionReplied():
        _removePendingPermission(sessionId: event.sessionID, requestId: event.requestID);
      default:
        return false;
    }

    return _detectEmitChange(forceReemit: forceReemit);
  }

  /// Looks up the session ID that currently owns the pending [questionId].
  /// Returns null if the question is not tracked.
  String? getSessionIdForQuestion({required String questionId}) {
    for (final entry in _pendingQuestions.entries) {
      if (entry.value.contains(questionId)) return entry.key;
    }
    return null;
  }

  ({bool found, String? resolvedSessionId, bool summaryChanged}) clearPendingQuestion({
    required String questionId,
    String? sessionId,
  }) {
    bool found;
    var resolvedSessionId = sessionId;
    if (sessionId != null) {
      found = _removePendingQuestion(sessionId: sessionId, requestId: questionId);
    } else {
      found = false;
      for (final entry in _pendingQuestions.entries.toList()) {
        if (entry.value.remove(questionId)) {
          found = true;
          resolvedSessionId = entry.key;
          if (entry.value.isEmpty) {
            _pendingQuestions.remove(entry.key);
          }
          break;
        }
      }
    }
    return (found: found, resolvedSessionId: resolvedSessionId, summaryChanged: _detectEmitChange());
  }

  ({bool found, String? resolvedSessionId, bool summaryChanged}) clearPendingPermission({
    required String sessionId,
    required String requestId,
  }) {
    final found = _removePendingPermission(sessionId: sessionId, requestId: requestId);
    return (found: found, resolvedSessionId: sessionId, summaryChanged: _detectEmitChange());
  }

  bool _detectEmitChange({bool forceReemit = false}) {
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
    _worktreeAliases.clear();
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

  void populatePendingQuestions({required List<QuestionRequest> questions}) {
    _pendingQuestions
      ..clear()
      ..addEntries(_groupBySessionId(questions.map((q) => (q.sessionID, q.id))).entries);
    _lastEmittedPendingInputSessions = _pendingInputSessions;
  }

  void populatePendingPermissions({required List<PermissionRequest> permissions}) {
    _pendingPermissions
      ..clear()
      ..addEntries(_groupBySessionId(permissions.map((p) => (p.sessionID, p.id))).entries);
    _lastEmittedPendingInputSessions = _pendingInputSessions;
  }

  /// Replaces the set of known project worktrees and re-resolves worktree
  /// mappings for any active sessions that currently lack one.
  ///
  /// Called from [OpenCodeService.getProjects] to keep the tracker's worktree
  /// knowledge in sync with the latest project list. This is important because
  /// [coldStart] may run before all projects are known (e.g. fresh OpenCode
  /// install), and new projects discovered later would otherwise be invisible
  /// to the activity summary.
  bool updateProjectWorktrees({required Set<String> worktrees}) {
    _projectWorktrees
      ..clear()
      ..addAll(worktrees);
    return _resummarizeAfterWorktreeKnowledgeChange();
  }

  /// Records that the backend resolves [directory] to the project rooted at
  /// [worktree] — a moved folder re-opened at a new location keeps its
  /// original worktree as the backend's project root. With the alias in
  /// place, sessions running under [directory] resolve to [worktree] like any
  /// other session of that project, so activity summaries and event
  /// projectIDs group under the canonical project.
  ///
  /// Called when project listing or lookup pairs a requested directory with the
  /// backend's canonical project root. Returns `true` when the alias changed the
  /// activity summary.
  bool registerWorktreeAlias({required String directory, required String worktree}) {
    if (!_putWorktreeAlias(directory: directory, worktree: worktree)) {
      return false;
    }
    return _resummarizeAfterWorktreeKnowledgeChange();
  }

  /// Stores the alias when it is meaningful and new: self-aliases and empty
  /// worktrees carry no information. Returns whether the alias map changed.
  bool _putWorktreeAlias({required String directory, required String worktree}) {
    final normalizedDirectory = _normalizePath(directory);
    if (worktree.isEmpty || normalizedDirectory == _normalizePath(worktree)) {
      return false;
    }
    if (_worktreeAliases[normalizedDirectory] == worktree) {
      return false;
    }
    _worktreeAliases[normalizedDirectory] = worktree;
    return true;
  }

  /// Re-resolves worktrees for active sessions that lack one — new knowledge
  /// (a fresh project list, a new directory alias) can make a previously
  /// unresolvable session directory groupable. Returns `true` when the
  /// activity summary changed as a result.
  bool _resummarizeAfterWorktreeKnowledgeChange() {
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

  /// Registers what we know about a session: its directory and its parent ID.
  ///
  /// Used both at request time (session creation, listing, pending-question
  /// lookups) and after a one-shot parent-ID resolution. Recording the parent
  /// ID here is the defense-in-depth half of the phantom-root fix: whenever any
  /// flow already holds the session object, we capture [parentId] so a later
  /// busy status for this session is attributed to the correct root instead of
  /// being misclassified as its own root.
  ///
  /// Returns `true` when this call changes the activity summary grouping — i.e.
  /// the session is currently active (busy/retry) and its recorded parent ID
  /// actually changed. Callers that drive summary re-emits (the SSE-resolution
  /// path) use this; request-time callers may ignore it.
  bool registerSession({
    required String sessionId,
    required String directory,
    required String? parentId,
  }) {
    _sessionDirectories[sessionId] = directory;
    // Resolve the directory into a worktree now. On the dropped-`session.created`
    // recovery path a bare `session.status` frame carries no directory, so this
    // call is the only place that learns it. buildSummary and
    // _activeSessionCounts key off _sessionWorktrees, so without this the
    // recovered root would still have no worktree and produce no summary row.
    final previousWorktree = _sessionWorktrees[sessionId];
    _updateSessionWorktree(sessionId, directory);
    final worktreeChanged = _sessionWorktrees[sessionId] != previousWorktree;

    final previousParent = _sessionParentIds[sessionId];
    _sessionParentIds[sessionId] = parentId;
    final parentChanged = previousParent != parentId;

    // Re-emit when this call changes how an active session appears in the
    // summary: either its grouping (parent) changed, or it just gained/changed a
    // worktree. The latter matters for a root recovered on the no-directory
    // path: its parent stays null, but it transitions from "no worktree / no
    // row" to a visible root row, so a worktree-only change must still
    // invalidate. A missing parent entry already resolves to null in
    // buildSummary, so an unobserved→root transition whose worktree is unchanged
    // is correctly NOT a change and avoids a redundant re-emit.
    final summaryChanged = parentChanged || worktreeChanged;
    // Only an active session affects the summary grouping.
    return summaryChanged && _sessionStatuses.containsKey(sessionId);
  }

  /// Whether the tracker already knows this session's parent attribution.
  ///
  /// Distinguishes "known root" (recorded value is `null`) from "never
  /// observed" (no entry). The SSE-resolution path uses this to decide whether
  /// a busy session still needs a one-shot parent-ID lookup.
  bool knowsParent({required String sessionId}) {
    return _sessionParentIds.containsKey(sessionId);
  }

  /// Look up the directory for a session. Returns null if unknown.
  String? getSessionDirectory({required String sessionId}) {
    return _sessionDirectories[sessionId];
  }

  /// Resolves the top-most root "display" session for [sessionId] by walking the
  /// recorded parent chain to the root.
  ///
  /// Used to surface a child/sub-agent session's pending input (questions and
  /// permissions) on its root session. Best-effort: returns the highest *known*
  /// ancestor, or [sessionId] itself when it is already a root or its parent
  /// chain has not been observed. Cycle-safe via a visited guard.
  String resolveDisplaySessionId(String sessionId) {
    final visited = <String>{};
    var current = sessionId;
    while (visited.add(current)) {
      final parent = _sessionParentIds[current];
      if (parent == null || parent.isEmpty) return current;
      current = parent;
    }
    return current;
  }

  /// Resolves the canonical worktree for a raw session directory.
  String? resolveProjectWorktree({required String directory}) {
    return _resolveWorktree(directory);
  }

  /// Every directory sessions may be running under: project worktrees plus
  /// moved-location aliases (each targets its own OpenCode instance). Exposed
  /// so the service can hydrate pending input per directory — an unscoped
  /// query only covers the OpenCode server's cwd instance.
  Set<String> get sessionDiscoveryDirectories => Set.unmodifiable({
    ..._projectWorktrees,
    ..._worktreeAliases.keys,
  });

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
        // Root session, or parent not yet resolved — treat as root. A busy
        // session whose parent is still unknown surfaces as its own root row
        // transiently; the one-shot parent-ID resolution re-emits the summary
        // once the real root is known (see OpenCodeService).
        activeRoots.add(sessionId);
      } else {
        // Direct child — surface its parent as the active root row directly.
        // We intentionally model only two levels (root + direct child): a
        // non-null parent ID is always treated as a direct child of a root,
        // with no grandchild/deep-descendant handling.
        activeChildrenByParent.putIfAbsent(parentId, () => []).add(sessionId);
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
      final isRetrying =
          _sessionStatuses[rootId] is SessionStatusRetry ||
          children.any((childId) => _sessionStatuses[childId] is SessionStatusRetry);
      byWorktree
          .putIfAbsent(worktree, () => [])
          .add(
            ActiveSession(
              id: rootId,
              mainAgentRunning: activeRoots.contains(rootId),
              awaitingInput: _rootHasPendingInput(rootId, children),
              isRetrying: isRetrying,
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

  /// Set of session IDs that are currently in retry state.
  ///
  /// Used for change detection so that a busy→retry transition (where the
  /// per-worktree active count does not change) still triggers a re-emit.
  /// Tracking individual IDs rather than counts ensures session-level swaps
  /// (A stops retrying while B starts) are also detected.
  Set<String> get _retryingSessionIds {
    return _sessionStatuses.entries.where((e) => e.value is SessionStatusRetry).map((e) => e.key).toSet();
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
    if (bestMatch != null) {
      return bestMatch;
    }
    // No known worktree contains the directory — it may be the live location
    // of a moved project. An alias maps the directory (and anything under it)
    // back to the project's canonical worktree.
    String? bestAliasRoot;
    for (final aliasRoot in _worktreeAliases.keys) {
      if (normalizedDirectory == aliasRoot || normalizedDirectory.startsWith("$aliasRoot/")) {
        if (bestAliasRoot == null || aliasRoot.length > bestAliasRoot.length) {
          bestAliasRoot = aliasRoot;
        }
      }
    }
    return bestAliasRoot == null ? null : _worktreeAliases[bestAliasRoot];
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

  bool _removePendingQuestion({required String sessionId, required String requestId}) {
    final questionIds = _pendingQuestions[sessionId];
    if (questionIds == null) return false;
    final removed = questionIds.remove(requestId);
    if (questionIds.isEmpty) {
      _pendingQuestions.remove(sessionId);
    }
    return removed;
  }

  bool _removePendingPermission({required String sessionId, required String requestId}) {
    final requestIds = _pendingPermissions[sessionId];
    if (requestIds == null) return false;
    final removed = requestIds.remove(requestId);
    if (requestIds.isEmpty) {
      _pendingPermissions.remove(sessionId);
    }
    return removed;
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
