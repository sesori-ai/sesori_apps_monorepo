import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../repositories/project_repository.dart";
import "../repositories/session_unseen_repository.dart";
import "session_view_tracker.dart";

/// Thrown by [SessionUnseenService.markUnread] when the target session has no
/// row (deleted / never learned). Rethrown so the requesting client receives a
/// non-2xx and refreshes its (optimistic) state from the authoritative list.
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
/// per-session flag and the project aggregate; and emits [unseenChanges] for
/// the orchestrator to forward as SSE.
///
/// It is also the single owner of unseen-row deletion: both delete triggers —
/// a live `session.deleted` event ([recordSessionDeleted]) and the `/sessions`
/// complete-list reconcile ([reconcileVanishedSessions]) — funnel through the
/// same delete-and-emit pipeline.
class SessionUnseenService {
  final SessionUnseenRepository _unseenRepository;
  final ProjectRepository _projectRepository;
  final SessionViewTracker _viewTracker;
  final int Function() _wallClock;

  /// Last timestamp this service issued. Used to keep [_nextTimestamp]
  /// strictly monotonic so two events processed within the same millisecond
  /// (e.g. a user `message.updated` immediately followed by the assistant's)
  /// still receive distinct, ordered timestamps — otherwise activity could
  /// equal the user-message timestamp and the session would wrongly stay seen.
  int _lastIssued = 0;

  final StreamController<UnseenChange> _changes = StreamController<UnseenChange>.broadcast();
  StreamSubscription<String>? _viewStartsSubscription;

  /// Single global write tail. All unseen mutations (across all sessions) are
  /// chained here so both per-session writes and the project-level aggregate
  /// emits happen in submission order — otherwise "mark A read"
  /// (aggregate=false) could be emitted after "B got activity" (aggregate=true)
  /// and leave clients with a stale `false`. The operations are tiny,
  /// infrequent DB writes, so the reduced concurrency is irrelevant.
  Future<void> _writeTail = Future<void>.value();

  SessionUnseenService({
    required SessionUnseenRepository unseenRepository,
    required ProjectRepository projectRepository,
    required SessionViewTracker viewTracker,
    int Function()? now,
  }) : _unseenRepository = unseenRepository,
       _projectRepository = projectRepository,
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

  /// Activity timestamp clamped above the row's persisted markers.
  ///
  /// [occurredAt] — the triggering message's own creation time — is preferred
  /// when available so activity stamps live in the same clock domain as the
  /// user-message markers (also stamped from creation times), keeping the
  /// unseen comparison meaningful under clock skew (remote `--opencode-host`)
  /// and delayed processing (reconnect backlog). The local monotonic clock is
  /// the fallback for events without a payload time.
  ///
  /// Either source is clamped above `max(userMessage, seen)`: stored markers
  /// can be ahead of the candidate (clock rollback, restart, cross-domain
  /// drift), and without the clamp a new activity could write a value <= the
  /// markers and the session would never bold.
  int _activityTimestamp({required int? userMessageAt, required int? seenAt, int? occurredAt}) {
    final floor = (userMessageAt ?? 0) > (seenAt ?? 0) ? (userMessageAt ?? 0) : (seenAt ?? 0);
    final candidate = occurredAt ?? _nextTimestamp();
    if (candidate > floor) return candidate;
    final at = floor + 1;
    if (at > _lastIssued) _lastIssued = at;
    return at;
  }

