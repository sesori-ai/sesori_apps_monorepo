import "dart:async";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/sse_event.dart";
import "../logging/logging.dart";

/// Layer-3 tracker that mirrors the bridge's unseen (new-changes) state for
/// projects and sessions. The bridge is the single authority: this class only
/// records what the bridge said — live `SesoriSessionUnseenChanged` SSE events
/// and REST-fetched flags (via the `seed*` methods) — and never computes or
/// adjusts unseen state itself. Momentary inconsistency in a rare
/// event-vs-fetch interleaving is accepted; it self-heals on the next event or
/// refetch (both list cubits already refetch on reconnect).
///
/// One guard exists: [tick]. A REST response is a snapshot from the past, so a
/// seed must not overwrite a project that received a LIVE update (or a local
/// optimistic apply) while the fetch was in flight — most visibly when
/// `/sessions` is held for seconds by the PR-data wait. Cubits capture [tick]
/// before fetching; seeds skip projects whose last update is newer.
@lazySingleton
class SessionUnseenTracker with Disposable {
  final FailureReporter _failureReporter;
  late final StreamSubscription<SseEvent> _subscription;

  // project ID -> whether the project has any unseen session.
  final BehaviorSubject<Map<String, bool>> _projectUnseen = BehaviorSubject.seeded(const {});

  // project ID -> (session ID -> unseen).
  final BehaviorSubject<Map<String, Map<String, bool>>> _sessionUnseen = BehaviorSubject.seeded(const {});

  int _tick = 0;
  // project ID -> tick of its last live/local update.
  final Map<String, int> _projectTick = {};

  SessionUnseenTracker(
    ConnectionService connectionService, {
    required FailureReporter failureReporter,
  }) : _failureReporter = failureReporter {
    _subscription = connectionService.events.listen(_handleEvent);
  }

  /// Monotonic update counter. Capture before starting a REST fetch and pass it
  /// to a `seed*` call so a stale snapshot can't overwrite fresher live state.
  int get tick => _tick;

  /// project ID -> whether it has unseen changes. Late subscribers get the
  /// latest cached value.
  ValueStream<Map<String, bool>> get projectUnseen => _projectUnseen.stream;

  Map<String, bool> get currentProjectUnseen => _projectUnseen.value;

  /// project ID -> (session ID -> unseen). Late subscribers get the latest
  /// cached value.
  ValueStream<Map<String, Map<String, bool>>> get sessionUnseen => _sessionUnseen.stream;

  Map<String, Map<String, bool>> get currentSessionUnseen => _sessionUnseen.value;

  /// Seeds the per-project aggregates from a `/projects` response. Projects
  /// updated live since [sinceTick] keep their (fresher) live value.
  void seedProjects(Map<String, bool> unseenByProjectId, {required int sinceTick}) {
    if (_projectUnseen.isClosed) return;
    final projects = Map<String, bool>.from(_projectUnseen.value);
    for (final entry in unseenByProjectId.entries) {
      if ((_projectTick[entry.key] ?? 0) > sinceTick) continue;
      projects[entry.key] = entry.value;
    }
    _projectUnseen.add(projects);
  }

  /// Seeds the per-session flags for [projectId] from a `/sessions` response,
  /// REPLACING the project's tracked map (sessions absent from the
  /// authoritative list — deleted rows — drop out naturally). Skipped entirely
  /// when the project was updated live since [sinceTick].
  void seedSessions({
    required String projectId,
    required Map<String, bool> unseenBySessionId,
    required int sinceTick,
  }) {
    if (_sessionUnseen.isClosed) return;
    if ((_projectTick[projectId] ?? 0) > sinceTick) return;
    final sessions = Map<String, Map<String, bool>>.from(_sessionUnseen.value);
    sessions[projectId] = Map<String, bool>.unmodifiable(unseenBySessionId);
    _sessionUnseen.add(sessions);
  }

  /// Applies a local, optimistic per-session change for an in-flight
  /// mark-read/unread, so the row updates immediately. The project aggregate is
  /// deliberately NOT touched: only the bridge knows which sessions count
  /// toward it (archived rows are excluded), and its echo lands within the
  /// round trip. On request failure the caller refetches, which re-seeds the
  /// authoritative state — there is no local rollback bookkeeping.
  void applyLocalSessionUnseen({
    required String projectId,
    required String sessionId,
    required bool unseen,
  }) {
    if (_sessionUnseen.isClosed) return;
    // Stamp the tick so an in-flight stale snapshot can't clobber the user's
    // explicit action before the bridge echo settles it.
    _projectTick[projectId] = ++_tick;
    final sessions = Map<String, Map<String, bool>>.from(_sessionUnseen.value);
    final projectSessions = Map<String, bool>.from(sessions[projectId] ?? const {});
    projectSessions[sessionId] = unseen;
    sessions[projectId] = projectSessions;
    _sessionUnseen.add(sessions);
  }

  void _handleEvent(SseEvent event) {
    try {
      if (event.data
          case SesoriSessionUnseenChanged(
            :final projectID,
            :final sessionId,
            :final unseen,
            :final projectHasUnseenChanges,
          )) {
        // A late event can race disposal (the subscription cancel is not
        // awaited); adding to a closed subject would throw and be reported as
        // a false-positive failure.
        if (_projectUnseen.isClosed || _sessionUnseen.isClosed) return;
        _projectTick[projectID] = ++_tick;

        final projects = Map<String, bool>.from(_projectUnseen.value);
        projects[projectID] = projectHasUnseenChanges;
        _projectUnseen.add(projects);

        final sessions = Map<String, Map<String, bool>>.from(_sessionUnseen.value);
        final projectSessions = Map<String, bool>.from(sessions[projectID] ?? const {});
        projectSessions[sessionId] = unseen;
        sessions[projectID] = projectSessions;
        _sessionUnseen.add(sessions);
      }
    } catch (e, st) {
      loge("SessionUnseenTracker event handler error", e, st);
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "session_unseen_tracker:${event.data.runtimeType.toString()}",
              fatal: false,
              reason: "Failed to handle unseen SSE event",
              information: [event.data.runtimeType.toString()],
            )
            .catchError((Object error, StackTrace stackTrace) {
              loge("Failed to report unseen-event handler error", error, stackTrace);
            }),
      );
    }
  }

  @override
  FutureOr<void> onDispose() {
    _subscription.cancel();
    _projectUnseen.close();
    _sessionUnseen.close();
  }
}
