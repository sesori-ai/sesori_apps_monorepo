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
  // project ID -> (session ID -> generation of its last LIVE update). Bumped
  // ONLY by live SSE events and local optimistic applies — NOT by REST
  // reconciles. A `/sessions` reconcile uses this to keep a fresher live value
  // over its (possibly stale) snapshot; recording REST values here would let an
  // older overlapping REST response make a session look "live-newer" and cause a
  // newer REST reconcile to preserve the stale value.
  final Map<String, Map<String, int>> _sessionLiveGeneration = {};
  // project ID -> (session ID -> generation of its last MUTATION of any kind:
  // live event, local apply, OR a REST reconcile that changed its value). Used
  // solely by [revertLocalSessionUnseen] to detect whether anything changed the
  // session since an optimistic apply, so a failed-request rollback never
  // clobbers a newer authoritative value.
  final Map<String, Map<String, int>> _sessionMutationGeneration = {};

  // project ID -> session IDs known to be EXCLUDED from the project aggregate
  // (archived). The bridge omits archived sessions from the aggregate, so an
  // archive event arrives as unseen:true (per-session, from timestamps) together
  // with projectHasUnseenChanges:false — a combination only possible when this
  // session does not count toward the aggregate. Tracking these lets the local
  // optimistic mark path skip a mark-unread that would otherwise re-bold the
  // project via an archived row.
  final Map<String, Set<String>> _excludedSessions = {};

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
    var changed = false;
    final appliedGeneration = ++_generation;
    for (final entry in unseenByProjectId.entries) {
      if ((_projectLiveGeneration[entry.key] ?? 0) > sinceGeneration) continue;
      // Treat the applied /projects value as authoritative as of now: stamp the
      // project generation so an older /sessions response (which can be delayed
      // by waitForPrData and started before an archive/read) can't later
      // recompute this aggregate back from its stale session snapshot.
      _projectLiveGeneration[entry.key] = appliedGeneration;
      projects[entry.key] = entry.value;
      changed = true;
    }
    if (changed) _projectUnseen.add(projects);
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
    Set<String> archivedSessionIds = const {},
  }) {
    if (_sessionUnseen.isClosed) return;

    final sessions = Map<String, Map<String, bool>>.from(_sessionUnseen.value);
    final liveGenerations = _sessionLiveGeneration[projectId] ??= {};
    final existing = sessions[projectId] ?? const {};
    final excluded = _excludedSessions[projectId];
    // Record the archived rows the REST list reported as excluded from the
    // aggregate, so an optimistic mark-unread of an archived session (even one
    // never seen as a live archive event) doesn't locally re-bold the project.
    // Guard each id against newer live state: if a session was archived in this
    // (possibly stale) snapshot but a newer live update arrived since the fetch
    // began (e.g. an unarchive), don't mark it excluded — the live state wins.
    for (final archivedId in archivedSessionIds) {
      if ((liveGenerations[archivedId] ?? 0) > sinceGeneration) continue;
      (_excludedSessions[projectId] ??= <String>{}).add(archivedId);
    }
    final merged = <String, bool>{};
    for (final entry in unseenBySessionId.entries) {
      // A session present in the authoritative /sessions list is not archived
      // (archived rows are omitted), so it no longer counts as excluded.
      excluded?.remove(entry.key);
      // Keep the live value for a session that changed after the fetch began;
      // otherwise take the authoritative REST value.
      if ((liveGenerations[entry.key] ?? 0) > sinceGeneration) {
        merged[entry.key] = existing[entry.key] ?? entry.value;
      } else {
        merged[entry.key] = entry.value;
      }
    }
    // Carry forward a session that got a newer live update but is absent from
    // the (older) REST snapshot — but only when the project's latest live
    // aggregate still reports unseen. A session whose newest live update predates
    // this fetch and is now absent has left the authoritative list (archived /
    // deleted) and is dropped; one with a newer-than-fetch live update is a
    // session created after the snapshot began, so its bold is preserved.
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

    // Stamp the MUTATION generation (not the live one) for sessions whose value
    // actually changed. This invalidates an in-flight optimistic rollback for a
    // session this authoritative REST reconcile updated (the late revert becomes
    // a no-op), while leaving an unchanged session's generation intact so a
    // legitimate post-failure revert of THAT session still applies. It must NOT
    // touch the live-generation map — otherwise an older overlapping REST
    // response would make a session look live-newer and cause a newer REST
    // reconcile (with the same captured sinceGeneration) to keep the stale value.
    final reconcileGeneration = ++_generation;
    final mutationGenerations = _sessionMutationGeneration[projectId] ??= {};
    for (final entry in merged.entries) {
      if (existing[entry.key] != entry.value) {
        mutationGenerations[entry.key] = reconcileGeneration;
      }
    }

    final projects = Map<String, bool>.from(_projectUnseen.value);
    // If a newer live aggregate arrived since the fetch began (e.g. an archive
    // SSE set it false while this slow /sessions response still lists the
    // archived session as present+unseen), keep that authoritative live value
    // rather than recomputing from the stale snapshot. Otherwise recompute over
    // the AUTHORITATIVE REST snapshot only (archived rows are already omitted
    // from it) — never over `merged`, so a carried-forward absent session (whose
    // archival the client can't detect) can't inflate the project aggregate.
    if ((_projectLiveGeneration[projectId] ?? 0) <= sinceGeneration) {
      _projectLiveGeneration[projectId] = reconcileGeneration;
      projects[projectId] = unseenBySessionId.values.any((unseen) => unseen);
      _projectUnseen.add(projects);
    }
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
  /// overwrites this with the bridge's recomputed aggregate.
  ///
  /// The project aggregate is updated only conservatively: marking a session
  /// UNREAD bolds the project (definitely correct), but marking READ does NOT
  /// recompute the aggregate from the per-session map — the client can't know
  /// which other sessions are archived/excluded on the bridge, so a downward
  /// recompute could wrongly clear (or, with a stale archived entry, wrongly
  /// keep) the project bold. The authoritative bridge echo settles it instead.
  ///
  /// Returns the mutation generation assigned to this update. Pass it to
  /// [revertLocalSessionUnseen] to roll back only when no newer update landed.
  int applyLocalSessionUnseen({
    required String projectId,
    required String sessionId,
    required bool unseen,
  }) {
    if (_sessionUnseen.isClosed) return _generation;
    final generation = ++_generation;
    // A local optimistic change is both a live-style update (protect it from a
    // stale in-flight REST snapshot) and a mutation (detectable by a rollback).
    (_sessionLiveGeneration[projectId] ??= {})[sessionId] = generation;
    (_sessionMutationGeneration[projectId] ??= {})[sessionId] = generation;

    final sessions = Map<String, Map<String, bool>>.from(_sessionUnseen.value);
    final projectSessions = Map<String, bool>.from(sessions[projectId] ?? const {});
    projectSessions[sessionId] = unseen;
    sessions[projectId] = projectSessions;
    _sessionUnseen.add(sessions);

    // Conservative aggregate update: only a mark-UNREAD of a session that is not
    // excluded (archived) can be locally trusted to bold the project. A
    // mark-READ leaves the aggregate to the bridge echo — and, crucially, does
    // NOT advance the project generation, otherwise an in-flight authoritative
    // REST clear (which carries the bridge-accepted false aggregate) would be
    // treated as older and skipped, leaving the project bold if the echo is
    // missed.
    final isExcluded = _excludedSessions[projectId]?.contains(sessionId) ?? false;
    if (unseen && !isExcluded) {
      _projectLiveGeneration[projectId] = generation;
      final projects = Map<String, bool>.from(_projectUnseen.value);
      projects[projectId] = true;
      _projectUnseen.add(projects);
    }
    return generation;
  }

  /// Rolls back a prior [applyLocalSessionUnseen] (identified by the generation
  /// it returned) — but only if no newer update for this session has landed
  /// since. This prevents a failed mark-read/unread from clobbering a genuine
  /// live `session.unseen_changed` (or another action) that arrived while the
  /// request was in flight.
  ///
  /// Restores both the per-session [unseen] value and the project aggregate to
  /// [projectUnseen] (the value before the optimistic apply). The aggregate
  /// restore matters because an optimistic mark-UNREAD that bolded a previously
  /// un-bold project leaves no bridge echo when the request fails, so without
  /// this the project would stay bold indefinitely.
  void revertLocalSessionUnseen({
    required String projectId,
    required String sessionId,
    required bool unseen,
    required bool projectUnseen,
    required int ifGeneration,
  }) {
    if (_sessionUnseen.isClosed) return;
    // Guard on the MUTATION generation: any change since the optimistic apply —
    // a live event, another apply, OR a REST reconcile that changed this session
    // — must block the rollback so it can't clobber a newer authoritative value.
    if ((_sessionMutationGeneration[projectId]?[sessionId] ?? 0) != ifGeneration) return;

    final generation = ++_generation;
    _projectLiveGeneration[projectId] = generation;
    (_sessionLiveGeneration[projectId] ??= {})[sessionId] = generation;
    (_sessionMutationGeneration[projectId] ??= {})[sessionId] = generation;

    final sessions = Map<String, Map<String, bool>>.from(_sessionUnseen.value);
    final projectSessions = Map<String, bool>.from(sessions[projectId] ?? const {});
    projectSessions[sessionId] = unseen;
    sessions[projectId] = projectSessions;
    _sessionUnseen.add(sessions);

    final projects = Map<String, bool>.from(_projectUnseen.value);
    projects[projectId] = projectUnseen;
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
        (_sessionMutationGeneration[projectID] ??= {})[sessionId] = generation;

        // unseen:true together with projectHasUnseenChanges:false can only mean
        // this session is excluded from the aggregate (archived). Record it.
        // Clear the exclusion only when the session demonstrably contributes
        // again (unseen AND the project aggregate is true). A read echo
        // (unseen:false) is NOT proof the session is un-archived — marking an
        // archived session read also yields unseen:false + projectHasUnseenChanges
        // :false — so it must not drop the exclusion, otherwise a later
        // mark-unread of that archived session would wrongly re-bold the project.
        // The exclusion is otherwise cleared when a /sessions reconcile shows the
        // session present (proving it is not archived).
        if (unseen && !projectHasUnseenChanges) {
          (_excludedSessions[projectID] ??= <String>{}).add(sessionId);
        } else if (unseen && projectHasUnseenChanges) {
          _excludedSessions[projectID]?.remove(sessionId);
        }

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
