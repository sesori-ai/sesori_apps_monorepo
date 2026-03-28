import "dart:async";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../capabilities/server_connection/models/sse_event.dart";
import "../../capabilities/session/session_service.dart";
import "../../capabilities/sse/session_activity_info.dart";
import "../../capabilities/sse/sse_event_repository.dart";
import "../../logging/logging.dart";
import "session_list_state.dart";

class SessionListCubit extends Cubit<SessionListState> {
  final CompositeSubscription _subscriptions = CompositeSubscription();

  final SessionService _service;
  final ConnectionService _connectionService;
  final SseEventRepository _sseEventRepository;
  final String _projectId;
  final FailureReporter _failureReporter;

  /// Tracks the session state before the last archive/unarchive action
  /// so the screen can offer an undo toast.
  Session? _undoSnapshot;

  SessionListCubit(
    SessionService service,
    ConnectionService connectionService,
    SseEventRepository sseEventRepository, {
    required String projectId,
    required FailureReporter failureReporter,
  }) : _service = service,
       _connectionService = connectionService,
       _sseEventRepository = sseEventRepository,
       _projectId = projectId,
       _failureReporter = failureReporter,
       super(const SessionListState.loading()) {
    loadSessions();
    _subscriptions.add(_connectionService.events.listen(_handleEvent));
    // skip(1) ignores the BehaviorSubject replay of the current status —
    // we only want to react to actual transitions (e.g. disconnected → connected).
    _subscriptions.add(_connectionService.status.skip(1).listen(_onConnectionStatusChanged));
    _subscriptions.add(
      _sseEventRepository.sessionActivity.listen(_onSessionActivityUpdated),
    );
  }

  void _handleEvent(SseEvent event) {
    try {
      if (isClosed) return;
      logd("[SessionList] event received: ${event.data.runtimeType}");
      switch (event.data) {
        case SesoriSessionCreated(:final info):
          _onSessionCreated(info);
        case SesoriSessionUpdated(:final info):
          _onSessionUpdated(info);
        case SesoriSessionDeleted(:final info):
          _onSessionDeleted(info);
        default:
          break;
      }
    } catch (e, st) {
      loge("SSE event handler error", e, st);
      unawaited(
        _failureReporter
            .recordFailure(
              error: e,
              stackTrace: st,
              uniqueIdentifier: "session_list_event:${event.data.runtimeType}",
              fatal: false,
              reason: "Failed to handle session list event",
              information: [event.data.runtimeType.toString()],
            )
            .catchError((_) {}),
      );
    }
  }

  void _onSessionActivityUpdated(Map<String, Map<String, SessionActivityInfo>> activityByProjectId) {
    if (isClosed) return;
    if (state is! SessionListLoaded) return;
    final loaded = state as SessionListLoaded;
    final projectActivity = activityByProjectId[_projectId] ?? <String, SessionActivityInfo>{};
    emit(
      SessionListState.loaded(
        sessions: loaded.sessions,
        showArchived: loaded.showArchived,
        activeSessionIds: projectActivity,
      ),
    );
  }

  void _onSessionCreated(Session session) {
    // Only add root sessions that belong to this project.
    if (session.parentID != null) {
      logd("[SessionList] session.created ignored id=${session.id} reason=child");
      return;
    }
    if (session.projectID != _projectId) {
      logd("[SessionList] session.created ignored id=${session.id} reason=project_mismatch");
      return;
    }

    if (state is! SessionListLoaded) {
      logd("[SessionList] session.created ignored id=${session.id} reason=state_not_loaded");
      return;
    }

    // Avoid duplicates.
    if (_allSessions.any((s) => s.id == session.id)) {
      logd("[SessionList] session.created ignored id=${session.id} reason=duplicate");
      return;
    }

    _allSessions = [session, ..._allSessions];
    logd("[SessionList] session.created added id=${session.id}");
    _emitFiltered();
  }

  void _onSessionUpdated(Session session) {
    if (session.projectID != _projectId) {
      logd("[SessionList] session.updated ignored id=${session.id} reason=project_mismatch");
      return;
    }
    if (state is! SessionListLoaded) {
      logd("[SessionList] session.updated ignored id=${session.id} reason=state_not_loaded");
      return;
    }

    final index = _allSessions.indexWhere((s) => s.id == session.id);

    if (index < 0) {
      // Session was unarchived (or created elsewhere) — add it if it belongs here.
      logd("[SessionList] session.updated not_found id=${session.id} action=add_via_created");
      _onSessionCreated(session);
      return;
    }

    _allSessions = List<Session>.from(_allSessions);
    _allSessions[index] = session;
    logd("[SessionList] session.updated updated id=${session.id}");
    _emitFiltered();
  }

