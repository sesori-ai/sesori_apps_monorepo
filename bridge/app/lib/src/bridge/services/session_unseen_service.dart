import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../repositories/project_repository.dart";
import "../repositories/session_repository.dart";
import "../repositories/session_unseen_repository.dart";
import "session_view_tracker.dart";

/// Thrown by [SessionUnseenService.markUnread] when the target session has no
/// row (deleted / unknown). The service still emits an authoritative clear for
/// other clients, but this is rethrown so the requesting client receives a
/// non-2xx and rolls back its optimistic "unread" — otherwise, if it misses the
/// clear SSE (e.g. during a reconnect), a 2xx would leave a phantom unseen row.
class SessionUnseenRowMissingException implements Exception {
  final String sessionId;

  SessionUnseenRowMissingException({required this.sessionId});
}

/// A single emitted unseen-state change for one session, plus the recomputed
/// project-level aggregate. The orchestrator maps this to
/// `SesoriSseEvent.sessionUnseenChanged`.
typedef UnseenChange = ({
  String projectId,
  String sessionId,
  bool unseen,
  bool projectHasUnseenChanges,
});

/// Layer-3 owner of unseen-changes decisions. It consumes activity events,
/// view declarations (via [SessionViewTracker]), and explicit mark-read/unread
/// commands; persists timestamps via [SessionUnseenRepository]; recomputes the
/// per-session flag and the project aggregate; and emits [unseenChanges] for the
/// orchestrator to forward as SSE — mirroring `PrSyncService.prChanges`.
class SessionUnseenService {
  final SessionUnseenRepository _unseenRepository;
  final ProjectRepository _projectRepository;
  final SessionRepository _sessionRepository;
  final SessionViewTracker _viewTracker;
  final int Function() _wallClock;

  /// Last timestamp this service issued. Used to keep `_nextTimestamp`
  /// strictly monotonic so two events processed within the same millisecond
  /// (e.g. a user `message.updated` immediately followed by the assistant's)
  /// still receive distinct, ordered timestamps — otherwise activity could
  /// equal the user-message timestamp and the session would wrongly stay seen.
  int _lastIssued = 0;

  final StreamController<UnseenChange> _changes = StreamController<UnseenChange>.broadcast();
  StreamSubscription<String>? _viewStartsSubscription;

  /// Single global write tail. All unseen mutations (across all sessions) are
  /// chained here so both per-session writes and the project-level aggregate
  /// emits happen in submission order. See [_serialize].
  Future<void> _writeTail = Future<void>.value();

  /// Session ids that had no persisted row and didn't resolve to a project
  /// (i.e. child/subagent sessions), mapped to the time the negative result was
  /// cached. Cached so an active subagent doesn't turn every `message.part`/
  /// `message.updated` event into a full project scan via
  /// `findProjectIdForSession`.
  ///
  /// The cache is TTL-bounded (not permanent): a transiently-unresolved ROOT —
  /// e.g. one whose first activity arrives before the plugin can resolve it, and
  /// is later learned via `/sessions` or `session.created` — re-resolves after
  /// the TTL instead of being skipped forever. It is also invalidated eagerly on
  /// `recordSessionCreated`, and bounded in size (oldest evicted first).
  static const int _maxUnresolvedCached = 1024;
  static const Duration _unresolvedTtl = Duration(seconds: 30);
  final Map<String, int> _unresolvedSessions = <String, int>{};

  bool _isCachedUnresolved(String sessionId) {
    final cachedAt = _unresolvedSessions[sessionId];
    if (cachedAt == null) return false;
    if (_wallClock() - cachedAt >= _unresolvedTtl.inMilliseconds) {
      _unresolvedSessions.remove(sessionId);
      return false;
    }
    return true;
  }

  void _markUnresolved(String sessionId) {
    if (_unresolvedSessions.length >= _maxUnresolvedCached) {
      _unresolvedSessions.remove(_unresolvedSessions.keys.first);
    }
    _unresolvedSessions[sessionId] = _wallClock();
  }

  SessionUnseenService({
    required SessionUnseenRepository unseenRepository,
    required ProjectRepository projectRepository,
    required SessionRepository sessionRepository,
    required SessionViewTracker viewTracker,
    int Function()? now,
  }) : _unseenRepository = unseenRepository,
       _projectRepository = projectRepository,
       _sessionRepository = sessionRepository,
       _viewTracker = viewTracker,
       _wallClock = now ?? (() => DateTime.now().millisecondsSinceEpoch) {
    _viewStartsSubscription = _viewTracker.viewStarts.listen(_onViewStarted);
  }

