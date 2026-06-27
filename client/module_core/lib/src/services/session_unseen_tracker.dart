import "dart:async";

import "package:get_it/get_it.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/sse_event.dart";
import "../logging/logging.dart";

/// Layer-3 tracker that maintains the real-time unseen (new-changes) state for
/// projects and sessions from the bridge's `SesoriSessionUnseenChanged` SSE
/// events. The project list and session list cubits subscribe to its streams;
/// initial state comes from the REST loads (`Project.hasUnseenChanges` /
/// `Session.unseen`), with these maps taking precedence once populated.
@lazySingleton
class SessionUnseenTracker with Disposable {
  final FailureReporter _failureReporter;
  late final StreamSubscription<SseEvent> _subscription;

  // project ID -> whether the project has any unseen session.
  final BehaviorSubject<Map<String, bool>> _projectUnseen = BehaviorSubject.seeded(const {});

  // project ID -> (session ID -> unseen).
  final BehaviorSubject<Map<String, Map<String, bool>>> _sessionUnseen = BehaviorSubject.seeded(const {});

  // Monotonic counter bumped on every live SSE update. A REST reconcile captures
  // the current generation before its fetch and skips any entry that received a
  // newer live update meanwhile — so a slow REST response can't clobber fresher
  // live state (a race the cubit's combined session+base-branch await opens).
  //
  // Guarding is per-entity, not per-project: a project's aggregate uses
  // [_projectLiveGeneration] (the `/projects` REST snapshot has no per-session
  // detail), while a `/sessions` reconcile guards each session independently via
  // [_sessionLiveGeneration] so an unrelated live update for one session does
  // not discard the REST clear for its siblings.
  int _generation = 0;
  final Map<String, int> _projectLiveGeneration = {};
  // project ID -> (session ID -> generation of its last live update).
  final Map<String, Map<String, int>> _sessionLiveGeneration = {};

  SessionUnseenTracker(
    ConnectionService connectionService, {
    required FailureReporter failureReporter,
  }) : _failureReporter = failureReporter {
    _subscription = connectionService.events.listen(_handleEvent);
  }

  /// Snapshot of the live-update generation. Capture this before starting a REST
  /// fetch and pass it back to a `reconcile*` call to guard against overwriting
  /// newer live updates that arrive while the fetch is in flight.
  int get generation => _generation;

  /// project ID -> whether it has unseen changes. Late subscribers get the
  /// latest cached value.
  ValueStream<Map<String, bool>> get projectUnseen => _projectUnseen.stream;

  Map<String, bool> get currentProjectUnseen => _projectUnseen.value;

  /// project ID -> (session ID -> unseen). Late subscribers get the latest
  /// cached value.
  ValueStream<Map<String, Map<String, bool>>> get sessionUnseen => _sessionUnseen.stream;

  Map<String, Map<String, bool>> get currentSessionUnseen => _sessionUnseen.value;

  /// Reconciles the per-project unseen aggregate from an authoritative source
  /// (a REST `/projects` refresh). This keeps the tracker as the single source
  /// of truth so a stale live `true` (e.g. after the last unseen session was
  /// archived without a follow-up SSE event) cannot indefinitely override a
  /// fresh aggregate.
  ///
  /// [sinceGeneration] is the [generation] captured before the fetch started;
  /// projects that received a newer live update meanwhile are left untouched so
  /// the slow REST snapshot can't clobber fresher live state.
  void reconcileProjectUnseen(Map<String, bool> unseenByProjectId, {required int sinceGeneration}) {
    if (_projectUnseen.isClosed) return;
    final projects = Map<String, bool>.from(_projectUnseen.value);
    for (final entry in unseenByProjectId.entries) {
      if ((_projectLiveGeneration[entry.key] ?? 0) > sinceGeneration) continue;
      projects[entry.key] = entry.value;
    }
    _projectUnseen.add(projects);
  }