  void _onSessionDeleted(Session session) {
    if (session.projectID != _projectId) {
      logd("[SessionList] session.deleted ignored id=${session.id} reason=project_mismatch");
      return;
    }
    if (state is! SessionListLoaded) {
      logd("[SessionList] session.deleted ignored id=${session.id} reason=state_not_loaded");
      return;
    }

    final before = _allSessions.length;
    _allSessions = _allSessions.where((s) => s.id != session.id).toList();
    if (_allSessions.length == before) {
      logd("[SessionList] session.deleted not_found id=${session.id}");
      return;
    }

    logd("[SessionList] session.deleted removed id=${session.id}");
    _emitFiltered();
  }

  void _onConnectionStatusChanged(ConnectionStatus status) {
    logd("[SessionList] connection status: ${status.runtimeType}");
    if (isClosed) return;
    if (status is ConnectionConnected && state is SessionListLoaded) {
      unawaited(refreshSessions());
    }
  }

  // ---------------------------------------------------------------------------
  // Archive / Unarchive / Delete
  // ---------------------------------------------------------------------------

  /// Archives a session. Returns `true` on success so the screen can show
  /// an undo toast.
  Future<bool> archiveSession(String sessionId) async {
    if (state is! SessionListLoaded) return false;

    final index = _allSessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return false;

    // Store for undo before removing.
    _undoSnapshot = _allSessions[index];

    // Optimistically mark as archived in the backing list so _emitFiltered
    // hides it when showArchived is off.
    _allSessions = List<Session>.from(_allSessions);
    _allSessions[index] = _allSessions[index].copyWith(
      time: _allSessions[index].time?.copyWith(archived: DateTime.now().millisecondsSinceEpoch),
    );
    _emitFiltered();

    final response = await _service.archiveSession(sessionId);
    if (isClosed) return false;

    return switch (response) {
      SuccessResponse() => true,
      ErrorResponse(:final error) => () {
        loge("Failed to archive session: $error");
        // Rollback — re-insert the original session.
        _rollbackLastAction();
        return false;
      }(),
    };
  }

  /// Unarchives a session. Returns `true` on success so the screen can show
  /// a confirmation message.
  ///
  /// Unlike [archiveSession], this does NOT set [_undoSnapshot] because the
  /// operation internally creates a new session (via fork + delete) with a
  /// different ID, so the original cannot be restored.
  Future<bool> unarchiveSession(String sessionId) async {
    if (state is! SessionListLoaded) return false;

    final index = _allSessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return false;

    // Store for rollback (NOT for undo — undo is disabled for unarchive).
    final original = _allSessions[index];

    // Optimistically REMOVE the session (it's archived, so removing it
    // from the list is the expected visual outcome).
    _allSessions = List<Session>.from(_allSessions)..removeAt(index);
    _emitFiltered();

    final response = await _service.unarchiveSession(sessionId);
    if (isClosed) return false;

    return switch (response) {
      SuccessResponse(:final data) => () {
        // Insert the NEW session (which may have a different ID).
        _reinsertSession(data);
        return true;
      }(),
      ErrorResponse(:final error) => () {
        loge("Failed to unarchive session: $error");
        // Rollback — re-insert the ORIGINAL session.
        _reinsertSession(original);
        return false;
      }(),
    };
  }

  /// Undoes the last archive or unarchive operation by reversing the action.
  Future<bool> undoLastArchiveAction() async {
    final snapshot = _undoSnapshot;
    if (snapshot == null) return false;
    _undoSnapshot = null;

    // If the snapshot was archived, the last action was an unarchive → re-archive.
    // If the snapshot was not archived, the last action was an archive → unarchive.
    final wasArchived = snapshot.time?.archived != null;
    final response = wasArchived
        ? await _service.archiveSession(snapshot.id)
        : await _service.unarchiveSession(snapshot.id);
    if (isClosed) return false;

    switch (response) {
      case SuccessResponse(:final data):
        _reinsertSession(data);
        return true;
      case ErrorResponse(:final error):
        loge("Failed to undo archive action: $error");
        return false;
    }
  }