  /// Records activity for [sessionId]. No-op when the session has no persisted
  /// row. While the session is being viewed, the seen timestamp is advanced too
  /// so it never bolds under the watcher. Durable child timestamps remain
  /// available for child reads but do not independently affect project unseen
  /// aggregation.
  ///
  /// [occurredAt] is the triggering message's own creation time (ms epoch),
  /// when the caller has one. It keeps the message timeline in a single clock
  /// domain: user messages advance only their marker at that time (idempotent
  /// across re-emissions — see the guard below), and assistant activity is
  /// stamped from it so genuine replies compare correctly against prior
  /// activity even under clock skew or delayed processing.
  Future<void> recordActivity({
    required String sessionId,
    required bool isUserMessage,
    int? occurredAt,
  }) {
    // Capture the viewed state at submission time, not when the (possibly
    // delayed) serialized write executes — otherwise navigating away while
    // events are queued could persist already-viewed activity as unseen.
    final viewedAtSubmit = _viewTracker.isViewed(sessionId: sessionId);
    return _serialize(sessionId, () async {
      final row = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      if (row == null) return;
      // A user message may only count ONCE. Backends re-emit the user message
      // record whenever server-side bookkeeping attached to it changes (e.g.
      // OpenCode updates its diff summary mid- and post-response); treating a
      // re-emission as a fresh interaction would stamp `last_user_message_at`
      // past the assistant's activity and permanently clear the unseen state.
      // A re-emission carries the message's ORIGINAL creation time — never
      // newer than the marker stored when it was first processed (stamped from
      // that same creation time, see below) — so it is skipped entirely (its
      // content change is bookkeeping, not unseen-worthy transcript activity).
      if (isUserMessage && occurredAt != null && (row.userMessageAt ?? 0) >= occurredAt) {
        return;
      }
      // Coalesce repeated assistant activity: once the session is already
      // unseen and no phone is viewing it, another non-user event changes
      // nothing observable — skip the redundant write + emit. (A later
      // mark-read stamps seen at `now`, which is always past the skipped,
      // older activity timestamp, so correctness is preserved.)
      if (!isUserMessage && !viewedAtSubmit && _unseenRepository.unseenForRow(row)) {
        return;
      }
      // A user message with a known creation time advances ONLY the
      // user-message marker, stamped at that creation time. A user message
      // proves engagement as of when it was written; it must not rewrite the
      // activity/seen timeline — otherwise a re-emission that slips past the
      // guard above (a row whose marker was never stamped, e.g. learned via a
      // `/sessions` placeholder) would drag `last_activity_at` down onto the
      // old message and clear genuinely-unseen assistant activity. Whether the
      // session is seen falls out of the formula: a fresh reply's creation
      // time exceeds the (same-domain) activity stamp; an old re-emission's
      // does not.
      if (isUserMessage && occurredAt != null) {
        await _unseenRepository.recordUserMessage(sessionId: sessionId, at: occurredAt);
        await _emit(sessionId: sessionId, projectId: row.projectId);
        return;
      }
      await _unseenRepository.recordActivity(
        sessionId: sessionId,
        at: _activityTimestamp(
          userMessageAt: row.userMessageAt,
          seenAt: row.seenAt,
          occurredAt: isUserMessage ? null : occurredAt,
        ),
        isUserMessage: isUserMessage,
        advanceSeen: viewedAtSubmit,
      );
      await _emit(sessionId: sessionId, projectId: row.projectId);
    });
  }

  /// Records that a persisted ROOT session was created (observed live). Child
  /// sessions ([parentId] != null) and missing durable bindings are ignored.
  /// The root is stamped with activity so it is immediately unseen — unless a
  /// phone is already viewing it, in which case it stays seen.
  ///
  /// [occurredAt] is the session's own creation time, preferred for the stamp
  /// so it lives in the same clock domain as the message-derived stamps: the
  /// creator's first message (created at/after the session itself) then
  /// reliably clears this creation bold, which a locally-clocked stamp could
  /// prevent (SSE latency puts local processing time past the first message's
  /// creation time even without skew).
  Future<void> recordSessionCreated({
    required String sessionId,
    required String? parentId,
    int? occurredAt,
  }) {
    if (parentId != null) return Future<void>.value();
    final viewedAtSubmit = _viewTracker.isViewed(sessionId: sessionId);
    return _serialize(sessionId, () async {
      final existing = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      if (existing == null) return;
      // If an earlier activity event already stamped this row (it has any
      // unseen marker), don't overwrite it — that would advance activity past
      // the user's own message and wrongly bold it. But a bare placeholder
      // inserted by a `/sessions` refresh (no markers at all) must still be
      // stamped with creation activity so a new laptop-created session bolds
      // instead of staying seen forever.
      final hasMarkers = existing.activityAt != null || existing.userMessageAt != null || existing.seenAt != null;
      if (hasMarkers) {
        await _emit(sessionId: sessionId, projectId: existing.projectId);
        return;
      }
      await _unseenRepository.recordActivity(
        sessionId: sessionId,
        at: occurredAt ?? _nextTimestamp(),
        advanceSeen: viewedAtSubmit,
        isUserMessage: false,
      );
      await _emit(sessionId: sessionId, projectId: existing.projectId);
    });
  }

