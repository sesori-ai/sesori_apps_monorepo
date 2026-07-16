import "dart:async";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/sse_event.dart";
import "../logging/logging.dart";

/// Layer-2 tracker that mirrors the bridge's attention metadata for projects
/// and sessions: unseen state and the latest persisted user interaction. The
/// bridge is the single authority; this class only records live
/// `SesoriSessionUnseenChanged` events and REST snapshots. Momentary
/// inconsistency in a rare
/// event-vs-fetch interleaving is accepted; it self-heals on the next event or
/// refetch (both list cubits already refetch on reconnect).
///
/// A REST response is a snapshot from the past, so a seed must not overwrite
/// state updated while the fetch was in flight. Cubits capture [tick] before
/// fetching; seeds preserve newer project aggregates and individual session
/// fields while still applying the snapshot to unaffected sessions.
@lazySingleton
class SessionAttentionTracker with Disposable {
  final FailureReporter _failureReporter;
  late final StreamSubscription<SseEvent> _subscription;

  // project ID -> whether the project has any unseen session.
  final BehaviorSubject<Map<String, bool>> _projectUnseen = BehaviorSubject.seeded(const {});

  // project ID -> (session ID -> unseen).
  final BehaviorSubject<Map<String, Map<String, bool>>> _sessionUnseen = BehaviorSubject.seeded(const {});

  // project ID -> latest persisted user-originated interaction.
  final BehaviorSubject<Map<String, int?>> _projectLastUserInteractionAt = BehaviorSubject.seeded(const {});

  // project ID -> (session ID -> latest persisted user-originated interaction).
  final BehaviorSubject<Map<String, Map<String, int?>>> _sessionLastUserInteractionAt = BehaviorSubject.seeded(
    const {},
  );

  int _tick = 0;
  // project ID -> tick of its last live update.
  final Map<String, int> _projectTick = {};
  // project ID -> (session ID -> tick of its last live/local unseen update).
  final Map<String, Map<String, int>> _sessionUnseenTick = {};
  // project ID -> (session ID -> tick of its last live interaction update).
  final Map<String, Map<String, int>> _sessionInteractionTick = {};