  /// Clears undo state. Called when the undo toast dismisses.
  void clearLastActionUndo() {
    _undoSnapshot = null;
  }

  /// Renames a session. Returns `true` on success so the screen can show
  /// a confirmation message.
  Future<bool> renameSession({required String sessionId, required String title}) async {
    final response = await _service.renameSession(sessionId: sessionId, title: title);
    if (isClosed) return false;

    switch (response) {
      case SuccessResponse():
        await refreshSessions();
        return true;
      case ErrorResponse():
        return false;
    }
  }

  /// Deletes a session permanently.
  Future<bool> deleteSession(String sessionId) async {
    if (state is! SessionListLoaded) return false;

    final index = _allSessions.indexWhere((s) => s.id == sessionId);
    if (index < 0) return false;

    // Optimistically remove.
    _allSessions = List<Session>.from(_allSessions)..removeAt(index);
    _emitFiltered();

    final response = await _service.deleteSession(sessionId);
    if (isClosed) return false;

    return switch (response) {
      SuccessResponse() => true,
      ErrorResponse(:final error) => () {
        loge("Failed to delete session: $error");
        // Reload to restore consistent state.
        loadSessions();
        return false;
      }(),
    };
  }

  void _rollbackLastAction() {
    final session = _undoSnapshot;
    if (session == null) return;
    _undoSnapshot = null;
    _reinsertSession(session);
  }

  void _reinsertSession(Session session) {
    if (state is! SessionListLoaded) return;

    // Replace or insert in backing list.
    final index = _allSessions.indexWhere((s) => s.id == session.id);
    _allSessions = List<Session>.from(_allSessions);
    if (index >= 0) {
      _allSessions[index] = session;
    } else {
      _allSessions.insert(0, session);
    }
    _emitFiltered();
  }

  // ---------------------------------------------------------------------------

  /// Creates a new session via POST /session and returns it, or null on failure.
  Future<Session?> createSession() async {
    final response = await _service.createSession(projectId: _projectId);

    if (isClosed) return null;

    return switch (response) {
      SuccessResponse(:final data) => () {
        _onSessionCreated(data);
        return data;
      }(),
      ErrorResponse() => null,
    };
  }

  /// Tracks the full unfiltered server response so toggling archived
  /// doesn't require a network round-trip.
  List<Session> _allSessions = [];
  bool _showArchived = false;

  void toggleArchived() {
    _showArchived = !_showArchived;
    _emitFiltered();
  }

  void _emitFiltered() {
    var visible = _allSessions;
    if (!_showArchived) {
      visible = visible.where((s) => s.time?.archived == null).toList();
    }
    final sorted = visible.toList()..sort((a, b) => (b.time?.updated ?? 0).compareTo(a.time?.updated ?? 0));

    if (isClosed) return;
    final projectActivity = _sseEventRepository.currentSessionActivity[_projectId] ?? <String, SessionActivityInfo>{};
    emit(
      SessionListState.loaded(
        sessions: sorted,
        showArchived: _showArchived,
        activeSessionIds: projectActivity,
      ),
    );
  }

  Future<void> loadSessions() async {
    emit(const SessionListState.loading());
    await _fetchSessions();
  }

  /// In-flight silent refresh, used for coalescing.
  Future<bool>? _activeRefresh;

  /// Re-fetches sessions without showing the full-screen loading indicator.
  /// Concurrent calls are coalesced: if a refresh is already in-flight, the
  /// existing Future is returned instead of starting a second network request.
  Future<bool> refreshSessions() {
    return _activeRefresh ??= _fetchSessions(silent: true).whenComplete(() => _activeRefresh = null);
  }

  Future<bool> _fetchSessions({bool silent = false}) async {
    final response = await _service.listSessions(projectId: _projectId);
    if (isClosed) return false;

    switch (response) {
      case SuccessResponse(:final data):
        _allSessions = data;
        _emitFiltered();
        return true;

      case ErrorResponse(:final error):
        if (silent) {
          logw("Failed to refresh sessions: $error");
        } else {
          emit(SessionListState.failed(error: error));
        }
        return false;
    }
  }

  @override
  Future<void> close() {
    _subscriptions.dispose();
    return super.close();
  }
}
