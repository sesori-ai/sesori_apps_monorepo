import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../repositories/project_repository.dart";
import "../repositories/session_repository.dart";
import "../repositories/session_unseen_repository.dart";
import "session_view_tracker.dart";

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

  /// Per-session write tail. All mutations for one session are chained here so
  /// they commit in submission order — without this, two fire-and-forget
  /// activity events for the same session could persist out of order (e.g. a
  /// user message then an assistant message writing in reverse, wrongly
  /// clearing the unseen flag).
  final Map<String, Future<void>> _sessionWriteTails = {};

  /// Session ids that have no persisted row and didn't resolve to a project
  /// (i.e. child/subagent sessions). Cached so an active subagent doesn't turn
  /// every `message.part`/`message.updated` event into a full project scan via
  /// `findProjectIdForSession`.
  final Set<String> _unresolvedSessions = {};

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
    // Known child/subagent session — skip without re-resolving (avoids a full
    // project scan on every streamed part for an active subagent).
    if (_unresolvedSessions.contains(sessionId)) return Future<void>.value();
    // Capture the viewed state at submission time, not when the (possibly
    // delayed) serialized write executes — otherwise navigating away while
    // events are queued could persist already-viewed activity as unseen.
    final viewedAtSubmit = _viewTracker.isViewed(sessionId: sessionId);
    return _serialize(sessionId, () async {
      final row = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      if (row == null) {
        // Not yet persisted — try to resolve the project id and create a row
        // so activity isn't silently dropped (e.g. a root session created on
        // the laptop while the bridge was offline).
        final projectId = await _sessionRepository.findProjectIdForSession(sessionId: sessionId);
        if (projectId == null) {
          _unresolvedSessions.add(sessionId);
          return;
        }
        await _unseenRepository.ensureRootSessionActivity(
          sessionId: sessionId,
          projectId: projectId,
          activityAt: _activityTimestamp(userMessageAt: null, seenAt: null),
          advanceSeen: viewedAtSubmit,
        );
        await _emit(sessionId: sessionId, projectId: projectId);
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
      await _unseenRepository.ensureRootSessionActivity(
        sessionId: sessionId,
        projectId: projectId,
        activityAt: _nextTimestamp(),
        advanceSeen: viewedAtSubmit,
      );
      await _emit(sessionId: sessionId, projectId: projectId);
    });
  }

  /// "Mark as Read": stamp seen at max(now, lastActivity) so it clears.
  /// Errors are propagated to the caller (this is a user-initiated request).
  Future<void> markRead({required String sessionId}) {
    return _serialize(sessionId, rethrowErrors: true, () async {
      final row = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      if (row == null) return;
      final now = _nextTimestamp();
      final seenAt = (row.activityAt ?? 0) > now ? row.activityAt! : now;
      await _unseenRepository.markSessionSeen(sessionId: sessionId, at: seenAt);
      await _emit(sessionId: sessionId, projectId: row.projectId);
    });
  }

  /// "Mark as Unread": force the session bold regardless of prior state.
  /// Errors are propagated to the caller (this is a user-initiated request).
  Future<void> markUnread({required String sessionId}) {
    return _serialize(sessionId, rethrowErrors: true, () async {
      final row = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      if (row == null) return;
      // Force activity strictly past both the user-message and seen markers so
      // the session reliably bolds even when the user's own message is latest.
      final at = _activityTimestamp(userMessageAt: row.userMessageAt, seenAt: row.seenAt);
      await _unseenRepository.markSessionUnseen(sessionId: sessionId, at: at);
      await _emit(sessionId: sessionId, projectId: row.projectId);
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

  /// Runs [operation] after any in-flight write for [sessionId] completes, so
  /// ordered events for the same session commit in order.
  ///
  /// By default failures are caught and logged so fire-and-forget callers (the
  /// orchestrator's SSE path) never see an unhandled async error. User-initiated
  /// operations pass [rethrowErrors] so the failure surfaces to the request
  /// handler (which turns it into a non-2xx response) — while still keeping the
  /// per-session ordering intact for any writes chained after it.
  Future<void> _serialize(
    String sessionId,
    Future<void> Function() operation, {
    bool rethrowErrors = false,
  }) {
    final previous = _sessionWriteTails[sessionId] ?? Future<void>.value();
    // The chain must continue regardless of this op's outcome, so the tail used
    // for ordering swallows errors; the returned future (for the caller) may
    // rethrow when requested.
    final result = previous.then((_) => operation());
    final tail = result.catchError((Object error, StackTrace stackTrace) {
      Log.w("unseen update failed for session $sessionId", error, stackTrace);
    });
    _sessionWriteTails[sessionId] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_sessionWriteTails[sessionId], tail)) {
          _sessionWriteTails.remove(sessionId);
        }
      }),
    );
    return rethrowErrors ? result : tail;
  }

  Future<void> _emit({required String sessionId, required String projectId}) async {
    try {
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
    } catch (error, stackTrace) {
      Log.w("failed to compute/emit unseen change for session $sessionId", error, stackTrace);
    }
  }

  Future<void> dispose() async {
    await _viewStartsSubscription?.cancel();
    // Let in-flight serialized writes finish (their tails swallow errors) before
    // closing the stream, so no operation runs against a closed controller.
    await Future.wait(_sessionWriteTails.values).catchError((_) => const <void>[]);
    await _changes.close();
  }
}
