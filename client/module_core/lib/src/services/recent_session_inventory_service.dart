import "dart:async";

import "package:collection/collection.dart";
import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/sse_event.dart";
import "../errors/api_error_remote_failure_x.dart";
import "../logging/logging.dart";
import "catalog_rescan_service.dart";
import "models/recent_sessions_entry.dart";
import "models/session_activity_info.dart";
import "models/session_list_filter.dart";
import "models/session_list_item_state.dart";
import "project_list_service.dart";
import "session_list_service.dart";
import "session_unseen_tracker.dart";
import "sse_event_tracker.dart";

enum _RecentReadOutcome() {
  applied,
  failed,
  superseded,
}

/// Scoped recent-session inventory: never acquires a project-view claim.
/// The caller owns this factory instance and disposes it with its signed-in scope.
@injectable
class RecentSessionInventoryService({
  required final SessionListService _sessionListService,
  required final ProjectListService projectListService,
  required final ConnectionService _connectionService,
  required final SseEventTracker _sseEventTracker,
  required final SessionUnseenTracker _sessionUnseenTracker,
  required CatalogRescanService catalogRescanService,
}) {
  final BehaviorSubject<Map<String, RecentSessionsEntry>> _state = BehaviorSubject.seeded(const {});
  final CompositeSubscription _subscriptions = CompositeSubscription();
  // Retain the latest result as well as its identity: useful rows alone cannot
  // tell an explicit refresh caller whether the owning read failed.
  final Map<String, Completer<_RecentReadOutcome>> _latestReads = {};
  // Retained until a snapshot covering this lifecycle generation is applied.
  final Map<String, int> _lifecycleChangeGenerations = {};

  ValueStream<Map<String, RecentSessionsEntry>> get state => _state.stream;

  this {
    _subscriptions.add(projectListService.listedProjects.listen(_admitProjects));
    _subscriptions.add(_connectionService.events.listen((event) => _onEvent(event: event)));
    _subscriptions.add(_sseEventTracker.sessionActivity.listen((_) => _projectLiveState()));
    _subscriptions.add(_sessionUnseenTracker.sessionUnseen.listen((_) => _projectLiveState()));
    _subscriptions.add(_connectionService.dataMayBeStale.listen((_) => _refreshKnownProjects()));
    _subscriptions.add(catalogRescanService.catalogChanged.listen((_) => _refreshKnownProjects()));
  }

  void _admitProjects(List<ProjectSummary> projects) {
    if (_state.isClosed) return;
    final projectIds = projects.map((project) => project.id).toSet();
    final removedProjectIds = _state.value.keys.where((projectId) => !projectIds.contains(projectId)).toList();
    if (removedProjectIds.isNotEmpty) {
      for (final projectId in removedProjectIds) {
        // Removing the request identity fences any completion already in flight.
        _latestReads.remove(projectId);
        _lifecycleChangeGenerations.remove(projectId);
      }
      _state.add(Map.unmodifiable({..._state.value}..removeWhere((projectId, _) => !projectIds.contains(projectId))));
    }
    for (final project in projects) {
      unawaited(ensureLoaded(projectId: project.id));
    }
  }

  Future<void> ensureLoaded({required String projectId}) async {
    if (_state.isClosed || _latestReads[projectId]?.isCompleted == false) return;
    final entry = _state.value[projectId];
    if (entry != null && !(entry is RecentSessionsLoaded && _lifecycleChangeGenerations.containsKey(projectId))) {
      return;
    }
    await _load(projectId: projectId);
  }

  Future<void> retry({required String projectId}) => _load(projectId: projectId);

  /// Refresh the currently admitted inventory, joining reads already in flight.
  /// This reports read outcomes, not whether older useful rows remain visible.
  Future<bool> refresh() async {
    if (_state.isClosed) return false;
    final results = await Future.wait(
      _state.value.keys.map((projectId) => _refreshProject(projectId: projectId)),
    );
    return results.every((succeeded) => succeeded);
  }

  Future<bool> _refreshProject({required String projectId}) async {
    final pending = _latestReads[projectId];
    var latest = pending != null && !pending.isCompleted ? pending.future : _load(projectId: projectId);
    while (true) {
      final outcome = await latest;
      if (_state.isClosed) return false;
      final current = _latestReads[projectId];
      // A removed project no longer belongs to this inventory's refresh.
      if (current == null) return true;
      if (!identical(current.future, latest)) {
        latest = current.future;
        continue;
      }
      return outcome == _RecentReadOutcome.applied;
    }
  }

  Future<_RecentReadOutcome> _load({required String projectId}) {
    if (_state.isClosed) return Future.value(_RecentReadOutcome.failed);
    final request = Completer<_RecentReadOutcome>();
    _latestReads[projectId] = request;
    unawaited(_runLoad(projectId: projectId, request: request));
    return request.future;
  }

  Future<void> _runLoad({
    required String projectId,
    required Completer<_RecentReadOutcome> request,
  }) async {
    final lifecycleChangeGeneration = _lifecycleChangeGenerations[projectId];
    try {
      if (_state.value[projectId] is! RecentSessionsLoaded) {
        _put(projectId: projectId, entry: RecentSessionsLoading());
      }
      final unseenTick = _sessionUnseenTracker.tick;
      final response = await _sessionListService.listSessions(projectId: projectId, waitForPrData: false);
      if (response case ErrorResponse(:final error)) {
        loge("Failed to load recent sessions for project $projectId", error);
      }
      // A reconnect/catalog event can request a newer snapshot while this read
      // is in flight. Its result, not this older one, owns the project entry.
      if (_state.isClosed || !identical(_latestReads[projectId], request)) {
        request.complete(_RecentReadOutcome.superseded);
        return;
      }
      // A phone/backend mutation may commit after the server took this list's
      // snapshot. Coalesce those events into one follow-up read before seeding.
      if (_lifecycleChangeGenerations[projectId] != lifecycleChangeGeneration) {
        await _load(projectId: projectId);
        request.complete(_RecentReadOutcome.superseded);
        return;
      }
      switch (response) {
        case SuccessResponse(:final data):
          _sessionUnseenTracker.seedSessions(
            projectId: projectId,
            stateBySessionId: {
              for (final session in data.items)
                session.id: (unseen: session.unseen, lastUserActivityAt: session.lastUserActivityAt),
            },
            sinceTick: unseenTick,
          );
          _put(
            projectId: projectId,
            entry: _project(projectId: projectId, sessions: data.items),
          );
          if (_lifecycleChangeGenerations[projectId] == lifecycleChangeGeneration) {
            _lifecycleChangeGenerations.remove(projectId);
          }
          request.complete(_RecentReadOutcome.applied);
        case ErrorResponse(:final error):
          if (_state.value[projectId] is! RecentSessionsLoaded) {
            _put(
              projectId: projectId,
              entry: RecentSessionsFailed(reason: error.remoteFailureReason),
            );
          }
          request.complete(_RecentReadOutcome.failed);
      }
    } catch (error, stackTrace) {
      loge("Failed to load recent sessions for project $projectId", error, stackTrace);
      if (!_state.isClosed && identical(_latestReads[projectId], request)) {
        if (_state.value[projectId] is! RecentSessionsLoaded) {
          _put(
            projectId: projectId,
            entry: const RecentSessionsFailed(reason: RemoteFailureReason.unknown),
          );
        }
      }
      request.complete(_RecentReadOutcome.failed);
    }
  }

  void _refreshKnownProjects() {
    if (_state.isClosed) return;
    // Each reconnect or catalog commit attempts one refresh per known entry,
    // including failed/in-flight reads. Failures wait for the next trigger.
    for (final projectId in _state.value.keys) {
      unawaited(_load(projectId: projectId));
    }
  }

  void _onEvent({required SseEvent event}) {
    if (_state.isClosed) return;
    final data = event.data;
    if (data case SesoriSessionsUpdated(:final projectID)) {
      if (_state.value.containsKey(projectID)) unawaited(_load(projectId: projectID));
    } else if (data
        case SesoriSessionCreated(:final info) ||
            SesoriSessionUpdated(:final info) ||
            SesoriSessionDeleted(:final info)) {
      final projectId = info.projectID;
      final entry = _state.value[projectId];
      if (info.parentID != null) return;
      final hasPendingRead = _latestReads[projectId]?.isCompleted == false;
      final hasRetainedLifecycleChange = _lifecycleChangeGenerations.containsKey(projectId);
      if (hasPendingRead || hasRetainedLifecycleChange) {
        _lifecycleChangeGenerations[projectId] = (_lifecycleChangeGenerations[projectId] ?? 0) + 1;
      }
      if (entry is! RecentSessionsLoaded) return;
      final existing = entry.sourceSessions.firstWhereOrNull((session) => session.id == info.id);
      final List<Session> sessions;
      if (data is SesoriSessionDeleted) {
        sessions = _sessionListService.removeSession(sessions: entry.sourceSessions, sessionId: info.id);
      } else if (data is SesoriSessionUpdated && existing != null) {
        sessions = _sessionListService.applySessionUpdatedEvent(
          sessions: entry.sourceSessions,
          existingSession: existing,
          session: info,
        );
      } else {
        sessions = _sessionListService.upsertSession(sessions: entry.sourceSessions, session: info);
      }
      _put(
        projectId: projectId,
        entry: _project(projectId: projectId, sessions: sessions),
      );
      if (!hasPendingRead && hasRetainedLifecycleChange) {
        unawaited(_load(projectId: projectId));
      }
    }
  }

  RecentSessionsLoaded _project({required String projectId, required List<Session> sessions}) {
    final activity = _sseEventTracker.currentSessionActivity[projectId] ?? const {};
    final listState = _sessionUnseenTracker.currentSessionUnseen[projectId] ?? const {};
    return RecentSessionsLoaded(
      sourceSessions: List.unmodifiable(sessions),
      visibleSessions: List.unmodifiable(
        _sessionListService.visibleSessions(
          sessions: sessions,
          filter: SessionListFilter.active,
          activityBySessionId: activity,
          listStateBySessionId: listState,
        ),
      ),
      activityBySessionId: Map.unmodifiable(activity),
      listStateBySessionId: Map.unmodifiable(listState),
    );
  }

  void _projectLiveState() {
    if (_state.isClosed) return;
    final changed = <String, RecentSessionsEntry>{};
    for (final MapEntry(key: projectId, value: entry) in _state.value.entries) {
      if (entry is! RecentSessionsLoaded) continue;
      final activity = _sseEventTracker.currentSessionActivity[projectId] ?? const {};
      final listState = _sessionUnseenTracker.currentSessionUnseen[projectId] ?? const {};
      if (const MapEquality<String, SessionActivityInfo>().equals(activity, entry.activityBySessionId) &&
          const MapEquality<String, SessionListItemState>().equals(listState, entry.listStateBySessionId)) {
        continue;
      }
      changed[projectId] = _project(projectId: projectId, sessions: entry.sourceSessions);
    }
    if (changed.isNotEmpty) _state.add(Map.unmodifiable({..._state.value, ...changed}));
  }

  void _put({required String projectId, required RecentSessionsEntry entry}) {
    _state.add(Map.unmodifiable({..._state.value, projectId: entry}));
  }

  Future<void> dispose() async {
    await _state.close();
    await _subscriptions.dispose();
  }
}