  /// Reconciles the per-session unseen state for [projectId] from an
  /// authoritative source (a REST `/sessions` refresh). Replaces the tracked
  /// session map for that project so a stale live `true` cannot keep a row bold
  /// after a clear event was missed (e.g. the session was seen on another phone
  /// while this client was reconnecting). Also refreshes the project-level
  /// aggregate so the two stay consistent.
  ///
  /// Each session is guarded independently: a session that received a newer live
  /// update since [sinceGeneration] (captured before the fetch) keeps its live
  /// value, while its siblings are still reconciled from the REST snapshot. This
  /// prevents an unrelated live update from discarding the whole snapshot (so a
  /// missed clear for one session isn't stranded by activity on another).
  ///
  /// A session that became unseen via a newer live update but is absent from the
  /// REST snapshot (e.g. a `session.created`/unseen event landed while an older
  /// `/sessions` request was still in flight) is preserved rather than dropped,
  /// so a freshly-created unseen session doesn't lose its bold until the next
  /// refresh — BUT only while the project's latest live aggregate still reports
  /// unseen. An archived session is intentionally omitted from `/sessions`; its
  /// archive event sets the project aggregate to false even though the
  /// per-session `unseen` flag (derived from timestamps) can still be true, so
  /// preserving it would wrongly re-bold the project. Gating on the live project
  /// aggregate keeps creations (aggregate true) while dropping archives
  /// (aggregate false).
  void reconcileSessionUnseen({
    required String projectId,
    required Map<String, bool> unseenBySessionId,
    required int sinceGeneration,
  }) {
    if (_sessionUnseen.isClosed) return;

    final sessions = Map<String, Map<String, bool>>.from(_sessionUnseen.value);
    final liveGenerations = _sessionLiveGeneration[projectId] ?? const {};
    final existing = sessions[projectId] ?? const {};
    final merged = <String, bool>{};
    for (final entry in unseenBySessionId.entries) {
      // Keep the live value for a session that changed after the fetch began;
      // otherwise take the authoritative REST value.
      if ((liveGenerations[entry.key] ?? 0) > sinceGeneration) {
        merged[entry.key] = existing[entry.key] ?? entry.value;
      } else {
        merged[entry.key] = entry.value;
      }
    }
    // Carry forward an unseen session that got a newer live update but is absent
    // from the REST snapshot — but only when the project's latest live aggregate
    // still reports unseen, so an archived (de-aggregated) session is dropped
    // while a freshly-created one is kept.
    final projectStillUnseenLive = _projectUnseen.value[projectId] ?? false;
    if (projectStillUnseenLive) {
      for (final entry in existing.entries) {
        if (merged.containsKey(entry.key)) continue;
        if (entry.value && (liveGenerations[entry.key] ?? 0) > sinceGeneration) {
          merged[entry.key] = entry.value;
        }
      }
    }
    sessions[projectId] = merged;
    _sessionUnseen.add(sessions);

    final projects = Map<String, bool>.from(_projectUnseen.value);
    projects[projectId] = merged.values.any((unseen) => unseen);
    _projectUnseen.add(projects);
  }

  /// Applies a local, optimistic unseen change for one session — e.g. an
  /// in-flight "mark as read/unread" — so the tracker (the source of truth the
  /// list cubits recompute from) reflects the action immediately rather than
  /// waiting for the bridge's `session.unseen_changed` echo, which can be
  /// delayed or missed across a reconnect. Without this the cubit's optimistic
  /// state could be clobbered by any unrelated recompute that re-reads the
  /// tracker's stale value.
  ///
  /// Bumps the live generation so a slow REST reconcile in flight can't override
  /// it before the echo lands. The authoritative echo, when it arrives,
  /// overwrites this with the bridge's recomputed aggregate. The project
  /// aggregate is recomputed from the (post-load complete) per-session map.
  void applyLocalSessionUnseen({
    required String projectId,
    required String sessionId,
    required bool unseen,
  }) {
    if (_sessionUnseen.isClosed) return;
    final generation = ++_generation;
    _projectLiveGeneration[projectId] = generation;
    (_sessionLiveGeneration[projectId] ??= {})[sessionId] = generation;

    final sessions = Map<String, Map<String, bool>>.from(_sessionUnseen.value);
    final projectSessions = Map<String, bool>.from(sessions[projectId] ?? const {});
    projectSessions[sessionId] = unseen;
    sessions[projectId] = projectSessions;
    _sessionUnseen.add(sessions);

    final projects = Map<String, bool>.from(_projectUnseen.value);
    projects[projectId] = projectSessions.values.any((u) => u);
    _projectUnseen.add(projects);
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
        final generation = ++_generation;
        _projectLiveGeneration[projectID] = generation;
        (_sessionLiveGeneration[projectID] ??= {})[sessionId] = generation;

        final projects = Map<String, bool>.from(_projectUnseen.value);
        projects[projectID] = projectHasUnseenChanges;
        _projectUnseen.add(projects);

        // Copy only the outer map and the affected project's inner map
        // (O(sessions in this project)), not every project's sessions.
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
            .catchError((_) {}),
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