  /// Records that a session was deleted (observed live via `session.deleted`,
  /// whether the delete originated on a phone or on the laptop). Removes the
  /// persisted row so a stale unseen row can't keep its project's aggregate
  /// bold, and always emits the cleared state.
  ///
  /// The STORED row's project id is preferred over the event's [projectId]:
  /// for dedicated-worktree sessions the event payload can carry the worktree
  /// directory instead of the canonical project, which would recompute the
  /// wrong aggregate and leave the real project bold on other clients. The
  /// event id is only the fallback for a row-less delete.
  Future<void> recordSessionDeleted({required String sessionId, required String projectId}) {
    return _serialize(sessionId, () async {
      final row = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      await _deleteRowAndEmit(sessionId: sessionId, projectId: row?.projectId ?? projectId);
    });
  }

  /// Reconciles rows for sessions that vanished from the authoritative
  /// complete `/sessions` list of [projectId] — deleted while the bridge was
  /// offline, or backend-side without a `session.deleted` event. Shares the
  /// delete-and-emit pipeline with [recordSessionDeleted] so other connected
  /// clients settle their bold state without a manual refresh.
  ///
  /// [fetchStartedAt] is the wall-clock time the fetch began; rows created
  /// after it are kept (they are legitimately absent from the older snapshot).
  Future<void> reconcileVanishedSessions({
    required String pluginId,
    required String projectId,
    required List<String> keepSessionIds,
    required int fetchStartedAt,
  }) {
    return _serialize(projectId, () async {
      final deletedIds = await _unseenRepository.deleteSessionsNotIn(
        pluginId: pluginId,
        projectId: projectId,
        keepSessionIds: keepSessionIds,
        createdBefore: fetchStartedAt,
      );
      for (final sessionId in deletedIds) {
        await _emitDeleted(sessionId: sessionId, projectId: projectId);
      }
    });
  }

  /// "Mark as Read": stamp seen at max(now, lastActivity) so it clears.
  /// A missing row is a no-op success — with no row, no client can see the
  /// session bold from an authoritative source, so there is nothing to clear.
  /// Errors are propagated to the caller (this is a user-initiated request).
  Future<void> markRead({required String sessionId}) {
    return _serialize(sessionId, rethrowErrors: true, () async {
      final row = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      if (row == null) return;
      final now = _nextTimestamp();
      final seenAt = (row.activityAt ?? 0) > now ? row.activityAt! : now;
      await _unseenRepository.markSessionSeen(sessionId: sessionId, at: seenAt);
      // The row mutation has committed, so the request has succeeded. The
      // follow-up SSE emit is a best-effort notification (_emit swallows+logs):
      // propagating its failure would fail a request whose write already
      // landed, desyncing the requesting client from the persisted state.
      await _emit(sessionId: sessionId, projectId: row.projectId);
    });
  }

  /// "Mark as Unread": force the session bold regardless of prior state.
  /// A missing row (deleted / unknown session) cannot be made unread — throws
  /// [SessionUnseenRowMissingException] so the handler returns a non-2xx and
  /// the requesting client refreshes its optimistic state.
  /// Errors are propagated to the caller (this is a user-initiated request).
  Future<void> markUnread({required String sessionId}) {
    return _serialize(sessionId, rethrowErrors: true, () async {
      final row = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      if (row == null) {
        throw SessionUnseenRowMissingException(sessionId: sessionId);
      }
      // Force activity strictly past both the user-message and seen markers so
      // the session reliably bolds even when the user's own message is latest.
      final at = _activityTimestamp(userMessageAt: row.userMessageAt, seenAt: row.seenAt);
      await _unseenRepository.markSessionUnseen(sessionId: sessionId, at: at);
      // Committed write; the emit is best-effort (see markRead).
      await _emit(sessionId: sessionId, projectId: row.projectId);
    });
  }