  /// Emits whenever a session's unseen state (or its project's aggregate) may
  /// have changed.
  Stream<UnseenChange> get unseenChanges => _changes.stream;

  /// Strictly-increasing timestamp source. Returns the wall clock, but never a
  /// value <= the previous one, so ordered writes always get ordered timestamps.
  int _nextTimestamp() {
    final wall = _wallClock();
    return _lastIssued = wall > _lastIssued ? wall : _lastIssued + 1;
  }

  /// Activity timestamp clamped above the row's persisted markers. The
  /// monotonic clock is process-local, so after a restart or a system-clock
  /// rollback it can start below stored timestamps; without this clamp a new
  /// assistant activity could write `last_activity_at` <= `max(userMessage,
  /// seen)` and the session would never bold. Clamping keeps the monotonic
  /// invariant intact for subsequent writes.
  int _activityTimestamp({required int? userMessageAt, required int? seenAt}) {
    final floor = (userMessageAt ?? 0) > (seenAt ?? 0) ? (userMessageAt ?? 0) : (seenAt ?? 0);
    final next = _nextTimestamp();
    if (next > floor) return next;
    final at = floor + 1;
    if (at > _lastIssued) _lastIssued = at;
    return at;
  }

  /// Records activity for [sessionId]. No-op when the session has no persisted
  /// row (child/subagent sessions, or sessions not yet learned). While the
  /// session is being viewed, the seen timestamp is advanced too so it never
  /// bolds under the watcher.
  Future<void> recordActivity({
    required String sessionId,
    required bool isUserMessage,
  }) {
    // Capture the viewed state at submission time, not when the (possibly
    // delayed) serialized write executes — otherwise navigating away while
    // events are queued could persist already-viewed activity as unseen.
    final viewedAtSubmit = _viewTracker.isViewed(sessionId: sessionId);
    return _serialize(sessionId, () async {
      final row = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      if (row == null) {
        // No persisted row. Honor the negative cache here (after the cheap PK
        // lookup, before the expensive resolution) — a row created since (e.g.
        // a `/sessions` refresh learned this root) clears the cache above and
        // takes the normal path, so a transiently-unresolved root self-heals.
        if (_isCachedUnresolved(sessionId)) return;
        // Not yet persisted — try to resolve the project id and create a row
        // so activity isn't silently dropped (e.g. a root session created on
        // the laptop while the bridge was offline).
        final projectId = await _sessionRepository.findProjectIdForSession(sessionId: sessionId);
        if (projectId == null) {
          _markUnresolved(sessionId);
          return;
        }
        await _unseenRepository.ensureRootSessionActivity(
          sessionId: sessionId,
          projectId: projectId,
          activityAt: _activityTimestamp(userMessageAt: null, seenAt: null),
          advanceSeen: viewedAtSubmit,
          isUserMessage: isUserMessage,
        );
        await _emit(sessionId: sessionId, projectId: projectId);
        return;
      }
      // The row exists, so this is a known (resolvable) session — drop any stale
      // unresolved marker so future events take the fast path normally.
      _unresolvedSessions.remove(sessionId);
      // Coalesce streaming output: once a non-user activity has already made the
      // session unseen and no phone is viewing it, further deltas don't change
      // the unseen state and the SSE emit is identical. Skip the redundant DB
      // write + recompute + emit so a long backgrounded response can't flood the
      // global write queue and delay view-start/mark-read for other sessions.
      // (A later mark-read stamps seen at `now`, which is always past the
      // skipped, older activity timestamp, so correctness is preserved.)
      if (!isUserMessage && !viewedAtSubmit && _unseenRepository.unseenForRow(row)) {
        return;
      }
      await _unseenRepository.recordActivity(
        sessionId: sessionId,
        at: _activityTimestamp(userMessageAt: row.userMessageAt, seenAt: row.seenAt),
        isUserMessage: isUserMessage,
        advanceSeen: viewedAtSubmit,
      );
      await _emit(sessionId: sessionId, projectId: row.projectId);
    });
  }

