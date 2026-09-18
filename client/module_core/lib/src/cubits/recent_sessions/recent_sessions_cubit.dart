import "dart:async";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/sse_event.dart";
import "../../errors/api_error_remote_failure_x.dart";
import "../../logging/logging.dart";
import "../../services/catalog_rescan_service.dart";
import "../../services/models/session_activity_info.dart";
import "../../services/models/session_list_filter.dart";
import "../../services/models/session_list_item_state.dart";
import "../../services/project_list_service.dart";
import "../../services/session_list_service.dart";
import "../../services/session_unseen_tracker.dart";
import "../../services/sse_event_tracker.dart";
import "recent_sessions_state.dart";

/// Sidebar inventory only: never acquires a project-view claim.
class RecentSessionsCubit({
  required final SessionListService _sessionListService,
  required final ProjectListService projectListService,
  required final ConnectionService _connectionService,
  required final SseEventTracker _sseEventTracker,
  required final SessionUnseenTracker _sessionUnseenTracker,
  required CatalogRescanService catalogRescanService,
}) extends Cubit<Map<String, RecentSessionsEntry>> {
  final CompositeSubscription _subscriptions = CompositeSubscription();
  // Refresh ownership is separate from the usable, live-patched display data.
  final Map<String, RecentSessionsLoading> _pendingReads = {};
  // Retained until a snapshot covering this lifecycle generation is applied.
  final Map<String, int> _lifecycleChangeGenerations = {};

  this : super(const {}) {
    _subscriptions.add(projectListService.listedProjects.listen(_admitProjects));
    _subscriptions.add(_connectionService.events.listen((event) => _onEvent(event: event)));
    _subscriptions.add(_sseEventTracker.sessionActivity.listen((_) => _projectLiveState()));
    _subscriptions.add(_sessionUnseenTracker.sessionUnseen.listen((_) => _projectLiveState()));
    _subscriptions.add(_connectionService.dataMayBeStale.listen((_) => _refreshKnownProjects()));
    _subscriptions.add(catalogRescanService.catalogChanged.listen((_) => _refreshKnownProjects()));
  }

  void _admitProjects(List<ProjectSummary> projects) {
    if (isClosed) return;
    final projectIds = projects.map((project) => project.id).toSet();
    final removedProjectIds = state.keys.where((projectId) => !projectIds.contains(projectId)).toList();
    if (removedProjectIds.isNotEmpty) {
      for (final projectId in removedProjectIds) {
        // Removing the request identity fences any completion already in flight.
        _pendingReads.remove(projectId);
        _lifecycleChangeGenerations.remove(projectId);
      }
      emit(Map.unmodifiable({...state}..removeWhere((projectId, _) => !projectIds.contains(projectId))));
    }
    for (final project in projects) {
      unawaited(ensureLoaded(projectId: project.id));
    }
  }

  Future<void> ensureLoaded({required String projectId}) async {
    if (isClosed || _pendingReads.containsKey(projectId)) return;
    final entry = state[projectId];
    if (entry != null && !(entry is RecentSessionsLoaded && _lifecycleChangeGenerations.containsKey(projectId))) {
      return;
    }
    await _load(projectId: projectId);
  }

  Future<void> retry({required String projectId}) => _load(projectId: projectId);

  Future<void> _load({required String projectId}) async {
    if (isClosed) return;
    final request = RecentSessionsLoading();
    _pendingReads[projectId] = request;
    final lifecycleChangeGeneration = _lifecycleChangeGenerations[projectId];
    if (state[projectId] is! RecentSessionsLoaded) _put(projectId: projectId, entry: request);
    try {
      final unseenTick = _sessionUnseenTracker.tick;
      final response = await _sessionListService.listSessions(projectId: projectId, waitForPrData: false);
      if (response case ErrorResponse(:final error)) {
        loge("Failed to load recent sessions for project $projectId", error);
      }
      // A reconnect/catalog event can request a newer snapshot while this read
      // is in flight. Its result, not this older one, owns the project entry.
      if (isClosed || !identical(_pendingReads[projectId], request)) return;
      // A phone/backend mutation may commit after the server took this list's
      // snapshot. Coalesce those events into one follow-up read before seeding.
      if (_lifecycleChangeGenerations[projectId] != lifecycleChangeGeneration) {
        await _load(projectId: projectId);
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
        case ErrorResponse(:final error):
          if (state[projectId] is! RecentSessionsLoaded) {
            _put(
              projectId: projectId,
              entry: RecentSessionsFailed(reason: error.remoteFailureReason),
            );
          }
      }
    } catch (error, stackTrace) {
      loge("Failed to load recent sessions for project $projectId", error, stackTrace);
      if (!isClosed && identical(_pendingReads[projectId], request)) {
        if (state[projectId] is! RecentSessionsLoaded) {
          _put(
            projectId: projectId,
            entry: const RecentSessionsFailed(reason: RemoteFailureReason.unknown),
          );
        }
      }
    } finally {
      if (identical(_pendingReads[projectId], request)) _pendingReads.remove(projectId);
    }
  }

  void _refreshKnownProjects() {
    if (isClosed) return;
    // Includes failed/in-flight entries, so a subsequent reconnect or catalog
    // commit retries them rather than consuming the invalidation unsuccessfully.
    for (final projectId in state.keys) {
      unawaited(_load(projectId: projectId));
    }
  }

  void _onEvent({required SseEvent event}) {
    if (isClosed) return;
    final data = event.data;
    if (data case SesoriSessionsUpdated(:final projectID)) {
      if (state.containsKey(projectID)) unawaited(_load(projectId: projectID));
    } else if (data
        case SesoriSessionCreated(:final info) ||
            SesoriSessionUpdated(:final info) ||
            SesoriSessionDeleted(:final info)) {
      final projectId = info.projectID;
      final entry = state[projectId];
      if (info.parentID != null) return;
      final hasPendingRead = _pendingReads.containsKey(projectId);
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
    if (isClosed) return;
    final changed = <String, RecentSessionsEntry>{};
    for (final MapEntry(key: projectId, value: entry) in state.entries) {
      if (entry is! RecentSessionsLoaded) continue;
      final activity = _sseEventTracker.currentSessionActivity[projectId] ?? const {};
      final listState = _sessionUnseenTracker.currentSessionUnseen[projectId] ?? const {};
      if (const MapEquality<String, SessionActivityInfo>().equals(activity, entry.activityBySessionId) &&
          const MapEquality<String, SessionListItemState>().equals(listState, entry.listStateBySessionId)) {
        continue;
      }
      changed[projectId] = _project(projectId: projectId, sessions: entry.sourceSessions);
    }
    if (changed.isNotEmpty) emit(Map.unmodifiable({...state, ...changed}));
  }

  void _put({required String projectId, required RecentSessionsEntry entry}) {
    emit(Map.unmodifiable({...state, projectId: entry}));
  }

  @override
  Future<void> close() async {
    await super.close();
    await _subscriptions.dispose();
  }
}
