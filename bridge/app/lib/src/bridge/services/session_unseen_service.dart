import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../repositories/project_repository.dart";
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
  final SessionViewTracker _viewTracker;
  final int Function() _now;

  final StreamController<UnseenChange> _changes = StreamController<UnseenChange>.broadcast();
  StreamSubscription<String>? _viewStartsSubscription;

  /// Per-session write tail. All mutations for one session are chained here so
  /// they commit in submission order — without this, two fire-and-forget
  /// activity events for the same session could persist out of order (e.g. a
  /// user message then an assistant message writing in reverse, wrongly
  /// clearing the unseen flag).
  final Map<String, Future<void>> _sessionWriteTails = {};

  SessionUnseenService({
    required SessionUnseenRepository unseenRepository,
    required ProjectRepository projectRepository,
    required SessionViewTracker viewTracker,
    int Function()? now,
  }) : _unseenRepository = unseenRepository,
       _projectRepository = projectRepository,
       _viewTracker = viewTracker,
       _now = now ?? (() => DateTime.now().millisecondsSinceEpoch) {
    _viewStartsSubscription = _viewTracker.viewStarts.listen(_onViewStarted);
  }

  /// Emits whenever a session's unseen state (or its project's aggregate) may
  /// have changed.
  Stream<UnseenChange> get unseenChanges => _changes.stream;

  /// Records activity for [sessionId]. No-op when the session has no persisted
  /// row (child/subagent sessions, or sessions not yet learned). While the
  /// session is being viewed, the seen timestamp is advanced too so it never
  /// bolds under the watcher.
  Future<void> recordActivity({
    required String sessionId,
    required int at,
    required bool isUserMessage,
  }) {
    return _serialize(sessionId, () async {
      final row = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      if (row == null) return;
      final advanceSeen = _viewTracker.isViewed(sessionId: sessionId);
      await _unseenRepository.recordActivity(
        sessionId: sessionId,
        at: at,
        isUserMessage: isUserMessage,
        advanceSeen: advanceSeen,
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
    required int createdAt,
  }) {
    if (parentId != null) return Future<void>.value();
    return _serialize(sessionId, () async {
      await _unseenRepository.ensureRootSessionActivity(
        sessionId: sessionId,
        projectId: projectId,
        createdAt: createdAt,
        advanceSeen: _viewTracker.isViewed(sessionId: sessionId),
      );
      await _emit(sessionId: sessionId, projectId: projectId);
    });
  }

  /// "Mark as Read": stamp seen at max(now, lastActivity) so it clears.
  Future<void> markRead({required String sessionId}) {
    return _serialize(sessionId, () async {
      final row = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      if (row == null) return;
      final seenAt = (row.activityAt ?? 0) > _now() ? row.activityAt! : _now();
      await _unseenRepository.markSessionSeen(sessionId: sessionId, at: seenAt);
      await _emit(sessionId: sessionId, projectId: row.projectId);
    });
  }

  /// "Mark as Unread": force the session bold regardless of prior state.
  Future<void> markUnread({required String sessionId}) {
    return _serialize(sessionId, () async {
      final row = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      if (row == null) return;
      await _unseenRepository.markSessionUnseen(sessionId: sessionId, at: _now());
      await _emit(sessionId: sessionId, projectId: row.projectId);
    });
  }

  Future<void> _onViewStarted(String sessionId) {
    return _serialize(sessionId, () async {
      final row = await _unseenRepository.getUnseenRow(sessionId: sessionId);
      if (row == null) return;
      await _unseenRepository.markSessionSeen(sessionId: sessionId, at: _now());
      await _emit(sessionId: sessionId, projectId: row.projectId);
    });
  }

  /// Runs [operation] after any in-flight write for [sessionId] completes, so
  /// ordered events for the same session commit in order. Failures are caught
  /// and logged here so callers (including fire-and-forget `unawaited` paths in
  /// the orchestrator) never see an unhandled async error.
  Future<void> _serialize(String sessionId, Future<void> Function() operation) {
    final previous = _sessionWriteTails[sessionId] ?? Future<void>.value();
    final next = previous.then((_) => operation()).catchError((Object error, StackTrace stackTrace) {
      Log.w("unseen update failed for session $sessionId", error, stackTrace);
    });
    _sessionWriteTails[sessionId] = next;
    // Drop the tail once it settles if nothing newer chained onto it, so the
    // map does not grow unbounded across many sessions.
    unawaited(
      next.whenComplete(() {
        if (identical(_sessionWriteTails[sessionId], next)) {
          _sessionWriteTails.remove(sessionId);
        }
      }),
    );
    return next;
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
    await _changes.close();
  }
}