  /// Records that a brand-new ROOT session was created (observed live). Child
  /// sessions ([parentId] != null) are ignored. The new root is stamped with
  /// activity so it is immediately unseen — unless a phone is already viewing
  /// it, in which case it stays seen.
  Future<void> recordSessionCreated({
    required String sessionId,
    required String projectId,
    required String? parentId,
  }) {
    if (parentId != null) return Future<void>.value();
    final viewedAtSubmit = _viewTracker.isViewed(sessionId: sessionId);
    return _serialize(sessionId, () async {
      // A root session.created proves this session is resolvable now, so drop
      // any stale "unresolved" marker. Done inside the serialized body (after
      // prior writes) so an earlier queued miss can't re-add it afterwards.
      _unresolvedSessions.remove(sessionId);
      final existing = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      // If an earlier activity event already stamped this row (it has any
      // unseen marker), don't overwrite it — that would advance activity past
      // the user's own message and wrongly bold it. But a bare placeholder
      // inserted by a `/sessions` refresh (no markers at all) must still be
      // stamped with creation activity so a new laptop-created session bolds
      // instead of staying seen forever.
      final hasMarkers =
          existing != null &&
          (existing.activityAt != null || existing.userMessageAt != null || existing.seenAt != null);
      if (hasMarkers) {
        await _emit(sessionId: sessionId, projectId: existing.projectId);
        return;
      }
      await _unseenRepository.ensureRootSessionActivity(
        sessionId: sessionId,
        projectId: projectId,
        activityAt: _nextTimestamp(),
        advanceSeen: viewedAtSubmit,
        isUserMessage: false,
      );
      await _emit(sessionId: sessionId, projectId: projectId);
    });
  }

  /// Records that a session was deleted (observed live via `session.deleted`,
  /// e.g. from another client or the laptop TUI). Removes the persisted row so a
  /// stale unseen row can't keep its project's aggregate bold after the session
  /// is gone, and emits the cleared state. No-op for unknown sessions.
  Future<void> recordSessionDeleted({required String sessionId}) {
    return _serialize(sessionId, () async {
      _unresolvedSessions.remove(sessionId);
      final row = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      if (row == null) return;
      await _unseenRepository.deleteSession(sessionId: sessionId);
      // Emit once so any client showing this session/project recomputes; the
      // session itself is gone, so its unseen flag is reported false.
      final projectHasUnseen = await _projectRepository.projectHasUnseenChanges(projectId: row.projectId);
      if (_changes.isClosed) return;
      _changes.add(
        (projectId: row.projectId, sessionId: sessionId, unseen: false, projectHasUnseenChanges: projectHasUnseen),
      );
    });
  }

  /// "Mark as Read": stamp seen at max(now, lastActivity) so it clears.
  /// Errors are propagated to the caller (this is a user-initiated request).
  Future<void> markRead({required String sessionId, required String? projectId}) {
    return _serialize(sessionId, rethrowErrors: true, () async {
      final row = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      if (row == null) {
        await _emitMissingRowClear(sessionId: sessionId, projectId: projectId);
        return;
      }
      final now = _nextTimestamp();
      final seenAt = (row.activityAt ?? 0) > now ? row.activityAt! : now;
      await _unseenRepository.markSessionSeen(sessionId: sessionId, at: seenAt);
      // Propagate emit failures: the client clears only the row optimistically
      // and leaves the project aggregate to this echo, so a 2xx without the
      // emitted aggregate could leave the project bold until a full refresh.
      await _computeAndEmit(sessionId: sessionId, projectId: row.projectId);
    });
  }

  /// "Mark as Unread": force the session bold regardless of prior state.
  /// Errors are propagated to the caller (this is a user-initiated request).
  Future<void> markUnread({required String sessionId, required String? projectId}) {
    return _serialize(sessionId, rethrowErrors: true, () async {
      final row = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      if (row == null) {
        // Emit a clear for other clients, then surface the missing row so the
        // requesting client rolls back its optimistic unread even if it misses
        // the clear SSE (a 2xx would otherwise leave a phantom unseen row).
        await _emitMissingRowClear(sessionId: sessionId, projectId: projectId);
        throw SessionUnseenRowMissingException(sessionId: sessionId);
      }
      // Force activity strictly past both the user-message and seen markers so
      // the session reliably bolds even when the user's own message is latest.
      final at = _activityTimestamp(userMessageAt: row.userMessageAt, seenAt: row.seenAt);
      await _unseenRepository.markSessionUnseen(sessionId: sessionId, at: at);
      // Propagate emit failures (user-initiated request); see markRead.
      await _computeAndEmit(sessionId: sessionId, projectId: row.projectId);
    });
  }