  SessionAttentionTracker({
    required ConnectionService connectionService,
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

  ValueStream<Map<String, int?>> get projectLastUserInteractionAt => _projectLastUserInteractionAt.stream;

  Map<String, int?> get currentProjectLastUserInteractionAt => _projectLastUserInteractionAt.value;

  ValueStream<Map<String, Map<String, int?>>> get sessionLastUserInteractionAt => _sessionLastUserInteractionAt.stream;

  Map<String, Map<String, int?>> get currentSessionLastUserInteractionAt => _sessionLastUserInteractionAt.value;

  /// Seeds the per-project aggregates from a `/projects` response. Projects
  /// updated live since [sinceTick] keep their (fresher) live value.
  void seedProjects(
    Map<String, bool> unseenByProjectId, {
    required Map<String, int?> lastUserInteractionAtByProjectId,
    required int sinceTick,
  }) {
    if (_projectUnseen.isClosed || _projectLastUserInteractionAt.isClosed) return;
    final projects = Map<String, bool>.from(_projectUnseen.value);
    final interactions = Map<String, int?>.from(_projectLastUserInteractionAt.value);
    for (final entry in unseenByProjectId.entries) {
      if ((_projectTick[entry.key] ?? 0) > sinceTick) continue;
      projects[entry.key] = entry.value;
      interactions[entry.key] = lastUserInteractionAtByProjectId[entry.key];
    }
    _projectUnseen.add(projects);
    _projectLastUserInteractionAt.add(interactions);
  }

  /// Seeds per-session metadata for [projectId] from a `/sessions` response.
  /// The snapshot replaces entries that have not changed since [sinceTick], so
  /// deleted rows drop out while newer live/local values remain intact.
  void seedSessions({
    required String projectId,
    required Map<String, bool> unseenBySessionId,
    required Map<String, int?> lastUserInteractionAtBySessionId,
    required int sinceTick,
  }) {
    if (_sessionUnseen.isClosed || _sessionLastUserInteractionAt.isClosed) return;
    final sessions = Map<String, Map<String, bool>>.from(_sessionUnseen.value);
    final interactions = Map<String, Map<String, int?>>.from(_sessionLastUserInteractionAt.value);
    final projectSessions = Map<String, bool>.from(unseenBySessionId);
    final currentProjectSessions = sessions[projectId] ?? const {};
    for (final entry in currentProjectSessions.entries) {
      if ((_sessionUnseenTick[projectId]?[entry.key] ?? 0) > sinceTick) {
        projectSessions[entry.key] = entry.value;
      }
    }
    sessions[projectId] = Map<String, bool>.unmodifiable(projectSessions);

    final projectInteractions = Map<String, int?>.from(lastUserInteractionAtBySessionId);
    final currentProjectInteractions = interactions[projectId] ?? const {};
    for (final entry in currentProjectInteractions.entries) {
      if ((_sessionInteractionTick[projectId]?[entry.key] ?? 0) > sinceTick) {
        projectInteractions[entry.key] = entry.value;
      }
    }
    interactions[projectId] = Map<String, int?>.unmodifiable(projectInteractions);
    _sessionUnseen.add(sessions);
    _sessionLastUserInteractionAt.add(interactions);
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
    final updateTick = ++_tick;
    _sessionUnseenTick.putIfAbsent(projectId, () => {})[sessionId] = updateTick;
    final sessions = Map<String, Map<String, bool>>.from(_sessionUnseen.value);
    final projectSessions = Map<String, bool>.from(sessions[projectId] ?? const {});
    projectSessions[sessionId] = unseen;
    sessions[projectId] = projectSessions;
    _sessionUnseen.add(sessions);
  }

  void _handleEvent(SseEvent event) {
    try {
      if (event.data case SesoriSessionUnseenChanged(
        :final projectID,
        :final sessionId,
        :final unseen,
        :final projectHasUnseenChanges,
        :final sessionLastUserInteractionAt,
        :final projectLastUserInteractionAt,
      )) {
        // A late event can race disposal (the subscription cancel is not
        // awaited); adding to a closed subject would throw and be reported as
        // a false-positive failure.
        if (_projectUnseen.isClosed ||
            _sessionUnseen.isClosed ||
            _projectLastUserInteractionAt.isClosed ||
            _sessionLastUserInteractionAt.isClosed) {
          return;
        }
        final updateTick = ++_tick;
        _projectTick[projectID] = updateTick;
        _sessionUnseenTick.putIfAbsent(projectID, () => {})[sessionId] = updateTick;
        _sessionInteractionTick.putIfAbsent(projectID, () => {})[sessionId] = updateTick;

        final projects = Map<String, bool>.from(_projectUnseen.value);
        projects[projectID] = projectHasUnseenChanges;
        _projectUnseen.add(projects);

        final sessions = Map<String, Map<String, bool>>.from(_sessionUnseen.value);
        final projectSessions = Map<String, bool>.from(sessions[projectID] ?? const {});
        projectSessions[sessionId] = unseen;
        sessions[projectID] = projectSessions;
        _sessionUnseen.add(sessions);

        final projectInteractions = Map<String, int?>.from(_projectLastUserInteractionAt.value);
        projectInteractions[projectID] = projectLastUserInteractionAt;
        _projectLastUserInteractionAt.add(projectInteractions);

        final sessionInteractions = Map<String, Map<String, int?>>.from(_sessionLastUserInteractionAt.value);
        final projectSessionInteractions = Map<String, int?>.from(sessionInteractions[projectID] ?? const {});
        projectSessionInteractions[sessionId] = sessionLastUserInteractionAt;
        sessionInteractions[projectID] = projectSessionInteractions;
        _sessionLastUserInteractionAt.add(sessionInteractions);
      }
    } catch (e, st) {
      loge("SessionAttentionTracker event handler error", e, st);
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "session_attention_tracker:${event.data.runtimeType.toString()}",
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
    _projectLastUserInteractionAt.close();
    _sessionLastUserInteractionAt.close();
  }
}