  /// Recomputes and emits the unseen state for [sessionId] after a change made
  /// outside this service that can flip the project aggregate — archiving /
  /// unarchiving a session (archived rows are excluded from the aggregate).
  /// [projectId] is the STORED project id of the row.
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

  /// Shared delete pipeline: removes the row (no-op when absent) and emits the
  /// cleared per-session state plus the recomputed project aggregate.
  Future<void> _deleteRowAndEmit({required String sessionId, required String projectId}) async {
    await _unseenRepository.deleteSession(sessionId: sessionId);
    await _emitDeleted(sessionId: sessionId, projectId: projectId);
  }

  /// Emits the post-delete state for a session whose row is gone: per-session
  /// `unseen: false` plus the recomputed project aggregate. Best-effort.
  Future<void> _emitDeleted({required String sessionId, required String projectId}) async {
    try {
      final projectHasUnseen = await _projectRepository.projectHasUnseenChanges(projectId: projectId);
      _add(projectId: projectId, sessionId: sessionId, unseen: false, projectHasUnseenChanges: projectHasUnseen);
    } catch (error, stackTrace) {
      Log.w("failed to emit unseen clear for deleted session $sessionId", error, stackTrace);
    }
  }

  /// Recomputes and emits the current unseen state. Best-effort: failures are
  /// swallowed + logged so they can't fail a caller whose own write already
  /// committed (or that is fire-and-forget from the SSE path).
  Future<void> _emit({required String sessionId, required String projectId}) async {
    try {
      final unseen = await _unseenRepository.isUnseen(sessionId: sessionId);
      final projectHasUnseen = await _projectRepository.projectHasUnseenChanges(projectId: projectId);
      _add(projectId: projectId, sessionId: sessionId, unseen: unseen, projectHasUnseenChanges: projectHasUnseen);
    } catch (error, stackTrace) {
      Log.w("failed to compute/emit unseen change for session $sessionId", error, stackTrace);
    }
  }

  void _add({
    required String projectId,
    required String sessionId,
    required bool unseen,
    required bool projectHasUnseenChanges,
  }) {
    if (_changes.isClosed) return;
    _changes.add(
      (
        projectId: projectId,
        sessionId: sessionId,
        unseen: unseen,
        projectHasUnseenChanges: projectHasUnseenChanges,
      ),
    );
  }

  /// Runs [operation] after any in-flight unseen write completes (see
  /// [_writeTail] for why ordering is global).
  ///
  /// By default failures are caught and logged so fire-and-forget callers (the
  /// orchestrator's SSE path) never see an unhandled async error. User-initiated
  /// operations pass [rethrowErrors] so the failure surfaces to the request
  /// handler (which turns it into a non-2xx response) — while keeping the queue
  /// intact for writes chained after it.
  Future<void> _serialize(
    String contextId,
    Future<void> Function() operation, {
    bool rethrowErrors = false,
  }) {
    // The chain must continue regardless of this op's outcome, so the tail used
    // for ordering swallows errors; the returned future (for the caller) may
    // rethrow when requested.
    final result = _writeTail.then((_) => operation());
    _writeTail = result.catchError((Object error, StackTrace stackTrace) {
      Log.w("unseen update failed for $contextId", error, stackTrace);
    });
    return rethrowErrors ? result : _writeTail;
  }

  Future<void> dispose() async {
    await _viewStartsSubscription?.cancel();
    // Let the in-flight write queue drain (the tail swallows errors) before
    // closing the stream, so no operation runs against a closed controller.
    await _writeTail.catchError((_) {});
    await _changes.close();
  }
}