  /// Emits an authoritative clear for a mark-read/unread that targeted a session
  /// with no row (deleted, or missed during a refresh). Reports the session
  /// `unseen: false` and recomputes the project aggregate so clients can settle
  /// (e.g. drop a project's bold whose only unseen row was the now-gone session)
  /// instead of waiting for a full refresh. No-op when [projectId] is unknown
  /// (older client) — there is no project to recompute against.
  Future<void> _emitMissingRowClear({required String sessionId, required String? projectId}) async {
    if (projectId == null) {
      Log.d("mark-seen for missing row $sessionId without a projectId; skipping authoritative clear");
      return;
    }
    // Use the throwing variant: this runs on a user-initiated mark-read/unread
    // (rethrowErrors), so if the clear can't be computed/emitted the failure
    // must surface as a non-2xx — otherwise the client would get success but
    // never receive the authoritative SSE clear, leaving stale optimistic state.
    await _computeAndEmit(sessionId: sessionId, projectId: projectId);
  }

  /// Recomputes and emits the unseen state for [sessionId] after a change made
  /// outside this service that can flip the project aggregate — archiving /
  /// unarchiving a session (archived rows are excluded from the aggregate), or a
  /// local `DELETE /session/delete` that already removed the row. [projectId] is
  /// required because the row may be gone (deleted). When the row no longer
  /// exists the session is reported `unseen: false`.
  Future<void> notifyExternalChange({required String sessionId, required String projectId}) {
    return _serialize(sessionId, () async {
      await _emit(sessionId: sessionId, projectId: projectId);
    });
  }

  Future<void> _onViewStarted(String sessionId) {
    return _serialize(sessionId, () async {
      final row = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      if (row == null) return;
      // Write at least the persisted activity timestamp so a clock skew or
      // restart can't leave seen below activity (which would keep it bold).
      final now = _nextTimestamp();
      final seenAt = (row.activityAt ?? 0) > now ? row.activityAt! : now;
      await _unseenRepository.markSessionSeen(sessionId: sessionId, at: seenAt);
      await _emit(sessionId: sessionId, projectId: row.projectId);
    });
  }

  /// Runs [operation] after any in-flight unseen write completes.
  ///
  /// Serialization is GLOBAL (a single tail), not per-session: an operation
  /// emits the project-level aggregate as authoritative, so two operations on
  /// different sessions of the same project must also be ordered — otherwise
  /// "mark A read" (aggregate=false) could be emitted after "B got activity"
  /// (aggregate=true) and leave clients with a stale `false`. A global queue
  /// keeps both the per-session writes and the cross-session aggregate emits in
  /// submission order. The operations are tiny, infrequent DB writes, so the
  /// reduced concurrency is irrelevant.
  ///
  /// By default failures are caught and logged so fire-and-forget callers (the
  /// orchestrator's SSE path) never see an unhandled async error. User-initiated
  /// operations pass [rethrowErrors] so the failure surfaces to the request
  /// handler (which turns it into a non-2xx response) — while keeping the queue
  /// intact for writes chained after it.
  Future<void> _serialize(
    String sessionId,
    Future<void> Function() operation, {
    bool rethrowErrors = false,
  }) {
    // The chain must continue regardless of this op's outcome, so the tail used
    // for ordering swallows errors; the returned future (for the caller) may
    // rethrow when requested.
    final result = _writeTail.then((_) => operation());
    _writeTail = result.catchError((Object error, StackTrace stackTrace) {
      Log.w("unseen update failed for session $sessionId", error, stackTrace);
    });
    return rethrowErrors ? result : _writeTail;
  }

  /// Fire-and-forget emit: swallows + logs failures (for the orchestrator's SSE
  /// path and other best-effort callers).
  Future<void> _emit({required String sessionId, required String projectId}) async {
    try {
      await _computeAndEmit(sessionId: sessionId, projectId: projectId);
    } catch (error, stackTrace) {
      Log.w("failed to compute/emit unseen change for session $sessionId", error, stackTrace);
    }
  }

  /// Computes and emits the unseen change, PROPAGATING any failure. Used by
  /// user-initiated paths that must surface an error to the caller.
  Future<void> _computeAndEmit({required String sessionId, required String projectId}) async {
    final unseen = await _unseenRepository.isUnseen(sessionId: sessionId);
    final projectHasUnseen = await _projectRepository.projectHasUnseenChanges(projectId: projectId);
    if (_changes.isClosed) return;
    _changes.add(
      (
        projectId: projectId,
        sessionId: sessionId,
        unseen: unseen,
        projectHasUnseenChanges: projectHasUnseen,
      ),
    );
  }

  Future<void> dispose() async {
    await _viewStartsSubscription?.cancel();
    // Let the in-flight write queue drain (the tail swallows errors) before
    // closing the stream, so no operation runs against a closed controller.
    await _writeTail.catchError((_) {});
    await _changes.close();
  }
}
